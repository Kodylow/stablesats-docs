# Decoupling the Bitcoin Wallet

Decoupling the bitcoin wallet will be significantly less work than decoupling the target usd liability in ledger and user_trades. You basically just need to hook in spend and receives for a standard bitcoin wallet instead of the GaloyClient's bitcoin wallet at the places where the hedging module moves funds in and out of OKX for the margin requirements.

## The `adjust_funding` job

The bitcoin wallet is used in the `hedging` module for moving money to and from OKX. One of the jobs, implemented in the same `sqlx-mq` job queue pattern as the other jobs we've goine over is `adjust_funding` , found in `hedging/src/okex/job/adjust_funding.rs` . It touches the galoy bitcoin wallet in 2 places to deposit and withdraw funds from OKX. To pull out the galoy backend for the bitcoin wallet here, you basically just need to change those 2 lines to point at a different client source for the bitcoin wallet. OKX also supports perpetual inverse swaps in other cryptos like ETH so you could point this at those other sources too, but remember you'll have to update the ledger system to reflect the different currencies if you don't just use bitcoin and you'll have to adjust the okx-client calls to not be hardcoded to bitcoin.

```rust
#[instrument(name = "hedging.okex.job.adjust_funding", skip_all, fields(correlation_id = %correlation_id,
        target_liability, current_position, last_price_in_usd_cents, funding_available_balance,
        trading_available_balance, onchain_fees, action, client_transfer_id,
        transferred_funding, lag_ok), err)]
pub(super) async fn execute(
    correlation_id: CorrelationId,
    pool: &sqlx::PgPool,
    ledger: ledger::Ledger,
    okex: OkexClient,
    okex_transfers: OkexTransfers,
    galoy: GaloyClient,
    funding_adjustment: FundingAdjustment,
) -> Result<(), HedgingError> {
    // ...
    // ...
    // ...

    match action {
        OkexFundingAdjustment::DoNothing => {}
        _ => {
            match action {
                // ...
                // ...
                // ...
                OkexFundingAdjustment::OnchainDeposit(amount) => {
                    let deposit_address = okex.get_funding_deposit_address().await?.value;
                    let reservation = TransferReservation {
                        shared: &shared,
                        action_size: Some(amount),
                        fee: Decimal::ZERO,
                        transfer_from: "galoy".to_string(),
                        transfer_to: deposit_address.clone(),
                    };
                    if let Some(client_id) =
                        okex_transfers.reserve_transfer_slot(reservation).await?
                    {
                        span.record(
                            "client_transfer_id",
                            &tracing::field::display(String::from(client_id)),
                        );

                        let amount_in_sats = amount * SATS_PER_BTC;
                        let memo: String = format!("deposit of {amount_in_sats} sats to OKX");

                        // *** TOUCHES BITCOIN WALLET TO SEND PAYMENT TO OKX ***
                        let _ = galoy
                            .send_onchain_payment(deposit_address, amount_in_sats, Some(memo), 1)
                            .await?;
                    }
                }
                OkexFundingAdjustment::OnchainWithdraw(amount) => {
                    // *** TOUCHES BITCOIN WALLET TO WITHDRAW FROM OKX ***
                    let deposit_address = galoy.onchain_address().await?.address;
                    let reservation = TransferReservation {
                        shared: &shared,
                        action_size: Some(amount),
                        fee: fees.min_fee,
                        transfer_from: "okx".to_string(),
                        transfer_to: deposit_address.clone(),
                    };
                    if let Some(client_id) =
                        okex_transfers.reserve_transfer_slot(reservation).await?
                    {
                        span.record(
                            "client_transfer_id",
                            &tracing::field::display(String::from(client_id.clone())),
                        );

                        okex.withdraw_btc_onchain(client_id, amount, fees.min_fee, deposit_address)
                            .await?;
                    }
                }
                _ => unreachable!(),
            }
            span.record("transferred_funding", &tracing::field::display(true));
        }
    };
    Ok(())
}
```

