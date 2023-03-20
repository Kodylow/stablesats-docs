# Synthetic USD on Bitcoin with Stablesats

## Structure of this Documentation

- [Introduction](introduction.md)
- [Synthetic USD Conceptual Overview](overview.md)
  - [Motivation](overview/motivation.md)
  - [How the Math Works](overview/synthUSD_math.md)
  - [An Alice and Bob Example](overview/alice_and_bob_synthUSD.md)
  - [Visualizations](overview/synthUSD_visualizations.md)
  - [Hedging Strategies via Coin Margined Futures Contracts and Derivatives](overview/hedging.md)
    - [Coin Margined Trading](overview/hedging/coin_margin.md)
    - [Futures Contracts Definitions](overview/hedging/futures.md)
    - [Price Oracles and Managing Position Sizing](overview/price_oracles.md)
    - [OKX Specific Contracts and Derivatives We Use](overview/hedging/okx_contracts.md)
- [Stablesats: GaloyMoney's Open Source SynthUSD Implementation](galoy_stablesats.md)
  - [Background on the Stablesats Implementation](galoy/background.md)
- [stablesats-rs : How it Works and How to Change It](stablesats_rust.md)
  - [Technical Docs: the Current Architecture](sats_rust/architecture.md)
  - [How to Decouple the Galoy Backend](sats_rust/decoupling.md)
    - [Pointing it at a new Bitcoin Wallet](sats_rust/bitcoin_wallet.md)
    - [Pointing it at a new USD Target Liability](sats_rust/usd_liability.md)
- [Assorted Notes That Will Help with Decoupling](assorted_notes_decoupling.md)