#!/usr/bin/env bash
# ============================================================
#  ARC LOCAL TESTNET NODE — ONE-CLICK INSTALLER
#  Source: https://github.com/circlefin/arc-node
#  Docs:   https://docs.arc.io/build
#  ============================================================
set -euo pipefail

# ─── COLORS ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()    { echo -e "${GREEN}[✓]${RESET} $*"; }
info()   { echo -e "${CYAN}[→]${RESET} $*"; }
warn()   { echo -e "${YELLOW}[!]${RESET} $*"; }
error()  { echo -e "${RED}[✗]${RESET} $*"; exit 1; }
banner() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════${RESET}"; \
           echo -e "${BOLD}${CYAN}  $*${RESET}"; \
           echo -e "${BOLD}${CYAN}══════════════════════════════════════${RESET}\n"; }

# ─── CONFIGURATION ─────────────────────────────────────────
ARC_VERSION="${ARC_VERSION:-0.6.0}"          # Pin version (change if needed)
ARC_HOME="${ARC_HOME:-$HOME/.arc}"
ARC_BIN_DIR="${ARC_BIN_DIR:-$ARC_HOME/bin}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/arc-node}"
NETWORK="${NETWORK:-local}"                  # local | testnet

# ─── LOCAL TESTNET PORTS ───────────────────────────────────
EL_RPC_PORT=8545
EL_WS_PORT=8546
CL_RPC_PORT=31000
METRICS_PORT=9001
EXPLORER_PORT=4000

# ============================================================
#  STEP 0 — PREFLIGHT CHECKS
# ============================================================
banner "Arc Node Installer v${ARC_VERSION}"

info "Checking OS..."
OS=$(uname -s)
ARCH=$(uname -m)
[[ "$OS" != "Linux" ]] && error "This script supports Linux only. Got: $OS"
[[ "$ARCH" != "x86_64" ]] && warn "Architecture $ARCH detected — AMD64 recommended"

info "Checking available disk space..."
FREE_GB=$(df -BG "$HOME" | awk 'NR==2{gsub("G",""); print $4}')
[[ "$FREE_GB" -lt 20 ]] && warn "Less than 20GB free disk space detected ($FREE_GB GB)"

info "Checking RAM..."
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
[[ "$TOTAL_RAM_GB" -lt 8 ]] && warn "Less than 8GB RAM detected — node may be slow"

log "Preflight checks complete"

# ============================================================
#  STEP 1 — SYSTEM DEPENDENCIES
# ============================================================
banner "Step 1: Installing System Dependencies"

info "Updating apt package list..."
apt-get update -qq

info "Installing core dependencies..."
apt-get install -y -qq \
    curl wget git build-essential pkg-config \
    libssl-dev ca-certificates gnupg lsb-release \
    jq unzip screen htop net-tools

log "System dependencies installed"

# ============================================================
#  STEP 2 — DOCKER
# ============================================================
banner "Step 2: Installing Docker"

if command -v docker &>/dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    log "Docker already installed: $DOCKER_VERSION"
else
    info "Installing Docker Engine..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

    systemctl enable docker
    systemctl start docker
    log "Docker installed successfully"
fi

# Docker Compose check
if docker compose version &>/dev/null; then
    log "Docker Compose plugin available"
elif command -v docker-compose &>/dev/null; then
    log "docker-compose available"
else
    info "Installing docker-compose standalone..."
    COMPOSE_VERSION="2.24.6"
    curl -SL "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    log "docker-compose installed"
fi

# ============================================================
#  STEP 3 — RUST (needed to build from source if required)
# ============================================================
banner "Step 3: Installing Rust"

if command -v rustc &>/dev/null; then
    RUST_VERSION=$(rustc --version | awk '{print $2}')
    log "Rust already installed: $RUST_VERSION"
else
    info "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable
    source "$HOME/.cargo/env"
    log "Rust installed: $(rustc --version)"
fi

# Ensure cargo is in PATH
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# ============================================================
#  STEP 4 — INSTALL ARC NODE BINARIES (via arcup)
# ============================================================
banner "Step 4: Installing Arc Node Binaries"

mkdir -p "$ARC_BIN_DIR"

if [[ -f "$ARC_BIN_DIR/arc-node-execution" ]]; then
    EXISTING_VER=$("$ARC_BIN_DIR/arc-node-execution" --version 2>/dev/null | awk '{print $2}' || echo "unknown")
    log "arc-node-execution already installed: $EXISTING_VER"
    if [[ "$EXISTING_VER" != "$ARC_VERSION" ]]; then
        warn "Version mismatch (installed: $EXISTING_VER, wanted: $ARC_VERSION). Reinstalling..."
        REINSTALL=true
    else
        REINSTALL=false
    fi
else
    REINSTALL=true
fi

