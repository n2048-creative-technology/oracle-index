# oracle-index

*local clockchain interactions, by "latency.club" collective*

An art/installation project that runs a small **private Bitcoin regtest
network** (a local, worthless-by-design test network — not mainnet, no real
money involved) across four Raspberry Pi-class nodes, and uses the
transaction/mining activity on that network to drive a **video loop**: which
video clip and aspect ratio plays next is meant to be chosen based on which
node last "mined" a block.

**Status: NEEDS WORK / ONE-OFF EXPERIMENT.** The Bitcoin regtest
infrastructure (systemd services, wallet scripts, traffic generators) is
complete and coherent. The actual video-selection logic that ties the chain
activity to on-screen video — `video-controller/video_select.js` — is
**pseudocode, not working code**: it has syntax errors (missing parens,
`.len()`/`.push()`/`.pull()` called on plain arrays that don't have those
methods, undefined `random()`), and the "read from mining node" hook is an
explicit `// To implement` stub. Treat this as a design sketch for the
video-reactive half of the piece, not a runnable installation end to end.

## What's actually in this repo

```
etc/systemd/system/       systemd units: bitcoind.service, bitcoind-regtest.service,
                           bitcoin-wallets.service, traffic.service, transfer.service
home/mining01/            per-node helper scripts run by those services:
  load-demo-wallet.sh       ensures a "demo" regtest wallet exists/loads
  traffic.sh                connects the 4 nodes, mines an initial 101 blocks,
                             funds each node, then loops random send+mine traffic
  transfer.sh               a transfer-only variant of the traffic loop (no auto-mining
                             except after enough balance accumulates)
  wallet-report.sh           prints a balance report across all 4 nodes' wallets
var/lib/bitcoin/.bitcoin/  example bitcoin.conf for a 4-node regtest mesh
check_last_rewarded_address.sh   pulls the payout address of the latest mined block
wallet-report.sh           (duplicate of home/mining01/wallet-report.sh, top-level copy)
video-controller/
  video_select.js           PSEUDOCODE for choosing the next video/aspect ratio based
                             on the "last miner" — not functional, several syntax
                             errors, `get_prefferred_format()` and `play()` are stubs
videos/                     8 tiny (76 KB each) placeholder .mp4 files for testing
mpv-offline/                257 .deb packages (~185 MB) — an offline apt mirror for
                            installing mpv + its dependencies on an air-gapped/Pi node
secret.md                  plaintext example credentials for the 4 demo nodes
                            (mining01..04 / password = same as username, LAN-only
                            192.168.1.101-104) — see Security note below
```

## Setting it up

`check_last_rewarded_address.sh` and the install/service steps are written
out in full in the original README content (now folded into this file — see
git history for the step-by-step Bitcoin Core + systemd install walkthrough
that used to live here as `README.md`). In short: install Bitcoin Core on
each of 4 nodes, configure `bitcoin.conf` for regtest with the other 3 as
`addnode` peers, install the systemd units, and start the mining/traffic
services. `mpv-offline/` exists so `mpv` (the intended video player on the
Pi nodes) can be installed without live internet access.

## Security / hygiene note

`secret.md` lists plaintext example SSH/system credentials
(`user == password`) for four LAN-only demo hosts. Regtest Bitcoin has no
real-world value, and the IPs are private (`192.168.1.x`), so the practical
risk is low — but committing any plaintext credential file to a **public**
repo is bad practice regardless of how low-value the target is. Recommend
removing `secret.md` from the working tree and from history (see bloat note
below — a `git filter-repo` pass would be a good time to also strip this)
before treating this repo as a portfolio piece.

## Known issues (flagged for cleanup)

- **Git history bloat**: the `mpv-offline/` directory of `.deb` packages
  accounts for ~185 MB of this repo's ~189 MB total size (`git rev-list
  --objects --all` + `cat-file --batch-check`, summed). That's an offline
  apt mirror committed wholesale rather than referenced/regenerated on
  demand. A `git filter-repo` history cleanup (or moving this to a Release
  asset / documenting `apt-get download` commands instead) would recover
  almost the entire size of this repo — flagging it here rather than
  attempting it, per project scope.
- `video-controller/video_select.js` does not run as-is (see Status above).
- `secret.md` should be removed from history (see Security note above).

## License

MIT — see [LICENSE](LICENSE). Covers the scripts and pseudocode authored in
this repo; does not cover the third-party `.deb` packages in `mpv-offline/`,
which keep their own upstream licenses (Debian/Ubuntu packages, mostly
GPL/LGPL/MIT depending on the package).
