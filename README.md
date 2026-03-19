instalation process: 

# UPDATE THE SYSTEM
```
sudo apt update
sudo apt upgrade
```

# INSTALL BASIC DEPENDENCIES
```
sudo apt install -y curl wget gnupg ufw
```

# INSTALL NVIDIA DEPENDENCIES
```
sudo apt install nvidia-utils-580
sudo apt install nvidia-drivers-580
```

# SYSTEM REBOOT
```
reboot
```

# CHECK NVIDIA GPUS
```
nvindia-smi
```

# DOWNLOAD BITCOIN CORE
```
cd /tmp/
wget https://bitcoincore.org/bin/bitcoin-core-27.0/bitcoin-27.0-x86_64-linux-gnu.tar.gz
```

# UNCOMPRESS AND INSTALL BINARIES
```
tar -xvf bitcoin-27.0-x86_64-linux-gnu.tar.gz 
sudo install -m 0755 bitcoin-27.0/bin/* /usr/local/bin/
```

sudo adduser --disabled-password -gecos "" bitcoin
sudo mkdir -p /var/lib/bitcoin

sudo chown bitcoin:bitcoin /var/lib/bitcoin

# CREATE FOLDER FOR STORING BLOCKCHAIN
sudo mkdir -p /var/lib/bitcoin/.bitcoin
sudo chown -R bitcoin /var/lib/bitcoin/.bitcoin

# BITCOIN DAEMON SETTINGS  (EDIT IP ADDRESSES FROM 4 NODES HERE!!) 
sudo -u bitcoin nano /var/lib/bitcoin/.bitcoin/bitcoin.conf

```
# Core
server=1
daemon=1
txindex=1
dbcache=2048

# Default network section, only used when NOT running -regtest
listen=1
port=8333
maxconnections=40
discover=1

# RPC for default network
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
rpcport=8332
rpcuser=bitcoin
rpcpassword=bitcoin

# Logging
debug=net
logtimestamps=1

# Default-network peers
addnode=192.168.1.101
addnode=192.168.1.102
addnode=192.168.1.103
addnode=192.168.1.104

[regtest]
server=1
daemon=1
txindex=1
dbcache=2048

# RPC
rpcbind=127.0.0.1
rpcbind=192.168.1.101   ## this is the address of this node, change for each node
rpcallowip=127.0.0.1
rpcallowip=192.168.1.0/24
rpcport=18443
rpcuser=bitcoin
rpcpassword=bitcoin

# P2P
listen=1
port=18444
maxconnections=40
discover=0
dnsseed=0
fixedseeds=0

# Wallet / fee convenience
fallbackfee=0.0002

# Logging
debug=net
logtimestamps=1

# Regtest peers   (for each node, add all the other nodes) 
addnode=192.168.1.102:18444
addnode=192.168.1.103:18444
addnode=192.168.1.104:18444
```

## Enable ssh for remote access
sudo systemctl enable ssh
sudo systemctl start ssh


# SET UP FIREWALL RULES
udo ufw allow 8333/tcp
sudo ufw allow 8333/tcp
sudo ufw allow ssh
sudo ufw enable 
sudo ufw status 

# CREATE DAEMON SERVICE DEFINITION (EDIT FILE)

sudo nano /etc/systemd/system/bitcoind.service

```
[Unit]
Description=Bitcoin Core Daemon
After=network.target

[Service]
ExecStart=/usr/local/bin/bitcoind -datadir=/var/lib/bitcoin/.bitcoin
User=bitcoin
Group=bitcoin
Type=forking
Restart=always
TimeoutStopSec=600

[Install]
WantedBy=multi-user.target
```


# CREATE REGTEST SERVICE TO ALLOW TEST TRANSACTIONS AND MINING

sudo nano /etc/systemd/system/bitcoind-regtest.service

```
[Unit]
Description=Bitcoin Core regtest daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=mining01
Group=mining01
ExecStart=/usr/local/bin/bitcoind -regtest -daemon
ExecStop=/usr/local/bin/bitcoin-cli -regtest stop
ExecStopPost=/bin/sleep 2
Restart=on-failure
RestartSec=5
TimeoutStartSec=120
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
```


## CREATE SERVICE TO ENSURE WALLET PRESENCE

sudo nano /etc/systemd/system/bitcoin-wallet.service

```
[Unit]
Description=Load Bitcoin regtest wallet
After=bitcoind-regtest.service
Requires=bitcoind-regtest.service

[Service]
Type=oneshot
User=mining01
Group=mining01
ExecStart=/home/mining01/load-demo-wallet.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

## CREATE SERVICE TO CREATE TRANSACTIONS AND MINING

sudo nano /etc/systemd/system/traffic.service

```
[Unit]
Description=Bitcoin regtest traffic generator
After=bitcoin-wallets.service
Requires=bitcoin-wallets.service

[Service]
Type=simple
User=mining01
Group=mining01
ExecStart=/home/mining01/traffic.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

sudo nano /etc/systemd/system/transfer.service

```
[Unit]
Description=Bitcoin regtest wallet transfer generator
After=bitcoin-wallets.service
Requires=bitcoin-wallets.service

[Service]
Type=simple
User=mining01
Group=mining01
ExecStart=/home/mining01/transfer.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```


# ENABLE AND START SERVICES

sudo systemctl daemon-reload 
sudo systemctl enable bitcoind.service 
sudo systemctl enable bitcoind-regtest.service 
sudo systemctl enable bitcoin-wallets.service 
sudo systemctl enable traffic.service 
sudo systemctl enable transfer.service

sudo systemctl start bitcoind.service 
sudo systemctl start bitcoind-regtest.service 
sudo systemctl start bitcoin-wallets.service 
sudo systemctl start traffic.service 
sudo systemctl start transfer.service


# CREATE KEY PAIRS FOR EACH NODE

RUN	`ssh-keygen` on each node to generate public and private key pairs inside /home/mining0X/.ssh/

# SHARE KEYS FOR EACH NODE

On each node, create /home/{HOST}/.ssh/authorized_keys, containing copies of the .pub key from every other node. 

Example:

/home/mining01/.ssh/authorized_keys:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAnDJRVCfnVO/LQYLmkDL5dFrLLTNshju0hUrbCezdZi mining02@mining02-H110-D3A
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDXzHj/aA70Cvb8M8S7ExT5yEqE80m9WEleEO5/+2Tlw mining03@mining03-H110-D3A
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB6HjZx0pe3LxbehSJtuhk+av1j6DycJwNhU0RzrlvAZ mining04@mining04-H110-D3A
```
