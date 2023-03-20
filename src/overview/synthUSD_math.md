# Synthetic USD with Bitcoin and Perpetual Inverse Swaps

This documentation explains how to create synthetic USD using Bitcoin and perpetual inverse swaps via OKX, with the aim of "locking" a net USD price between the 2 assets that synthetically behaves like a stable USD price for the underlying assets.

## Technical Description of Synthetic USD Math

To create a synthetic USD asset, we use a combination of Bitcoin and an inverse Bitcoin/USD perpetual swap. The synthetic asset, called synthUSD, is defined as follows (math taken from Arthur Hayes' Dust on Crust):

1 synthUSD = $1 of Bitcoin + Short 1 Bitcoin / Perpetual Inverse Swap


The perpetual inverse swap pays out $1 of Bitcoin in Bitcoin at any price. Its payoff function is:

$1 / Bitcoin Price in USD

If Bitcoin is worth $1, then the Bitcoin value of the perpetual swap is 1 BTC, $1 / $1.

If Bitcoin is worth $0.5, then the Bitcoin value of the perpetual swap is 2 BTC, $1 / $0.5.

If Bitcoin is worth $2, then the Bitcoin value of the perpetual swap is 0.5 BTC, $1 / $2.

To create 1 synthUSD, a user can deposit 1 BTC on an exchange (in our case OKX) and coin margin it to short 1 Bitcoin/USD inverse perpetual swap.

The synthetic USD asset is designed to be inversely correlated with Bitcoin price. As the price of Bitcoin goes up, the value of the shorted inverse perpetual swap goes down, causing the synthetic USD price to stay stable. Conversely, as the price of Bitcoin goes down, the value of the shorted inverse perpetual swap goes up, causing the synthetic USD price to stay stable.

This math is implemented in Rust code below. Try changing the percentage moves up or down in the code and running it, you'll see that the synthetic value of the 2 assets combined remains stable in USD even for extremely violent Bitcoin price fluctations...

```rust,editable
fn main() {
    let btc_price: f64 = 100_000.0;
    let user_btc: f64 = 10.0;
    let user_usd_locked: f64 = 200_000.0;

    // Amount of Bitcoin to be locked
    let btc_locked = user_usd_locked / btc_price;

    // Half of the locked Bitcoin is used to buy the perpetual inverse swap
    let btc_to_swap = btc_locked / 2.0;

    // Initial values
    let initial_btc_value = user_btc * btc_price;
    let initial_locked_btc_value = btc_locked * btc_price;
    let initial_inverse_swap_value = btc_to_swap * btc_price;
    let initial_total_usd_value = initial_locked_btc_value + initial_inverse_swap_value;

    println!("Initial Prices: BTC-USD:{:.2} User BTC:{:.2} Locked BTC:{:.2} Inverse Swap:{:.2} Total Locked Value:${:.2}", btc_price, initial_btc_value, initial_locked_btc_value, initial_inverse_swap_value, initial_total_usd_value);

    // Simulate a 20% increase in Bitcoin price
    let new_btc_price = btc_price * 1.2;

    // New value of user's remaining Bitcoin
    let new_btc_value = (user_btc - btc_locked) * new_btc_price;

    // New value of the locked bitcoin
    let new_locked_btc_value = btc_locked * new_btc_price;

    // New value of the inverse perpetual swap
    let new_inverse_swap_value = (btc_to_swap * btc_price) / new_btc_price;

    // New total value of the locked assets in USD
    let new_total_usd_value = new_locked_btc_value + new_inverse_swap_value;

    println!("New Prices: BTC-USD:{:.2} User BTC:{:.2} Locked BTC:{:.2} Inverse Swap:{:.2} Total Locked Value:${:.2}", new_btc_price, new_btc_value, new_locked_btc_value, new_inverse_swap_value, new_total_usd_value);

    // Loop to simulate random price changes
    for i in 1..6 {
        let random_btc_price = btc_price * (1.0 + (i as f64) / 10.0);
        let random_locked_btc_value = btc_locked * random_btc_price;
        let random_inverse_swap_value = (btc_to_swap * btc_price) / random_btc_price;
        let random_total_usd_value = random_locked_btc_value + random_inverse_swap_value;

        println!("Random Prices {}: BTC-USD:{:.2} User BTC:{:.2} Locked BTC:{:.2} Inverse Swap:{:.2} Total Locked Value:${:.2}", i, random_btc_price, random_btc_value, random_locked_btc_value, random_inverse_swap_value, random_total_usd_value);
    }
}
```

### Benefits: NO BANKS UP OR DOWN THE STACK

- "This method allows us to synthetically create a USD equivalent without touching USD held in the fiat banking system or a stablecoin that exists in crypto. Moreover, it does not require more crypto collateral than it creates in fiat value, unlike MakerDAO." - Arthur Hayes

- Synthetic USD requires NO banking relationships. This is especially important today as banks continue to lever up their rehypothecation of depositors' assets. Once the galoy backend is removed from stablesats, you'll be able to run stablesats synthetic USD hedging with nothing but a bitcoin wallet and an OKX API key and maintain maximal sovereignty over your wealth.

### Risks

- Counterparty Risk: while synthUSD does not touch banks, it does require an exchange (centralized or otherwise) offerring coin-margined perpetual inverse swap contracts. There are several exchanges that offer this today so can diversify across them, but you are implicitly trusting the exchange while you implement the hedge.

- Liquidity Risk: synthetic usd operates on the inverse correlation between the 2 assets being properly priced. Accurate pricing requires deep, responsive order books which make this hedging strategy operate best (today) on the larger centralized exchanges, particularly OKX. While this hedging strategy could in theory be implemented using defi and stability pools. We highly recommend developing working implementations against cefi exchanges to prove the use before diversifying the hedging locations to other cefi exchanges and eventually defi.
