#!/usr/bin/env bash
set -euo pipefail

WALLET_NAME="demo"
CONTROLLER="mining01"
MIN_AMOUNT="0.1"
MAX_AMOUNT="0.9"
SLEEP_SECS=1

declare -A HOSTS=(
  [mining01]="192.168.1.101"
  [mining02]="192.168.1.102"
  [mining03]="192.168.1.103"
  [mining04]="192.168.1.104"
)

NODES=(mining01 mining02 mining03 mining04)

log() {
  echo "xfer | $*"
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

cli() {
  local node="$1"
  shift
  run_on_node "$node" "bitcoin-cli -regtest -rpcwallet=${WALLET_NAME} $*"
}

wait_for_node() {
  local node="$1"
  log "[*] Waiting for ${node} regtest RPC..."
  until cli_no_wallet "$node" getblockchaininfo >/dev/null 2>&1; do
    sleep 1
  done
  log "    ${node} is up."
}

ensure_wallet_on_node() {
  local node="$1"

  if cli_no_wallet "$node" listwallets | grep -q "\"${WALLET_NAME}\""; then
    return 0
  fi

  if cli_no_wallet "$node" loadwallet "$WALLET_NAME" >/dev/null 2>&1; then
    return 0
  fi

  if cli_no_wallet "$node" listwalletdir | grep -q "\"name\": \"${WALLET_NAME}\""; then
    cli_no_wallet "$node" loadwallet "$WALLET_NAME" >/dev/null
    return 0
  fi

  cli_no_wallet "$node" createwallet "$WALLET_NAME" >/dev/null
}

ensure_wallet_everywhere() {
  log "[*] Ensuring wallet '${WALLET_NAME}' exists and is loaded on all nodes..."
  for node in "${NODES[@]}"; do
    ensure_wallet_on_node "$node"
  done
}

set_fee_everywhere() {
  log "[*] Setting wallet fee on all nodes..."
  for node in "${NODES[@]}"; do
    cli "$node" settxfee 0.0002 >/dev/null 2>&1 || true
  done
}

connect_nodes() {
  log "[*] Connecting ${CONTROLLER} to the other nodes..."
  for node in "${NODES[@]}"; do
    if [ "$node" != "$CONTROLLER" ]; then
      cli_no_wallet "$CONTROLLER" addnode "${HOSTS[$node]}:18444" onetry || true
    fi
  done
}

wait_for_peers() {
  log "[*] Waiting for ${CONTROLLER} to have peers..."
  while true; do
    local count
    count=$(cli_no_wallet "$CONTROLLER" getconnectioncount 2>/dev/null || echo 0)
    if [ "${count}" -ge 1 ]; then
      log "    ${CONTROLLER} has ${count} peer(s)."
      break
    fi
    sleep 1
  done
}

get_balance() {
  local node="$1"
  cli "$node" getbalance | tr -d '\r'
}

random_node() {
  local idx=$((RANDOM % ${#NODES[@]}))
  echo "${NODES[$idx]}"
}

random_amount() {
  awk -v min="$MIN_AMOUNT" -v max="$MAX_AMOUNT" 'BEGIN{
    srand();
    printf "%.8f\n", min + rand() * (max - min)
  }'
}

can_send() {
  local node="$1"
  local amount="$2"

  awk -v bal="$(get_balance "$node" 2>/dev/null || echo 0)" -v amt="$amount" 'BEGIN{
    if (bal > amt + 0.001) exit 0;
    exit 1
  }'
}

print_balances() {
  log "[*] Balances:"
  for node in "${NODES[@]}"; do
    local bal
    bal=$(get_balance "$node" 2>/dev/null || echo "ERR")
    echo "  ${node}: ${bal}"
  done
}

mine_one_block() {
  local miner="$1"
  local maddr
  maddr=$(cli "$miner" getnewaddress | tr -d '\r')
  log "    mining 1 block on ${miner}"
  cli_no_wallet "$miner" generatetoaddress 1 "$maddr" >/dev/null
}

main_loop() {
  log "[*] Starting transfer-only traffic loop..."
  print_balances

  while true; do
    local from_node to_node addr amount output miner

    from_node=$(random_node)
    to_node=$(random_node)

    if [ "$from_node" = "$to_node" ]; then
      sleep "$SLEEP_SECS"
      continue
    fi

    amount=$(random_amount)

    if ! can_send "$from_node" "$amount"; then
      log "    skip: ${from_node} balance too low for ${amount}"
      sleep "$SLEEP_SECS"
      continue
    fi

    addr=$(cli "$to_node" getnewaddress | tr -d '\r')
    log "    tx: ${from_node} -> ${to_node} amount=${amount} to ${addr}"

    if output=$(cli "$from_node" sendtoaddress "$addr" "$amount" 2>&1); then
      log "    txid: ${output}"

      miner=$(random_node)
      mine_one_block "$miner"

      print_balances
    else
      log "    send failed from ${from_node}: ${output}"
    fi

    sleep "$SLEEP_SECS"
  done
}

for node in "${NODES[@]}"; do
  wait_for_node "$node"
done

ensure_wallet_everywhere
set_fee_everywhere
connect_nodes
wait_for_peers
main_loop
