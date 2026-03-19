#!/usr/bin/env bash
set -euo pipefail

WALLET="demo"

until bitcoin-cli -regtest getblockchaininfo >/dev/null 2>&1; do
  sleep 1
done

if bitcoin-cli -regtest listwallets | grep -q "\"${WALLET}\""; then
  exit 0
fi

if bitcoin-cli -regtest loadwallet "${WALLET}" >/dev/null 2>&1; then
  exit 0
fi

if bitcoin-cli -regtest listwalletdir | grep -q "\"name\": \"${WALLET}\""; then
  bitcoin-cli -regtest loadwallet "${WALLET}" >/dev/null
  exit 0
fi

bitcoin-cli -regtest createwallet "${WALLET}" >/dev/null
