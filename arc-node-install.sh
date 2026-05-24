#!/bin/bash

# =================================================================
# Arc Testnet Node Installer
# Guide by: @ATIKURR420 (Twitter) / atkw3 (Discord)
# =================================================================

set -e # Exit on error

echo "🚀 Starting Arc Testnet Node Installation..."

# 1. Update and Install System Dependencies
echo "📦 Installing system dependencies..."
sudo apt update && sudo apt install -qq -y \
    screen git curl build-essential pkg-config \
    libssl-dev protobuf-compiler clang libclang-dev jq

# 2. Install Foundry
echo "🔥 Installing Foundry..."
curl -L https://foundry.paradigm.xyz | bash
export PATH="$HOME/.foundry/bin:$PATH"
source ~/.bashrc
$HOME/.foundry/bin/foundryup -i v1.4.4

# 3. Install Node.js & Yarn
echo "🟢 Installing Node.js and Yarn..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g yarn

# 4. Install Rust
echo "🦀 Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
export PATH="$HOME/.cargo/bin:$PATH"

# 5. Install Buf
echo "📦 Installing Buf..."
sudo curl -sSL https://github.com/bufbuild/buf/releases/download/v1.30.0/buf-Linux-x86_64 -o /usr/local/bin/buf
sudo chmod +x /usr/local/bin/buf

# 6. Setup Screen and Build Node
echo "🖥️ Starting build process in screen session 'arc'..."
screen -S arc -dm bash -c '
    export PATH="$HOME/.cargo/bin:$HOME/.foundry/bin:$PATH";
    if [ ! -d ~/arc-node ]; then
        git clone https://github.com/circlefin/arc-node.git ~/arc-node;
    fi
    cd ~/arc-node
    git submodule update --init --recursive
    yarn install
    make build
    make testnet
    exec bash
'

echo "✅ Installation complete!"
echo "➡️ To view your node logs, run: screen -r arc"
