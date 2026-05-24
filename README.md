

## An automation script designed to quickly provision, deploy, and monitor an Arc Layer-1 stablechain node on Ubuntu environments.

Local Testnet
Run a complete Arc network on your machine — no cloud, no hardware requirements.

 What you get: five Execution nodes + five Consensus nodes running entirely on your machine, a Blockscout block explorer, and a Grafana metrics dashboard — all launched with one command. No real tokens needed. Ideal for building and testing contracts before deploying to the live testnet.

## 1. Run the Installer
```
apt update && apt install -qq -y screen git curl build-essential pkg-config libssl-dev protobuf-compiler clang libclang-dev jq && curl -L https://foundry.paradigm.xyz | bash && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt install -y nodejs && npm i -g yarn && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path && curl -sSL https://github.com/bufbuild/buf/releases/download/v1.30.0/buf-Linux-x86_64 -o /usr/local/bin/buf && chmod +x /usr/local/bin/buf && screen -S arc -dm bash -c 'export PATH="$HOME/.cargo/bin:$HOME/.foundry/bin:$PATH"; foundryup -i v1.4.4; [ -d ~/arc-node ] || git clone https://github.com/circlefin/arc-node.git ~/arc-node; cd ~/arc-node && git submodule update --init --recursive && yarn install && make build && make testnet; exec bash'

```
# What this does:
Installs everything: Rust, Node.js, Yarn, Foundry, and Buf are all set up first.

Cleans Pathing: Injects the necessary paths directly into the screen session.

Safe Cloning: It checks if the arc-node directory already exists before trying to clone, preventing "already exists" errors.

Backgrounds the Node: Runs the build and testnet commands inside a detached screen session named arc.
# How to check the progress:
Once you run the command, you won't see any output. Run this to see your node building and running:
```
screen -r arc

```
# One command launches everything.This compiles the Arc node binary from source. Rust has to compile hundreds of packages on the first run — expect 30–60 minutes. Your fans will spin. This is normal. Do not close the terminal 

## Customize the Version (Optional)

If you need to deploy a specific version of the Arc network software, pass the ARC_VERSION flag before execution:

```
ARC_VERSION=0.6.0 sudo bash arc-node-install.sh

```

## Post-Installation Access

Once the installation loop successfully completes, your local infrastructure endpoints will be fully accessible at the following destinations:

RPC Endpoint: http://localhost:8545

Block Explorer: http://localhost:4000
  - Prometheus:     http://localhost:9090
  - Grafana:        http://localhost:3000
  - Block explorer: http://localhost:80
   
This guide provides a single-command installation script for setting up an Arc Testnet node using the official infrastructure.

## 🔗 Reference Documentation
* **GitHub Repository:** [circlefin/arc-node](https://github.com/circlefin/arc-node/blob/main/docs/running-an-arc-node.md)
* **Official Technical Docs:** [docs.arc.io - Run an Arc Node](https://docs.arc.io/arc/tutorials/run-an-arc-node)

## 🤝 Need Help? Community Support

If you encounter any issues or synchronization bugs during your setup, connect with me directly through the channels below:

* **Twitter / X:** [@ATIKURR420](https://twitter.com/ATIKURR420)
* **Discord Username:** `atkw3` (Add me directly)
