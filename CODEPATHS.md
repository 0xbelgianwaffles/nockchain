# Nockchain Developer Guide: Understanding Code Paths & Genesis

This document provides a deep-dive into the Nockchain startup process, specifically focusing on how a local development network (`devnet`) is initialized and how the genesis block is created. It is intended for developers who are working on the Nockchain codebase.

## 1. Overview: The Fakenet Genesis Problem

Setting up a local, multi-node Nockchain network for development is not as simple as launching multiple instances of the `nockchain` binary. A specific, non-obvious startup sequence is required to overcome a deadlock related to the creation of the genesis block.

The core problem is this:
*   A "leader" node is responsible for creating the genesis block.
*   The leader node does not *commit* the genesis block until it has successfully gossiped it to at least one peer.
*   The leader node does not automatically gossip the block upon peer connection.
*   The networking layer has a `KeepAliveTimeout`. If no communication occurs shortly after a connection is established, the connection is dropped.

This creates a deadlock: the leader needs to gossip to a peer, but it doesn't do so in time, causing the connection to drop. The key to solving this is creating a perfectly isolated local network where nodes are not distracted by attempts to connect to public peers.

## 2. Key Components

The genesis process involves a tight integration between the Rust backend and the Hoon kernel. Understanding their roles is crucial.

*   **`nockchain` (crate)**: The main application crate.
    *   `src/main.rs`: The application entry point.
    *   `src/config.rs`: Parses all command-line arguments (e.g., `--genesis-leader`) using `clap`.
    *   `src/lib.rs`: Wires together all the different components and drivers based on the CLI configuration.

*   **`nockchain-bitcoin-sync` (crate)**: A driver responsible for synchronizing with an external chain (Bitcoin) to seed genesis. In `fakenet` mode, this crate contains the special logic to create a deterministic test genesis block.

*   **`nockchain-libp2p-io` (crate)**: The networking layer. It manages all peer-to-peer communication using `libp2p`, including peer discovery, connection handling, and message gossip.

*   **`hoon/apps/dumbnet/inner.hoon`**: The Hoon application kernel. This is where the state machine of the blockchain is implemented. It handles incoming "pokes" (events) from the Rust drivers and produces "effects" (commands) that are sent back to the drivers.

## 3. Detailed Code Walkthrough: The Genesis Sequence

This is the step-by-step journey of a `fakenet` leader node from launch to successful genesis creation.

### Step 1: The Command Line (`config.rs`)

The process starts with the `nockchain` binary and its arguments. The most important flags for a local devnet are:
*   `--fakenet`: This is a master switch that disables the need for a live Bitcoin node and activates the test genesis logic.
*   `--genesis-leader`: This flag designates the node as the one responsible for creating the genesis block template. A node without this flag is a "watcher" or "follower".
*   `--no-default-peers`: This is the critical flag for creating an isolated network. It prevents the node from attempting to connect to a hardcoded list of public `backbone_peers`.
*   `--peer <MULTIADDR>`: Explicitly tells the node to connect to the given peer address.

### Step 2: Initialization (`lib.rs`)

Inside `init_with_kernel`, the `NockchainCli` struct is used to configure the application.

1.  **Peer Isolation**: The `--no-default-peers` flag is checked. If it is present, the list of initial peers to connect to starts empty. If it is absent, the node will try to connect to the public backbone, which causes the timeout issues on a local devnet.
2.  **Genesis Logic**: The code checks for the `--fakenet` and `--genesis-leader` flags.
    ```rust
    let node_type = if cli.as_ref().map(|c| c.genesis_leader).unwrap_or(false) {
        GenesisNodeType::Leader
    } else {
        GenesisNodeType::Watcher
    };
    let watcher_driver =
        bitcoin_watcher_driver(None, node_type, ...);
    nockapp.add_io_driver(watcher_driver).await;
    ```
    This code path ensures that for a `fakenet` leader, the `bitcoin_watcher_driver` is initialized with `GenesisNodeType::Leader`.

