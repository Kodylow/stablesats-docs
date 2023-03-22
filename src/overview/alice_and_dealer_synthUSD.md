# An Alice and Bob Example of Using Synthetic USD on Bitcoin with OKX

In cryptography we like to use Alice and Bob examples, and when there's a "dealer" or superuser of some kind we like to call him Dave.

This example walks through step by step the high level mechanism for how synthetic USD works. We walk through the example in plain english (graphically depicted below), then provide a commented rust implementation so you can walk through the math yourself.

Alice holds 1 million satoshis in her Bitcoin account and wishes to move $120 to a synthetic USD account. Given the price of Bitcoin is $30,000, she allocates ~400,000 satoshis (from her 1 million) for the synthetic USD account, while retaining 600,000 satoshis in her Bitcoin account, which are valued at $180. Alice locks 400,000 satoshis with Dave the Dealer. Dave acknowledges the deposit of 400,000 satoshis at the $30,000 Bitcoin price and promptly opens a corresponding short position on OKX by shorting the BTC/USD perpetual inverse swap, which moves inversely in price to the USD price of Bitcoin.

We consider two scenarios:

1. Three months after Alice's actions, the Bitcoin price falls by 50% to $15,000. Alice's Bitcoin account maintains 600,000 satoshis, now worth $90. However, her synthetic USD account, comprising the net position between the Bitcoin she moved to Dave and the value of the short position, remains worth 800,000 satoshis or $120, preserving a stable USD value through hedging.
2. Three months after Alice's actions, the Bitcoin price surges by 100% to $60,000. Alice's Bitcoin account still has 600,000 satoshis, now worth $360. Yet, her synthetic USD account, consisting of the net position between the Bitcoin she transferred to Dave and the value of the short position, maintains a value of 200,000 satoshis or $120, ensuring a stable USD value through hedging.

Dave the Dealer's physical BTC profit was +$120, and his short position loss was -$120, resulting in a Net Profit and Loss of $0. This indicates a delta-neutral trade. 

![alice and bob](../images/mimages/alice_and_bob.png)


The Rust implementation demonstrates that the synthetic USD account's value remains stable, and Dave's trading strategy is delta-neutral.

```rust
use std::collections::HashMap;

// Define the Account struct to hold the BTC and USD balances for Alice.
#[derive(Debug, PartialEq)]
struct Account {
    btc_balance: f64,
    usd_balance: f64,
}

impl Account {
    // Constructor for the Account struct.
    fn new(btc_balance: f64, usd_balance: f64) -> Account {
        Account { btc_balance, usd_balance }
    }
}

// Define the Dealer struct to represent the dealer's physical Bitcoin account and short position.
#[derive(Debug)]
struct Dealer {
    btc_balance: f64,
    short_position: f64,
}

impl Dealer {
    // Constructor for the Dealer struct.
    fn new(btc_balance: f64, short_position: f64) -> Dealer {
        Dealer { btc_balance, short_position }
    }

    // Adjust the dealer's short position based on Alice's locked BTC balance and the current BTC/USD price.
    fn adjust_trade(&mut self, alice_btc_balance: f64, btc_usd: f64) {
        self.short_position = alice_btc_balance / btc_usd;
    }
}

// Function to handle transferring satoshis from Alice's account to the dealer and locking the USD value.
fn lock_btc_usd_price(
    alice_account: &mut Account,
    dealer: &mut Dealer,
    locked_sats: f64,
    btc_usd: f64,
) {
    // Transfer the locked satoshis from Alice's account to the dealer's account.
    dealer.btc_balance += locked_sats;

    // Update the dealer's short position.
    dealer.adjust_trade(locked_sats, btc_usd);

    // Update Alice's account to reflect the locked satoshis and the corresponding USD value.
    alice_account.btc_balance -= locked_sats;
    alice_account.usd_balance = locked_sats / btc_usd * 100.0;
}

fn main() {
    // Initialize Alice's account with 1,000,000 satoshis and an empty dealer account.
    let mut accounts: HashMap<String, Account> = HashMap::new();
    accounts.insert("Alice".to_string(), Account::new(1_000_000.0, 0.0));
    let mut dealer = Dealer::new(0.0, 0.0);

    // Lock 400,000 satoshis in Alice's account at a BTC/USD price of $30,000.
    let locked_sats = 400_000.0;
    let btc_usd = 30_000.0;
    lock_btc_usd_price(
        accounts.get_mut("Alice").unwrap(),
        &mut dealer,
        locked_sats,
        btc_usd,
    );

    // Define the two scenarios for changes in the BTC price.
    let scenarios = vec![15_000.0, 60_000.0];

    // Iterate through the scenarios and calculate the new values for Alice's and the dealer's accounts.
    for price in scenarios {
        let price_change_ratio = price / btc_usd;
        let alice_account = accounts.get_mut("Alice").unwrap();
        let alice_new_btc_balance = alice_account.btc_balance * price_change_ratio;
        let dealer_short_position_loss = dealer.short_position * (1.0 - price_change_ratio);
        let alice_new_usd_balance = alice_account.usd_balance + dealer_short_position_loss * 100.0;

        // Update the dealer's BTC balance and short position.
        dealer.btc_balance -= dealer_short_position_loss * 100.0;
        dealer.adjust_trade(dealer.btc_balance, price);
        let dealer_net_pnl = dealer_short_position_loss * 100.0;

        println!("BTC price: ${}", price);
        println!(
            "Alice's BTC account: {:.0} sats, Alice's USD account: {:.2} sats",
            alice_new_btc_balance,
            alice_new_usd_balance
        );
        println!(
            "Dealer's BTC position: {:.0} sats, Dealer's Short position: {:.2}, Dealer's Net PnL: {:.2}",
            dealer.btc_balance,
            dealer.short_position,
            dealer_net_pnl
        );
        println!("---");
    }
}
```