if [[ "$REINSTALL" == "true" ]]; then
    info "Installing Arc node via arcup..."
    curl -L https://raw.githubusercontent.com/circlefin/arc-node/main/arcup/install \
        | bash -s -- --version "$ARC_VERSION"

    # Load env so binaries are in PATH
    ENV_FILE="$ARC_HOME/env"
    [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
    export PATH="$ARC_BIN_DIR:$PATH"

    # Add to .bashrc permanently
    if ! grep -q "ARC_BIN_DIR" "$HOME/.bashrc"; then
        echo "export ARC_HOME=$ARC_HOME" >> "$HOME/.bashrc"
        echo "export ARC_BIN_DIR=$ARC_BIN_DIR" >> "$HOME/.bashrc"
        echo 'export PATH="$ARC_BIN_DIR:$PATH"' >> "$HOME/.bashrc"
    fi

    log "Arc binaries installed"
fi

# Verify binaries
export PATH="$ARC_BIN_DIR:$PATH"
for bin in arc-node-execution arc-node-consensus arc-snapshots; do
    if command -v "$bin" &>/dev/null || [[ -f "$ARC_BIN_DIR/$bin" ]]; then
        log "$bin ✓"
    else
        warn "$bin not found in PATH — may need manual PATH setup"
    fi
done

# ============================================================
#  STEP 5 — CLONE arc-node REPO
# ============================================================
banner "Step 5: Fetching arc-node Repository"

if [[ -d "$INSTALL_DIR/.git" ]]; then
    log "Repository already exists at $INSTALL_DIR"
    info "Pulling latest changes..."
    cd "$INSTALL_DIR"
    git fetch --tags
    git checkout "v${ARC_VERSION}" 2>/dev/null || warn "Tag v${ARC_VERSION} not found, using main"
else
    info "Cloning circlefin/arc-node..."
    git clone https://github.com/circlefin/arc-node.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    git checkout "v${ARC_VERSION}" 2>/dev/null || warn "Tag v${ARC_VERSION} not found, using main"
    git submodule update --init --recursive
    log "Repository cloned to $INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# ============================================================
#  STEP 6 — CONFIGURE .env
# ============================================================
banner "Step 6: Configuring Environment Variables"

ENV_FILE="$INSTALL_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
    warn ".env already exists — backing up to .env.bak"
    cp "$ENV_FILE" "${ENV_FILE}.bak"
fi

cat > "$ENV_FILE" <<EOF
# ─── Arc Node Configuration ────────────────────────────────
# Generated by arc-node-install.sh on $(date)
# Docs: https://docs.arc.io/arc/tutorials/run-an-arc-node

# ── Version ────────────────────────────────────────────────
ARC_VERSION=${ARC_VERSION}

# ── Network ────────────────────────────────────────────────
# Options: local | arc-testnet
NETWORK=local

# ── Data Directories ───────────────────────────────────────
ARC_HOME=${ARC_HOME}
EXECUTION_DATA_DIR=\${ARC_HOME}/execution
CONSENSUS_DATA_DIR=\${ARC_HOME}/consensus

# ── Execution Layer (RPC) ──────────────────────────────────
EL_HTTP_PORT=${EL_RPC_PORT}
EL_WS_PORT=${EL_WS_PORT}
EL_AUTH_PORT=8551
EL_P2P_PORT=30303
EL_METRICS_PORT=${METRICS_PORT}

# ── Consensus Layer ────────────────────────────────────────
CL_RPC_PORT=${CL_RPC_PORT}
CL_P2P_PORT=27000
CL_METRICS_PORT=29000

# ── Explorer (Blockscout) ──────────────────────────────────
EXPLORER_PORT=${EXPLORER_PORT}

# ── Logging ────────────────────────────────────────────────
LOG_LEVEL=info

# ── Fee Recipient (optional — for testnet) ─────────────────
# FEE_RECIPIENT=0xYourWalletAddressHere
EOF

log ".env configured at $ENV_FILE"

# ============================================================
#  STEP 7 — DATA DIRECTORIES
# ============================================================
banner "Step 7: Creating Data Directories"

mkdir -p "$ARC_HOME/execution"
mkdir -p "$ARC_HOME/consensus"

# Required by arc-snapshots container
sudo install -d -o "$USER" /run/arc 2>/dev/null || \
    (mkdir -p /run/arc && chmod 755 /run/arc)

log "Data directories created at $ARC_HOME"

# ============================================================
#  STEP 8 — PULL DOCKER IMAGES
# ============================================================
banner "Step 8: Pulling Docker Images"

info "Pulling Arc execution image..."
docker pull "docker.cloudsmith.io/circle/arc-network/arc-execution:${ARC_VERSION}" \
    && log "arc-execution image pulled" \
    || warn "Could not pull arc-execution — will use local build"

info "Pulling Arc consensus image..."
docker pull "docker.cloudsmith.io/circle/arc-network/arc-consensus:${ARC_VERSION}" \
    && log "arc-consensus image pulled" \
    || warn "Could not pull arc-consensus — will use local build"

# ============================================================
#  STEP 9 — OPEN FIREWALL PORTS
# ============================================================
banner "Step 9: Configuring Firewall"

if command -v ufw &>/dev/null; then
    ufw allow "${EL_RPC_PORT}/tcp"   2>/dev/null && log "Port ${EL_RPC_PORT} (EL RPC) open"
    ufw allow "${EL_WS_PORT}/tcp"    2>/dev/null && log "Port ${EL_WS_PORT} (EL WS) open"
    ufw allow "30303/tcp"            2>/dev/null && log "Port 30303 (P2P) open"
    ufw allow "27000/tcp"            2>/dev/null && log "Port 27000 (CL P2P) open"
else
    warn "ufw not found — skipping firewall config"
fi

# ============================================================
#  STEP 10 — START LOCAL TESTNET
# ============================================================
banner "Step 10: Starting Arc Local Testnet"

cd "$INSTALL_DIR"

# Use docker compose (plugin) or docker-compose (standalone)
COMPOSE_CMD="docker compose"
command -v docker-compose &>/dev/null && COMPOSE_CMD="docker-compose"

info "Building local testnet images..."
make testnet-build 2>/dev/null || {
    warn "make testnet-build failed — trying docker compose directly"
    $COMPOSE_CMD -f deployments/docker-compose.local.yml build 2>/dev/null || true
}

info "Starting local testnet (5 EL + 5 CL nodes + Blockscout)..."
make testnet-up 2>/dev/null || {
    warn "make testnet-up failed — trying docker compose directly"
    $COMPOSE_CMD -f deployments/docker-compose.local.yml up -d 2>/dev/null \
    || $COMPOSE_CMD up -d
}

log "Local testnet started!"

# ============================================================
#  STEP 11 — WAIT & VERIFY
# ============================================================
banner "Step 11: Verifying Node is Running"

info "Waiting 30 seconds for node to initialize..."
sleep 30

MAX_RETRIES=10
RETRY=0
while [[ $RETRY -lt $MAX_RETRIES ]]; do
    BLOCK=$(curl -s -X POST "http://localhost:${EL_RPC_PORT}" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        2>/dev/null | jq -r '.result // empty' 2>/dev/null || echo "")

    if [[ -n "$BLOCK" && "$BLOCK" != "null" ]]; then
        BLOCK_DEC=$(printf "%d" "$BLOCK" 2>/dev/null || echo "?")
        log "Node is producing blocks! Latest block: $BLOCK_DEC (${BLOCK})"
        break
    fi

    RETRY=$((RETRY+1))
    info "Attempt $RETRY/$MAX_RETRIES — waiting for node..."
    sleep 10
done

[[ $RETRY -eq $MAX_RETRIES ]] && warn "Node not responding yet — check logs with: docker compose logs -f"

# ============================================================
#  STEP 12 — PRINT SUMMARY
# ============================================================
banner "🎉 Arc Local Testnet Ready!"

echo -e "${BOLD}Network Details:${RESET}"
echo -e "  Chain ID:      ${CYAN}5042002 (testnet) / 5042001 (local)${RESET}"
echo -e "  Gas Token:     ${CYAN}USDC${RESET}"
echo ""
echo -e "${BOLD}Endpoints:${RESET}"
echo -e "  RPC:           ${CYAN}http://localhost:${EL_RPC_PORT}${RESET}"
echo -e "  WebSocket:     ${CYAN}ws://localhost:${EL_WS_PORT}${RESET}"
echo -e "  Explorer:      ${CYAN}http://localhost:${EXPLORER_PORT}${RESET}"
echo -e "  Metrics:       ${CYAN}http://localhost:${METRICS_PORT}${RESET}"
echo ""
echo -e "${BOLD}Useful Commands:${RESET}"
echo -e "  View logs:     ${CYAN}cd $INSTALL_DIR && docker compose logs -f${RESET}"
echo -e "  Stop node:     ${CYAN}cd $INSTALL_DIR && make testnet-down${RESET}"
echo -e "  Clean all:     ${CYAN}cd $INSTALL_DIR && make testnet-clean${RESET}"
echo -e "  Send tx load:  ${CYAN}cd $INSTALL_DIR && make testnet-load RATE=100 TIME=60${RESET}"
echo -e "  Check block:   ${CYAN}curl -s -X POST http://localhost:${EL_RPC_PORT} -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'${RESET}"
echo ""
echo -e "${BOLD}Get Testnet USDC:${RESET}"
echo -e "  Faucet:        ${CYAN}https://faucet.circle.com${RESET}"
echo -e "  Explorer:      ${CYAN}https://testnet.arcscan.app${RESET}"
echo ""
echo -e "${BOLD}Connect MetaMask:${RESET}"
echo -e "  RPC URL:       https://rpc.testnet.arc.network"
echo -e "  Chain ID:      5042002"
echo -e "  Currency:      USDC"
echo -e "  Explorer:      https://testnet.arcscan.app"
echo ""
echo -e "${GREEN}${BOLD}Install complete! ✓${RESET}"
echo -e "Docs: ${CYAN}https://docs.arc.io/build${RESET}"