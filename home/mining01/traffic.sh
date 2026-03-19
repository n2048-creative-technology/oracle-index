#!/usr/bin/env bash
set -euo pipefail

WALLET_NAME="demo"
CONTROLLER="mining01"

declare -A HOSTS=(
  [mining01]="192.168.1.101"
  [mining02]="192.168.1.102"
  [mining03]="192.168.1.103"
  [mining04]="192.168.1.104"
)

NODES=(mining01 mining02 mining03 mining04)

log() {
  echo "traffic | $*"
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
  log "    - ensuring wallet '${WALLET_NAME}' on ${node}"

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

get_blockcount() {
  local node="$1"
  cli_no_wallet "$node" getblockcount | tr -d '\r'
}

ensure_initial_blocks() {
  log "[*] Ensuring at least 101 blocks exist..."
  local height
  height=$(get_blockcount "$CONTROLLER")
  log "    current height on ${CONTROLLER}: ${height}"

  if [ "$height" -lt 101 ]; then
    local to_mine=$((101 - height))
    local addr
    addr=$(cli "$CONTROLLER" getnewaddress | tr -d '\r')
    log "    mining ${to_mine} blocks on ${CONTROLLER} to ${addr}"
    cli_no_wallet "$CONTROLLER" generatetoaddress "$to_mine" "$addr" >/dev/null
  fi
}

sync_wait() {
  local expected
  expected=$(get_blockcount "$CONTROLLER")

  for node in "${NODES[@]}"; do
    local tries=0
    while true; do
      local h
      h=$(get_blockcount "$node" 2>/dev/null || echo -1)
      if [ "$h" = "$expected" ]; then
        break
      fi
      tries=$((tries + 1))
      if [ "$tries" -gt 20 ]; then
        log "    warning: ${node} did not reach height ${expected}"
        break
      fi
      sleep 1
    done
  done
}

random_node() {
  local idx=$((RANDOM % ${#NODES[@]}))
  echo "${NODES[$idx]}"
}

print_balances() {
  log "[*] Balances:"
  for node in "${NODES[@]}"; do
    local bal
    bal=$(cli "$node" getbalance 2>/dev/null | tr -d '\r' || echo "ERR")
    echo "  ${node}: ${bal}"
  done
}

fund_other_nodes() {
  log "[*] Funding the other nodes from ${CONTROLLER}..."

  for node in "${NODES[@]}"; do
    if [ "$node" != "$CONTROLLER" ]; then
      local addr
      addr=$(cli "$node" getnewaddress | tr -d '\r')
      log "    sending 10 BTC from ${CONTROLLER} to ${node} -> ${addr}"
      cli "$CONTROLLER" sendtoaddress "$addr" "10" >/dev/null
    fi
  done

  local maddr
  maddr=$(cli "$CONTROLLER" getnewaddress | tr -d '\r')
  log "    mining 1 confirmation block on ${CONTROLLER}"
  cli_no_wallet "$CONTROLLER" generatetoaddress 1 "$maddr" >/dev/null

  sync_wait
  print_balances
}

set_fee_everywhere() {
  log "[*] Setting wallet fee on all nodes..."
  for node in "${NODES[@]}"; do
    cli "$node" settxfee 0.0002 >/dev/null 2>&1 || true
  done
}

main_loop() {
  log "[*] Starting traffic loop..."
  while true; do
    local from_node to_node addr amount miner maddr output

    from_node=$(random_node)
    to_node=$(random_node)

    if [ "$from_node" = "$to_node" ]; then
      continue
    fi

    addr=$(cli "$to_node" getnewaddress | tr -d '\r')
    amount="0.$((RANDOM % 9 + 1))"

    log "    tx: ${from_node} -> ${to_node} amount=${amount} to ${addr}"

    if output=$(cli "$from_node" sendtoaddress "$addr" "$amount" 2>&1); then
      if [ $((RANDOM % 3)) -eq 0 ]; then
        miner=$(random_node)
        maddr=$(cli "$miner" getnewaddress | tr -d '\r')
        log "    mining 1 block on ${miner}"
        cli_no_wallet "$miner" generatetoaddress 1 "$maddr" >/dev/null
        sync_wait
      fi
    else
      log "    send failed from ${from_node}: ${output}"
    fi

    sleep 1
  done
}

for node in "${NODES[@]}"; do
  wait_for_node "$node"
done

ensure_wallet_everywhere
set_fee_everywhere
connect_nodes
wait_for_peers
ensure_initial_blocks
sync_wait
fund_other_nodes
main_loop
