# Price Oracles

Synthetic USD has a critical reliance on having on accurate price of bitcoin. This requires a price "oracle": a source of truth. This can be a single source, the aggregation of multiple sources, or a price mechanism derived from liquidity/stability pools in defi. The point is you need to get the price from somewhere so you can track the relative value of the perpetual inverse swaps.

## Price Oracle Tradeoffs

The price oracle provides the current Bitcoin price in USD, which is essential for calculating the position's PNL and total equity balance. However, relying on a price oracle introduces certain tradeoffs:

- Centralization: Fetching the price from a single source can lead to centralization, making the system susceptible to manipulation or errors.
- Trust: The price oracle's accuracy and reliability are crucial, requiring trust in the price source.
- Latency: Price data fetched from multiple sources or DeFi stability pools may have different latency, which can result in discrepancies in the calculated positions. Even getting pricing data from a single source has latency issues, some exchanges have better latency than others.

## Single Source of Truth

A basic price oracle implementation fetches the Bitcoin price from a single exchange. This is the easiest "just trust me bro" way to do this, and for the positioning on a single exchange you'll probably have to use that exchange itself as the price oracle. For example, stablesats-rs as it exists today uses OKX for the exchange part and also uses its price data. Here's the pseudocode for a single price oracle...

```rust,editable
extern crate reqwest;

use reqwest::Error;

trait PriceOracle {
    fn get_btc_price_usd(&self) -> Result<f64, Error>;
}

struct SingleExchangePriceOracle;

impl PriceOracle for SingleExchangePriceOracle {
    fn get_btc_price_usd(&self) -> Result<f64, Error> {
        let response: reqwest::Result<String> = reqwest::blocking::get("https://api.exchange.com/btc_usd")?.text();
        let price: f64 = response?.parse()?;
        Ok(price)
    }
}
```

## Multi-Source Price Oracle

A more complex implementation fetches the Bitcoin price from multiple sources, including for example DeFi stability pools, and assigns relative weighting to the sources. For example, the pseudocode might look like this:

```rust,editable
struct MultiSourcePriceOracle {
    sources: HashMap<String, (String, f64)>,
}

impl MultiSourcePriceOracle {
    fn new(sources: HashMap<String, (String, f64)>) -> Self {
        MultiSourcePriceOracle { sources }
    }
}

impl PriceOracle for MultiSourcePriceOracle {
    fn get_btc_price_usd(&self) -> Result<f64, Error> {
        let mut total_price = 0.0;
        let mut total_weight = 0.0;

        for (name, (url, weight)) in self.sources.iter() {
            let response: reqwest::Result<String> = reqwest::blocking::get(url)?.text();
            let price: f64 = response?.parse()?;
            total_price += price * weight;
            total_weight += weight;
            println!("{}: {} * {} = {}", name, price, weight, price * weight);
        }

        if total_weight > 0.0 {
            Ok(total_price / total_weight)
        } else {
            Err(reqwest::Error::new(reqwest::StatusCode::INTERNAL_SERVER_ERROR, "No price data"))
        }
    }
}
```

### Relative Weighting of the Pricing Sources

You can equally weight the sources, but some exchanges and sources of price data are probably more reliable than others. If you're going to use multiple sources, you should probably assign relative weightings for them based off their latency, order book depth, and reliability.

```rust,editable
let mut sources = HashMap::new();
sources.insert("OKX".to_string(), ("https://api.okx.com/api/v3/ticker.do?symbol=btc_usdt".to_string(), 0.4));
sources.insert("BitMex".to_string(), ("https://www.bitmex.com/api/v1/trade?symbol=XBTUSD&count=1&reverse=true".to_string(), 0.2));
sources.insert("Bitfinex".to_string(), ("https://api-pub.bitfinex.com/v2/ticker/tBTCUSD".to_string(), 0.3));
sources.insert("SomeDefiProtocol".to_string(), ("https://somedefiprotocol.com/v1/ticker/BTC_USD"));
let oracle = MultiSourcePriceOracle::new(sources);
```

## Position Sizing

Futures are generally traded in units of $100, so the synthUSD implementation should calculate the target USD liability to the nearest unit of $100. This naturally leans toward implementing synthUSD as a custodial solution, for example GaloyMoney's stablesats implementation calculates an aggregate USD liability for all its users and runs the hedging against that aggregate liability. Whatever implementation you decide on, you'll have to add logic that adjusts the target to the nearest $100 denomination.
