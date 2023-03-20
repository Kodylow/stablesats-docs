# Decoupling the Galoy Backend

There are 2 points of coupling between stablesats's hedging logic and the galoy backend which we'll need to address.

1. The Target USD Liability: the accounting source of truth for how much USD stablesats hedging is responsible for
2. The BTC Wallet: hot wallet access to a mechanism to move bitcoin to and from the exchange for the coin margined trading.

Currently both of these are deeply coupled to the galoy backend, the USD liability being more deeply coupled and tricky than the second. We'll have to remove both these couplings to plug stablesats into a different backend or run it against a different asset.

## Current Architecture

`stablesats-rs`

![stablesats structure](../images/stablesats_structure.png)

The following pages are documentation notes designed to help navigate how you could most effectively go about decoupling galoy's backend from stablesats based off of a conversation with @jcarter, GaloyMoney's CTO and the architect/maintainer of stablesats-rs.
