#HASH=$(bitcoin-cli -regtest getbestblockhash)
#bitcoin-cli -regtest getblock "$HASH" 2 | jq '.tx[0]'


HASH=$(bitcoin-cli -regtest getbestblockhash)
bitcoin-cli -regtest getblock "$HASH" 2 | jq -r '
  .tx[0].vout[]
  | select(.value > 0)
  | .scriptPubKey.address // .scriptPubKey.addresses[0]
'

