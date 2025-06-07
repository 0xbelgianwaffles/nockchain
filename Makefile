# Load environment variables from .env file
include .env

# Set default env variables if not set in .env
export RUST_BACKTRACE ?= full
export RUST_LOG ?= info,nockchain=info,nockchain_libp2p_io=info,libp2p=info,libp2p_quic=info
export MINIMAL_LOG_FORMAT ?= true
export MINING_PUBKEY ?= 3u5yn5Zx473y4QT5zWJCMfBEwQAGM7rJModnFiCQyQ4im2sLyuPLtoFkGbTTcoMCR5az7n7Ag7k966yx1FwDsiG7aq42Dz4xMhnJPfYGSS4W7kq1niVtaNQYKH5CDrWGiHUy
export

.PHONY: build
build: build-hoon-all build-rust
	$(call show_env_vars)

## Build all rust
.PHONY: build-rust
build-rust:
	cargo build --release

## Run all tests
.PHONY: test
test:
	cargo test --release

.PHONY: install-hoonc
install-hoonc: nuke-hoonc-data ## Install hoonc from this repo
	$(call show_env_vars)
	cargo install --locked --force --path crates/hoonc --bin hoonc

.PHONY: update-hoonc
update-hoonc:
	$(call show_env_vars)
	cargo install --locked --path crates/hoonc --bin hoonc

.PHONY: install-nockchain
install-nockchain: build-hoon-all
	$(call show_env_vars)
	cargo install --locked --force --path crates/nockchain --bin nockchain

.PHONY: update-nockchain
update-nockchain: build-hoon-all
	$(call show_env_vars)
	cargo install --locked --path crates/nockchain --bin nockchain


.PHONY: install-nockchain-wallet
install-nockchain-wallet: build-hoon-all
	$(call show_env_vars)
	cargo install --locked --force --path crates/nockchain-wallet --bin nockchain-wallet

.PHONY: update-nockchain-wallet
update-nockchain-wallet: build-hoon-all
	$(call show_env_vars)
	cargo install --locked --path crates/nockchain-wallet --bin nockchain-wallet

.PHONY: ensure-dirs
ensure-dirs:
	mkdir -p hoon
	mkdir -p assets

.PHONY: build-trivial
build-trivial: ensure-dirs
	$(call show_env_vars)
	echo '%trivial' > hoon/trivial.hoon
	hoonc --arbitrary hoon/trivial.hoon

HOON_TARGETS=assets/dumb.jam assets/wal.jam assets/miner.jam

.PHONY: nuke-hoonc-data
nuke-hoonc-data:
	rm -rf .data.hoonc
	rm -rf ~/.nockapp/hoonc

.PHONY: nuke-assets
nuke-assets:
	rm -f assets/*.jam

.PHONY: build-hoon-all
build-hoon-all: nuke-assets update-hoonc ensure-dirs build-trivial $(HOON_TARGETS)
	$(call show_env_vars)

.PHONY: build-hoon
build-hoon: ensure-dirs update-hoonc $(HOON_TARGETS)
	$(call show_env_vars)

.PHONY: run-nockchain
run-nockchain:  # Run a nockchain node in follower mode with a mining pubkey
	$(call show_env_vars)
	mkdir -p miner-node && cd miner-node && rm -f nockchain.sock && RUST_BACKTRACE=1 cargo run --release --bin nockchain -- --npc-socket nockchain.sock --mining-pubkey $(MINING_PUBKEY) --mine

.PHONY: run-nockchain-leader
run-nockchain-leader:  # Run nockchain mode in leader mode
	$(call show_env_vars)
	mkdir -p test-leader && cd test-leader && rm -rf .data.nockchain && RUST_BACKTRACE=1 cargo run --release --bin nockchain -- --fakenet --genesis-leader --npc-socket nockchain.sock --mining-pubkey $(MINING_PUBKEY) --bind /ip4/0.0.0.0/udp/3005/quic-v1 --new-peer-id --no-default-peers

.PHONY: run-nockchain-follower
run-nockchain-follower:  # Run nockchain mode in follower mode
	$(call show_env_vars)
	mkdir -p test-follower && cd test-follower && rm -rf .data.nockchain && RUST_BACKTRACE=1 cargo run --release --bin nockchain -- --fakenet --genesis-watcher --npc-socket nockchain.sock --mining-pubkey $(MINING_PUBKEY) --bind /ip4/0.0.0.0/udp/3006/quic-v1 --peer /ip4/127.0.0.1/udp/3005/quic-v1 --new-peer-id --no-default-peers

HOON_SRCS := $(find hoon -type file -name '*.hoon')

## Build dumb.jam with hoonc
assets/dumb.jam: update-hoonc hoon/apps/dumbnet/outer.hoon $(HOON_SRCS)
	$(call show_env_vars)
	RUST_LOG=trace hoonc hoon/apps/dumbnet/outer.hoon hoon
	mv out.jam assets/dumb.jam

## Build wal.jam with hoonc
assets/wal.jam: update-hoonc hoon/apps/wallet/wallet.hoon $(HOON_SRCS)
	$(call show_env_vars)
	RUST_LOG=trace hoonc hoon/apps/wallet/wallet.hoon hoon
	mv out.jam assets/wal.jam

## Build mining.jam with hoonc
assets/miner.jam: update-hoonc hoon/apps/dumbnet/miner.hoon $(HOON_SRCS)
	$(call show_env_vars)
	RUST_LOG=trace hoonc hoon/apps/dumbnet/miner.hoon hoon
	mv out.jam assets/miner.jam

#
# Local Devnet Targets
#

# Cleans old data and runs a genesis leader node. Uses MINING_PUBKEY from .env
# Usage: make run-leader
.PHONY: run-leader
run-leader:
	mkdir -p nets/leader
	cd nets/leader && rm -rf .data.nockchain && \
	echo "Starting genesis leader..." && \
	RUST_BACKTRACE=1 cargo run --release --bin nockchain -- \
		--mine --mining-pubkey $(MINING_PUBKEY) \
		--bind /ip4/127.0.0.1/udp/4000/quic-v1 \
		$(if $(FOLLOWER_ADDR),--peer $(FOLLOWER_ADDR),) \
		--npc-socket ./npc.sock \
		--fakenet --genesis-leader --no-default-peers

# Cleans old data and runs a follower node.
# Usage: make run-follower DIR=nets/follower1 PORT=5000 KEY=$(FOLLOWER_PUBKEY) LEADER_ADDR=$(LEADER_MULTIADDR)
.PHONY: run-follower
run-follower:
	mkdir -p $(DIR)
	cd $(DIR) && rm -rf .data.nockchain && \
	echo "Starting follower in $(DIR) on port $(PORT)..." && \
	RUST_BACKTRACE=1 cargo run --release --bin nockchain -- \
		--mine --mining-pubkey $(KEY) \
		--bind /ip4/127.0.0.1/udp/$(PORT)/quic-v1 \
		$(if $(LEADER_ADDR),--peer $(LEADER_ADDR),) \
		--npc-socket ./npc.sock \
		--fakenet --genesis-watcher --no-default-peers
