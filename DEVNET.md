# Setting Up a Local Nockchain Devnet

This guide provides the definitive method for setting up a local Nockchain development network (`devnet`) on a single machine. This procedure uses `make` targets to correctly launch a leader node and a follower node, which are required to create the genesis block.

The startup process is not what you might expect. The **leader node will not create the genesis block until it connects to a peer.** Therefore, we must start a "follower" node first to give the leader a peer to connect to.

## 1. Prerequisites

Ensure you have completed the initial project setup as described in the `nockchain/README.md`, including installing dependencies and running `make build`. All commands should be run from the root of the `nockchain` repository.

## 2. Generate and Export Keys

For a realistic multi-miner setup, we need unique keys. The `generate-keys.sh` script automates this. This script also updates your `.env` file to set the leader's key as the default `MINING_PUBKEY`.

**How to use the script:**

1.  Make the script executable: `chmod +x generate-keys.sh`
2.  **Source** the script to export the keys into your current terminal session:
    ```bash
    source ./generate-keys.sh
    ```
    (You **must** use `source` for the variables to be available to the `make` commands.)

**`generate-keys.sh`:**
```bash
#!/bin/bash
# Usage: source ./generate-keys.sh

echo "Generating keys for the Leader and a Follower..."

# Leader Keys (will also be set as the default MINING_PUBKEY in .env)
output1=$(nockchain-wallet keygen)
export LEADER_PUBKEY=$(echo "$output1" | grep -a -A 1 "New Public Key" | tail -n 1 | tr -d '"')
# Update .env, creating it from .env_example if it doesn't exist
if [ ! -f .env ]; then cp .env_example .env; fi
# Remove existing MINING_PUBKEY and append the new one
sed -i'' -e '/^MINING_PUBKEY/d' .env
echo "MINING_PUBKEY=$LEADER_PUBKEY" >> .env
echo "Updated .env with leader's public key as MINING_PUBKEY."

# Follower Keys
output2=$(nockchain-wallet keygen)
export FOLLOWER_PUBKEY=$(echo "$output2" | grep -a -A 1 "New Public Key" | tail -n 1 | tr -d '"')

echo ""
echo "----------------------------------------------------------------"
echo "Miner keys have been exported as environment variables."
echo "  LEADER_PUBKEY  : $LEADER_PUBKEY"
echo "  FOLLOWER_PUBKEY: $FOLLOWER_PUBKEY"
echo "----------------------------------------------------------------"
```

## 3. Launching the Devnet

You will need three separate terminal windows for this process.

---

**In Terminal 1: Prepare Environment**

Source the key generation script. Keep this terminal open to copy the keys later if needed.

```bash
source ./generate-keys.sh
```
---

**In Terminal 2: Run the FOLLOWER Node**

In a new terminal, launch the follower node. This node will start up and wait for a connection.

```bash
make run-follower DIR=nets/follower1 PORT=5000 KEY=$FOLLOWER_PUBKEY LEADER_ADDR=""
```
*(Note: `LEADER_ADDR` is empty because this follower doesn't need to dial the leader; the leader will dial it.)*

The node will start and display its listening address and its peer ID in separate lines.
```text
I (12:09:38) nockchain: Loaded identity as peer 12D3KooWA6av4B1NXhcWiQCpN8ovwWkFmG7VJe7cBDfQnkgtuBrn
...
I (12:09:38) nc: SEvent: Listening on /ip4/127.0.0.1/udp/5000/quic-v1
```
You must combine these to form the full multiaddress. **Copy both parts and join them together with a `/` to create the full address.** It will look like this:
`/ip4/127.0.0.1/udp/5000/quic-v1/p2p/12D3KooWA6av4B1NXhcWiQCpN8ovwWkFmG7VJe7cBDfQnkgtuBrn`

We'll call this `FOLLOWER_MULTIADDR`.

---

**In Terminal 3: Run the LEADER Node**

In a third terminal, launch the leader. You must provide the follower's multiaddress that you just copied.

```bash
make run-leader FOLLOWER_ADDR=$FOLLOWER_MULTIADDR
```
The leader will start, connect to the follower using the address you provided, and then successfully create the genesis block. At this point, both nodes will begin mining on the new chain.

## 4. Verifying the Network

You can verify the network is running by checking the balances of the nodes after a few minutes.

**Check Leader's Balance:**
```bash
nockchain-wallet --nockchain-socket nets/leader/npc.sock list-notes
```

**Check Follower's Balance:**
```bash
nockchain-wallet --nockchain-socket nets/follower1/npc.sock list-notes
```

This `make`-based approach is the correct and most reliable way to launch a local devnet.