# Decoupling the Galoy Backend

There are 2 points of coupling between stablesats's hedging logic and the galoy backend which we'll need to address.

1. The Target USD Liability: the accounting source of truth for how much USD stablesats hedging is responsible for
2. The BTC Wallet: hot wallet access to a mechanism to move bitcoin to and from the exchange for the coin margined trading.

Currently both of these are deeply coupled to the galoy backend, the USD liability being more deeply coupled and tricky than the second. We'll have to remove both these couplings to plug stablesats into a different backend or run it against a different asset.

## Current Architecture

`stablesats-rs` is currently organized as a binary with several subcrates and a cli. The main modules that can be run via the cli are:

- `okex-price`: Module that streams price information from okex onto the pubsub
- `price-server`: Module that exposes a grpc endpoint for clients to get up-to-date price information (cached from the pubsub messages coming from okex-price).
- `user_trades`: Module that identifies how much the total usd liability exists in the galoy accounting ledger. It publishes the SynthUsdLiabilityPayload message for downstream trading modules to pick up.
- `hedging`: Module that executes trades on okex to match the target liability received from the pubsub.

![stablesats structure](../images/stablesats_structure.png)

The following pages are documentation notes designed to help navigate how you could most effectively go about decoupling galoy's backend from stablesats based off of a conversation with @jcarter, GaloyMoney's CTO and the architect/maintainer of stablesats-rs.

## Running stablesats-rs Locally with Docker

Again, it's still coupled to galoy's backend, but the basic steps to run the project are:

1. Fork the repo and clone it down locally.
2. You'll need Docker, cargo, cargo-nextest, cargo-watch, and sqlx-cli installed (and make sure you don't have postgres or redis running locally, stablesats will start them up via docker compose and do the db migration at when you run the reset).
3. Change the environment variables in the .envrc file and use `direnv` to load them into your shell, particularly your OKX api key
4. Stablesats uses `make` for builds. You'll first want to run
`make reset-deps-local` to setup the dependencies, postgres/redis, and the environment.
5. Then run `make next-watch` to run the test suite, either at the project level or in each individual crate. Sometimes `cargo watch` doesn't work so if you're having issues here try just running `cargo nextest run` in each crate. It will skip a lot of the tests to not hit the okx api rate limits, but they're worth reading just to see how they work in the context of the wider project.

## Running stablesats-rs Locally with Nix

If (like me) you don't like docker and would prefer to use nix, you can clone down my `nix-flake-stablesats` branch at [https://github.com/Kodylow/stablesats-rs/tree/nix-flake-stablesats](https://github.com/Kodylow/stablesats-rs/tree/nix-flake-stablesats) which is exactly the same but with a nix flake and JUSTFILE. Just install nix, enable commands and flakes, then run:

1. `nix develop`
2. `just reset-deps-local`
3. `just next-watch`

To avoid all the dockering.
