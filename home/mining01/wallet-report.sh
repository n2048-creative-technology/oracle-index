#!/usr/bin/env bash
set -euo pipefail

CONTROLLER="mining01"

declare -A HOSTS=(
  [mining01]="192.168.1.101"
  [mining02]="192.168.1.102"
  [mining03]="192.168.1.103"
  [mining04]="192.168.1.104"
)

NODES=(mining01 mining02 mining03 mining04)

log() {
  echo "monitor | $*"
}

run_on_node() {
  local node="$1"
  shift
  local cmd="$*"

  if [ "$node" = "$CONTROLLER" ]; then
    bash -lc "$cmd"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=5 "${node}@${HOSTS[$node]}" "$cmd"
  fi
}

cli_no_wallet() {
  local node="$1"
  shift
  run_on_node "$node" "bitcoin-cli -regtest $*"
}

cli_wallet() {
  local node="$1"
  local wallet="$2"
  shift 2
  run_on_node "$node" "bitcoin-cli -regtest -rpcwallet=\"${wallet}\" $*"
}

wait_for_node() {
  local node="$1"
  log "[*] Waiting for ${node} regtest RPC..."
  until cli_no_wallet "$node" getblockchaininfo >/dev/null 2>&1; do
    sleep 1
  done
  log "    ${node} is up."
}

get_loaded_wallets() {
  local node="$1"
  cli_no_wallet "$node" listwallets \
    | tr -d '[]",' \
    | sed 's/^ *//; s/ *$//' \
    | sed '/^$/d'
}

get_walletdir_wallets() {
  local node="$1"
  cli_no_wallet "$node" listwalletdir \
    | grep '"name"' \
    | sed -E 's/.*"name":[[:space:]]*"([^"]+)".*/\1/'
}

wallet_is_loaded() {
  local node="$1"
  local wallet="$2"
  get_loaded_wallets "$node" | grep -Fxq "$wallet"
}

load_wallet_if_needed() {
  local node="$1"
  local wallet="$2"

  if wallet_is_loaded "$node" "$wallet"; then
    return 1
  fi

  cli_no_wallet "$node" loadwallet "\"${wallet}\"" >/dev/null 2>&1
  return 0
}

unload_wallet_if_needed() {
  local node="$1"
  local wallet="$2"
  cli_no_wallet "$node" unloadwallet "\"${wallet}\"" >/dev/null 2>&1 || true
}

get_wallet_balance() {
  local node="$1"
  local wallet="$2"
  cli_wallet "$node" "$wallet" getbalance 2>/dev/null | tr -d '\r'
}

get_wallet_balances_detailed() {
  local node="$1"
  local wallet="$2"
  cli_wallet "$node" "$wallet" getbalances 2>/dev/null | tr -d '\r'
}

print_node_wallet_report() {
  local node="$1"
  local wallets
  local found_any=0

  echo
  echo "=== ${node} ==="

  wallets=$(get_walletdir_wallets "$node" || true)

  if [ -z "$wallets" ]; then
    echo "No wallets found on disk."
    return 0
  fi

  while IFS= read -r wallet; do
    local loaded_before="no"
    local loaded_now="no"
    local balance="ERR"
    local temp_loaded=0

    [ -z "$wallet" ] && continue
    found_any=1

    if wallet_is_loaded "$node" "$wallet"; then
      loaded_before="yes"
      loaded_now="yes"
    else
      if load_wallet_if_needed "$node" "$wallet"; then
        temp_loaded=1
        loaded_now="yes (temporary)"
      else
        loaded_now="no"
      fi
    fi

    balance=$(get_wallet_balance "$node" "$wallet" || echo "ERR")

    printf "wallet=%s | loaded_before=%s | loaded_now=%s | balance=%s BTC\n" \
      "$wallet" "$loaded_before" "$loaded_now" "$balance"

    if [ "$temp_loaded" -eq 1 ]; then
      unload_wallet_if_needed "$node" "$wallet"
    fi
  done <<< "$wallets"

  if [ "$found_any" -eq 0 ]; then
    echo "No wallets found."
  fi
}

print_full_report() {
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  echo
  echo "############################################################"
  echo "# Wallet balance report - ${timestamp}"
  echo "############################################################"

  for node in "${NODES[@]}"; do
    print_node_wallet_report "$node"
  done

  echo
}

main_once() {
  for node in "${NODES[@]}"; do
    wait_for_node "$node"
  done

  print_full_report
}

main_watch() {
  local interval="${1:-5}"

  for node in "${NODES[@]}"; do
    wait_for_node "$node"
  done

  while true; do
    clear
    print_full_report
    sleep "$interval"
  done
}

# Run once by default.
# For continuous monitoring every 5 seconds:
#   ./monitor_wallets.sh watch
# Or:
#   ./monitor_wallets.sh watch 2

case "${1:-once}" in
  once)
    main_once
    ;;
  watch)
    main_watch "${2:-5}"
    ;;
  *)
    echo "Usage: $0 [once|watch [seconds]]"
    exit 1
    ;;
esac