## Making a `WalletClient` trait for the onchain deposits/withdraws

To create a more generic wallet client, you can define a `WalletClient` trait that can be implemented by any Bitcoin wallet. In this example, we will create a trait with the two required methods: `onchain_address` and `send_onchain_payment`. Then, you can update the `execute` function in `adjust_funding.rs` to use this trait instead of the `GaloyClient`.

First, create the `WalletClient` trait:

```rust
pub trait WalletClient {
    async fn onchain_address(&self) -> Result<OnchainAddress, WalletError>;
    async fn send_onchain_payment(
        &self,
        destination: String,
        amount_in_sats: Decimal,
        memo: Option<String>,
        confirmations: usize,
    ) -> Result<(), WalletError>;
}

#[derive(Debug)]
pub struct OnchainAddress {
    pub address: String,
}
```

To update the `execute` function to use this trait for the `OKexFundingAdjustment::OnchainDeposit` and `OkexFundingAdjustment::OnchainWithdraw` actions, the code would look something like this:

```rust
#[instrument(name = "hedging.okex.job.adjust_funding", skip_all, fields(correlation_id = %correlation_id,
        target_liability, current_position, last_price_in_usd_cents, funding_available_balance,
        trading_available_balance, onchain_fees, action, client_transfer_id,
        transferred_funding, lag_ok), err)]
pub(super) async fn execute<W: WalletClient>(
    correlation_id: CorrelationId,
    pool: &sqlx::PgPool,
    ledger: ledger::Ledger,
    okex: OkexClient,
    okex_transfers: OkexTransfers,
    wallet: W,
    funding_adjustment: FundingAdjustment,
) -> Result<(), HedgingError> {
    // ...
    // ...
    // ...

    match action {
        OkexFundingAdjustment::DoNothing => {}
        _ => {
            match action {
                // ...
                // ...
                // ...
                OkexFundingAdjustment::OnchainDeposit(amount) => {
                    let deposit_address = okex.get_funding_deposit_address().await?.value;
                    let reservation = TransferReservation {
                        shared: &shared,
                        action_size: Some(amount),
                        fee: Decimal::ZERO,
                        transfer_from: "wallet".to_string(),
                        transfer_to: deposit_address.clone(),
                    };
                    if let Some(client_id) =
                        okex_transfers.reserve_transfer_slot(reservation).await?
                    {
                        span.record(
                            "client_transfer_id",
                            &tracing::field::display(String::from(client_id)),
                        );

                        let amount_in_sats = amount * SATS_PER_BTC;
                        let memo: String = format!("deposit of {amount_in_sats} sats to OKX");

                        // *** TOUCHES BITCOIN WALLET TO SEND PAYMENT TO OKX ***
                        let _ = wallet
                            .send_onchain_payment(deposit_address, amount_in_sats, Some(memo), 1)
                            .await?;
                    }
                }
                OkexFundingAdjustment::OnchainWithdraw(amount) => {
                    // *** TOUCHES BITCOIN WALLET TO WITHDRAW FROM OKX ***
                    let deposit_address = wallet.onchain_address().await?.address;
                    let reservation = TransferReservation {
                        shared: &shared,
                        action_size: Some(amount),
                        fee: fees.min_fee,
                        transfer_from: "okx".to_string(),
                        transfer_to: deposit_address.clone(),
                    };
                    if let Some(client_id) =
                        okex_transfers.reserve_transfer_slot(reservation).await?
                    {
                        span.record(
                            "client_transfer_id",
                            &tracing::field::display(String::from(client_id.clone())),
                        );

                        okex.withdraw_btc_onchain(client_id, 
                        amount, fees.min_fee, deposit_address)
                            .await?;
                    }
                }
                _ => unreachable!(),
            }
            span.record("transferred_funding", &tracing::field::display(true));
        }
    };
    Ok(())
}
```
