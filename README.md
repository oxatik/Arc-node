# Arc Node One-Click Installer

An automation script designed for Operations Engineers to quickly provision, deploy, and monitor an Arc Layer-1 stablechain node on Ubuntu environments.

## Quick Start

## 1. Run the Installer
Give the script executable permissions and run it with root privileges:
```
chmod +x arc-node-install.sh

```
```
sudo bash arc-node-install.sh

```


## Customize the Version (Optional)

If you need to deploy a specific version of the Arc network software, pass the ARC_VERSION flag before execution:

```
ARC_VERSION=0.6.0 sudo bash arc-node-install.sh

```

## Post-Installation Access

Once the installation loop successfully completes, your local infrastructure endpoints will be fully accessible at the following destinations:

RPC Endpoint: http://localhost:8545

Block Explorer: http://localhost:4000