### Step 3: The Leader's First Move (`nockchain-bitcoin-sync/lib.rs`)

The `bitcoin_watcher_driver` is the heart of the genesis process. When started with `GenesisNodeType::Leader` and no `BitcoinRPCConnection` (because of `--fakenet`), it immediately executes this logic:

```rust
GenesisNodeType::Leader => {
    debug!("Creating test genesis block for leader node");
    let poke_slab = make_test_genesis_block(&message);
    handle.poke(wire, poke_slab).await?;
    debug!("test genesis block template sent successfully");
}
```
The driver creates a noun (a `poke_slab`) containing the `[%command %genesis ...]` event and **pokes it into the Hoon kernel**. This is an internal, self-contained event. The driver's job is now done.

### Step 4: Hoon Receives the Template (`inner.hoon`)

The Hoon kernel receives the `[%genesis]` poke. An arm in `inner.hoon` handles this event. It:
1.  Validates the template.
2.  Stores the template in its internal state (`k`).
3.  Logs the message `create genesis block with template`.
4.  Crucially, it then logs `Requesting genesis block`. This indicates that the kernel has the *idea* of the genesis block, but according to its state machine, it must now wait to *formally receive* this block from the network before it is added to the chain.

This is the origin of the deadlock. Hoon is now waiting for the network to deliver a block that only exists inside its own memory.

### Step 5: The Connection and the Missing Link (`nc.rs`)

For the gossip to happen, the leader needs a peer. The `--peer` argument on the leader (pointing to the follower) causes the `nockchain-libp2p-io` driver to establish a connection.

However, a deep analysis of `nc.rs` shows that there is **no specific "new peer connected" event** that gets poked into Hoon. The networking layer simply establishes the connection and then waits for one of two things:
1.  An incoming message from the remote peer.
2.  An effect from the Hoon kernel telling it to send a message.

Since the follower has no block to send, and the leader's Hoon kernel is never explicitly told to gossip its template upon connection, nothing happens. The `KeepAliveTimeout` is triggered, and the connection is severed.

### Step 6: The Solution - A Purely Local Network

The key is that the Hoon kernel *will* eventually decide to gossip its blocks. The problem is that without `--no-default-peers`, the Rust networking layer is simultaneously trying to connect to hardcoded public nodes. This seems to create an unstable state where the conditions for the Hoon kernel to gossip its genesis template are never met before the local connection times out.

By adding `--no-default-peers`, we create a pristine, isolated environment. The `libp2p` swarm's only task is to connect to the single local follower. This connection is stable, and in this stable state, the Hoon kernel's internal logic correctly proceeds to gossip the genesis block to its only peer. The follower receives it, gossips it back, the leader "hears" the block it was waiting for, and the chain begins.

## 4. The Correct Devnet Workflow

Based on this deep understanding, the correct and reliable procedure is:

1.  **Isolate**: Ensure the `make` targets for running nodes include the `--no-default-peers` flag.
2.  **Generate Keys**: Use the provided `generate-keys.sh` script to create and export unique keys for the leader and follower nodes.
3.  **Start the Follower First**: In a terminal, run the follower node. It will start and listen for connections. Its command will not have a `--peer` argument.
    ```bash
    make run-follower DIR=nets/follower1 PORT=5000 KEY=$FOLLOWER_PUBKEY LEADER_ADDR=""
    ```
4.  **Capture the Follower's Address**: Copy the multiaddress from the follower's log output (e.g., `/ip4/127.0.0.1/udp/5000/quic-v1/p2p/12D3Koo...`).
5.  **Start the Leader**: In a second terminal, run the leader node, passing it the follower's address via the `FOLLOWER_ADDR` variable.
    ```bash
    make run-leader FOLLOWER_ADDR=<follower_multiaddress>
    ```

The leader will start, connect *only* to the waiting follower, and the stable, isolated environment will allow the genesis process to complete successfully. 