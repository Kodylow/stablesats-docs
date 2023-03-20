# Getting the USD Target Liability

## How It Currently Works Against GaloyMoney's Backend

### "Polling the USD Liability from the `user-trades` module"

The stablesats application architecture uses postgres tables for its double entry accounting ledger. It uses rust's `sqlx` query builder library along with domain logic from `sqlx-mq`, which implements a job runner that can use postgres as a backend (sort of like sidekick or any standard asynchronous job runner). This lets stablesats 'de-duplicate' jobs when running as a highly available replicated application at enterprise scale. You can run it locally, but if you want to scale it out then you can because the jobs polling mechanism won't duplicate work across instance redundancies.

This job pattern of using a `sqlx-mq` job queue is used throughout the codebase.

Stablesats gets the target USD liability from the galoy backend via one of these jobs: there is a specific aggregate user in the postgres table (TK: which table, what's the schema?) named `dealer` which holds all the USD liability for all of GaloyMoney's bitcoin banking users.

> Note: this use of an aggregate user is an anti-pattern, it is in the process of being changed to track individual accounts instead, and not the recommended way of doing this for your own implementation. But it's how the target USD liability is done today and actually makes plugging in a different backend source easier, so tradeoffs.

Stablesats has login credentials for this special user, `dealer`, and the polling job checks against the table for new transactions by `dealer` using a cursor.

### 2 Transactions For Each Trade

When a galoy bank user, Alice, wants to move money to the synthetic USD account, there are two transactions that show up in this table under the `dealer`.

1. The `dealer` receives bitcoin from Alice
2. The `dealer` sends synthUSD to Alice

The "receiving" bitcoin is Alice locking in a USD price of some bitcoin, the "sending" USD is crediting Alice with the equivalent USD value of that locked bitcoin at the time she locks it.

The logic here needs to correlate the receiving bitcoin and sending USD and make sure that they match up: it has to identify `what the price of Bitcoin was at the time Alice locked it up`.

### Negative `dealer` USD Balance, Positive `dealer` Bitcoin Balance

Regular users cannot go negative (cannot overdraw), however the `dealer` has special logic that lets it go negative on the USD amount.

> Note: again, antipattern, don't do this with your implementation but it's how it works right now

This negative USD amount is the source of truth for the entire USD target liability. The target USD liability is the `dealer`'s USD balance (how many dollars it has credited to users in aggregate), and the positive bitcoin balance is the available bitcoin it has to use for the stablesats hedging strategy.

### Where the Polling Logic for USD-Target-Liability exists in the `stablesats-rs` Code

The entrypoint for the `dealer` polling job is in the `user-trades/job/mod.rs` module, specifically this function on line 66:

```rust
#[job(name = "poll_galoy_transactions")]
async fn poll_galoy_transactions(
    mut current_job: CurrentJob,
    user_trades: UserTrades,
    galoy: GaloyClient,
    PollGaloyTransactionsDelay(delay): PollGaloyTransactionsDelay,
    ledger: ledger::Ledger,
) -> Result<(), UserTradesError> {
    let pool = current_job.pool().clone();
    let has_more = JobExecutor::builder(&mut current_job)
        .initial_retry_delay(Duration::from_secs(5))
        .build()
        .expect("couldn't build JobExecutor")
        .execute(|_| async move {
            let galoy_transactions = GaloyTransactions::new(pool.clone());
            poll_galoy_transactions::execute(
                &pool,
                &user_trades,
                &galoy_transactions,
                &galoy,
                &ledger,
            )
            .await
        })
        .await?;
    if has_more {
        spawn_poll_galoy_transactions(current_job.pool(), Duration::from_secs(0)).await?;
    } else {
        spawn_poll_galoy_transactions(current_job.pool(), delay).await?;
    }
    Ok(())
}
```

The important part is in that `poll_galoy_transactions::execute()` function, which looks like this:

```rust
#[instrument(
    name = "user_trades.job.poll_galoy_transactions",
    skip_all,
    err,
    fields(n_galoy_txs, n_unpaired_txs, n_user_trades, has_more, n_bad_trades)
)]
pub(super) async fn execute(
    pool: &sqlx::PgPool,
    user_trades: &UserTrades,
    galoy_transactions: &GaloyTransactions,
    galoy: &GaloyClient,
    ledger: &ledger::Ledger,
) -> Result<bool, UserTradesError> {
    let has_more = import_galoy_transactions(galoy_transactions, galoy.clone()).await?;
    update_user_trades(galoy_transactions, user_trades).await?;
    update_ledger(pool, user_trades, ledger).await?;

    Ok(has_more)
}
```

## 3 Subsections for `poll_galoy_transactions::execute()`

### Section 1: Getting the transactions

```rust
let has_more = import_galoy_transactions(galoy_transactions, galoy.clone()).await?;
```

1. Calls the backend, in this case Galoy. The imported table has a flag for whether the transaction has been matched.
2. Checks for any new `dealer` transactions since the last time it polled.
3. Persists the transactions locally to its own postgres table.

### Section 2: Updating the user_trades tables

```rust
update_user_trades(galoy_transactions, user_trades).await?;
```

This checks for eventual consistency, matching the transactions and marking them as having been matched or not, before persisting to the local postgres database in a table called `user_trades`. see code for the function below.

```rust
async fn update_user_trades(
    galoy_transactions: &GaloyTransactions,
    user_trades: &UserTrades,
) -> Result<(), UserTradesError> {
    let UnpairedTransactions { list, mut tx } =
        galoy_transactions.list_unpaired_transactions().await?;
    if list.is_empty() {
        return Ok(());
    }
    let (trades, paired_ids) = unify(list);
    galoy_transactions
        .update_paired_ids(&mut tx, &paired_ids)
        .await?;
    let lookup = user_trades
        .find_already_paired_trades(&mut tx, paired_ids)
        .await?;
    let (trades, bad_pairings) = find_trades_needing_correction(trades, lookup);
    tracing::Span::current().record("n_user_trades", &tracing::field::display(trades.len()));
    if !bad_pairings.is_empty() {
        user_trades.mark_bad_trades(&mut tx, bad_pairings).await?;
    }
    user_trades.persist_all(&mut tx, trades).await?;
    tx.commit().await?;
    Ok(())
}
```

### Section 3: Update `ledger`

```rust
update_ledger(pool, user_trades, ledger).await?;
```

Just as the import table has a flag for whether the transaction has been matched, the user_trades table has a flag for whether the transaction has been accounted for in the ledger system. So before this is called the new transactions haven't been accounted for yet, and the accounting in the user_trades table is what's needed to hand it off to the hedging. This is another part made pretty complicated by the high-availability architecture, so is worth some more notes.

Let's look at the loop in `update_ledger` (lines 160-207) that do this accounting:

```rust
loop {
    let mut tx = pool.begin().await?;
    if let Ok(Some(UnaccountedUserTrade {
        buy_unit,
        buy_amount,
        sell_amount,
        external_ref,
        ledger_tx_id,
        ..
    })) = user_trades.find_unaccounted_trade(&mut tx).await
    {
        if buy_unit == UserTradeUnit::UsdCent {
            ledger
                .user_buys_usd(
                    tx,
                    ledger_tx_id,
                    ledger::UserBuysUsdParams {
                        satoshi_amount: sell_amount,
                        usd_cents_amount: buy_amount,
                        meta: ledger::UserBuysUsdMeta {
                            timestamp: external_ref.timestamp,
                            btc_tx_id: external_ref.btc_tx_id,
                            usd_tx_id: external_ref.usd_tx_id,
                        },
                    },
                )
                .await?;
        } else {
            ledger
                .user_sells_usd(
                    tx,
                    ledger_tx_id,
                    ledger::UserSellsUsdParams {
                        satoshi_amount: buy_amount,
                        usd_cents_amount: sell_amount,
                        meta: ledger::UserSellsUsdMeta {
                            timestamp: external_ref.timestamp,
                            btc_tx_id: external_ref.btc_tx_id,
                            usd_tx_id: external_ref.usd_tx_id,
                        },
                    },
                )
                .await?;
        }
    } else {
        break;
    }
}
```

That find_unaccounted_trade function is an sqlx query that will find a single user trade that hasn't been accounted for yet and mark it as being accounted for so that it doesn't get polled again. Doing it this way allows for effective and efficient locking around individual transactions as they get updated in the db.

Once the trade get accounted for, we call into the `ledger` module.

#### How do you decouple from the Galoy Backend? You have to adjust from poll_galoy_transactions up to this point. If at this point you format the data to match what the ledger module is expecting in the `user_buys_usd` and `user_sells_usd` methods, it can operate, manage, and run the USD-target-liability hedging (basically) untouched because the ledger module is what triggers the downstream hedging

