# Synthetic USD on Bitcoin with Stablesats

Crypto users who want to be able to access the price stability of the U.S dollar (USD) can get it either through:

- Direct banking access, by depositing and withdrawing traditional currency
- Indirect banking access, by converting some of their holdings into stablecoins

Both require some sort of banking access. But in some cases, this is not practical. For both crypto companies and traders, a tool allowing USD price exposure without the need for a traditional banking relationship would come very handy. Some claim Bitcoin-based synthetic USD could be the answer. If that sounds weird, interesting or even slightly frightening, bear with us and read on. 👇

## What are synthetic dollars?

The basic insight behind synthetic dollars is that by holding two inversely related assets one can maintain, in aggregate, a stable USD price. Arthur Hayes first proposed the idea in a 2014 blog post. The concept is pretty straightforward:

- A user locks in, say, 100 USD worth of Bitcoin by opening a hedge through a derivatives exchange.
- If the price of Bitcoin goes up, the value of the hedge goes down proportionally.
- If the price of Bitcoin goes down, the value of the hedge goes up proportionally.
- When the user closes the hedge position, they should end up with 100 USD worth of Bitcoin, same as when they first opened the position.

__On paper, the price of Bitcoin could swing with enormous volatility and the net position would remain the same.__

## Digging deeper

In crypto we like to use Alice and Bob examples, and when there's a "dealer" or superuser of some kind (in this case, a crypto derivatives exchange) we like to call him Dave.

Imagine Alice holds 1 million satoshis in her Bitcoin account and wishes to move $120 to a synthetic USD account. If the price of Bitcoin was $30,000:

Alice would allocate ~400,000 satoshis for the synthetic USD account, locked-in with Dave the Dealer.

She would keep 600,000 satoshis in her Bitcoin account, valued at $180.
Dave would receive the deposit of 400,000 satoshis and open a corresponding short position, on OKX for example, by shorting the BTC/USD perpetual inverse swap, which moves inversely in price to the USD price of Bitcoin.

Now let's skip to three months later and consider two scenarios. In the first case, the Bitcoin price falls by 50%, down to $15,000:

Alice's Bitcoin account still has 600,000 satoshis, now worth $90.
Her synthetic USD account, comprising the net position between the Bitcoin she moved to Dave and the value of the short position, is now worth 800,000 satoshis or $120.

In the second case, the Bitcoin price surges by 100% to $60,000:

Alice's Bitcoin account still has 600,000 satoshis, now worth $360.
Her synthetic USD account, consisting of the net position between the Bitcoin she transferred to Dave and the value of the short position, is now worth 200,000 satoshis or $120.

In both cases, Alice's synthetic USD position would remain stable, thanks to hedging. Dave the Dealer's physical BTC profit would be +$120, and his short position loss would be -$120, resulting in a net profit and loss of $0. This is called a delta-neutral trade: the person implementing this strategy would not expose themselves to Bitcoin's volatile price swings, either to the upside or downside.

This strategy requires no banking relationship for the user (who can self custody the Bitcoin) or for the exchange where they're placing the hedge. The user still trusts the exchange to a degree, but would benefit from a stable USD price with zero interaction anywhere up or down the stack with banking infrastructure. Companies like Galoy are working hard to provide the necessary ecosystem through a product known as "Stablesats".

## What's Stablesats?

Stablesats is an already working, open-source, implementation of synthetic USD. I'ts built on top of Bitcoin by Galoy. Galoy builds open source Bitcoin banking infrastructure across the world and they observed that even if businesses want to exclusively use Bitcoin as a medium of exchange, merchants and users still need USD price stability for their unit of account. When the Bitcoin price declines, the purchasing power of sats declines too, making it more difficult to afford dollar-priced goods and services. This leads to instability and uncertainty, causing merchants and consumers to contemplate converting Bitcoin to dollars to meet their financial obligations.

Stablesats provides a USD account feature in the Blink Wallet (formerly Bitcoin Beach Wallet). The feature allows users to maintain "dollar equivalent" balances alongside their Bitcoin. It is designed from the ground up for deployment at enterprise scale. While today the feature exclusively uses OKX for derivatives hedging, it will soon support position management across multiple exchanges to improve market making and limit the reliance on a single exchange.

Stablesats can be adapted by companies who want to maintain a synthetic USD balance for their operating capital, regardless of banking relationships.

## What's next for synthetic dollars?

Stablesats is an example of the promise of the crypto industry. It allows anyone, anywhere, to access stable USD price exposure with some Bitcoin and a place to short it. While there are currently some couplings of Stablesats to Galoy's backend, OKX is looking to support open source work and hackathons to generalize the use of synthetic dollars with any Bitcoin or crypto wallet. Engineers at OKX have already begun preliminary work documenting how wallet developers can use Stablesats to add USD balances to their existing applications. If you think you'd be a fit, reach out!