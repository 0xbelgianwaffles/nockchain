#!/bin/bash
#
# This script must be SOURCED to correctly export environment variables
# into your current shell session.
#
# Usage: source ./generate_keys.sh
#

echo "Generating keys for Miner 1..."
output1=$(nockchain-wallet keygen)
export MINER1_PUBKEY=$(echo "$output1" | grep -a -A 1 "New Public Key" | tail -n 1 | tr -d '"')
export MINER1_PRIVKEY=$(echo "$output1" | grep -a -A 1 "New Private Key" | tail -n 1 | tr -d '"')
export MINER1_CHAINCODE=$(echo "$output1" | grep -a -A 1 "Chain Code" | tail -n 1 | tr -d '"')
export MINER1_SEEDPHRASE=$(echo "$output1" | grep -a -A 1 "Seed Phrase" | tail -n 1 | tr -d "'")

echo "Generating keys for Miner 2..."
output2=$(nockchain-wallet keygen)
export MINER2_PUBKEY=$(echo "$output2" | grep -a -A 1 "New Public Key" | tail -n 1 | tr -d '"')
export MINER2_PRIVKEY=$(echo "$output2" | grep -a -A 1 "New Private Key" | tail -n 1 | tr -d '"')
export MINER2_CHAINCODE=$(echo "$output2" | grep -a -A 1 "Chain Code" | tail -n 1 | tr -d '"')
export MINER2_SEEDPHRASE=$(echo "$output2" | grep -a -A 1 "Seed Phrase" | tail -n 1 | tr -d "'")

echo "Generating keys for Miner 3..."
output3=$(nockchain-wallet keygen)
export MINER3_PUBKEY=$(echo "$output3" | grep -a -A 1 "New Public Key" | tail -n 1 | tr -d '"')
export MINER3_PRIVKEY=$(echo "$output3" | grep -a -A 1 "New Private Key" | tail -n 1 | tr -d '"')
export MINER3_CHAINCODE=$(echo "$output3" | grep -a -A 1 "Chain Code" | tail -n 1 | tr -d '"')
export MINER3_SEEDPHRASE=$(echo "$output3" | grep -a -A 1 "Seed Phrase" | tail -n 1 | tr -d "'")

echo ""
echo "----------------------------------------------------------------"
echo "Miner keys have been exported as environment variables."
echo "You can now use them in this terminal session."
echo "e.g., echo \$MINER1_PUBKEY"
echo "----------------------------------------------------------------"