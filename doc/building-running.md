**Validated: 2020/02/19**

# Building and Running the Godx DB Sync Node

The bcc-db-sync node is built and tested to run on Linux. It may run on Mac OS X or Windows but
that is unsupported.

Running the db sync node will require Nix and either multiple terminals or a multi terminal
emulator like GNU Screen or TMux.
Setup [tbco binary cache](https://github.com/The-Blockchain-Company/bcc-node/blob/master/doc/getting-started/building-the-node-using-nix.md#tbco-binary-cache)
to avoid several hours of build time.

The db sync node is designed to work with a locally running Godx Node. The two git repositories need to be checked out so that
they are both at the same level. eg:

```
> tree -L 1
.
├── bcc-db-sync
├── bcc-node
```
To setup and run db sync node for testnet replace **mainnet** with **testnet** in all examples below.
These instuction assume than only blocks and transactions for a single blockchain are inserted in
the db. If you want to to use a single database for more than one chain, you will need to duplicate
`config/pgpass` and provide a unique db name for each chain (ie mainnet uses `bccexplorer`). An example
testnet `PGPASSFILE` is at `config/pgpass-testnet`.

### Set up and run a local node
```
git clone https://github.com/The-Blockchain-Company/bcc-node
cd bcc-node
nix-build -A scripts.mainnet.node -o mainnet-node-local
./mainnet-node-local
```

### Set up and run the db-sync node
```
git clone https://github.com/The-Blockchain-Company/bcc-db-sync
cd bcc-db-sync
nix-build -A bcc-db-sync -o db-sync-node
PGPASSFILE=config/pgpass-mainnet scripts/postgresql-setup.sh --createdb
PGPASSFILE=config/pgpass-mainnet db-sync-node/bin/bcc-db-sync \
    --config config/mainnet-config.yaml \
    --socket-path ../bcc-node/state-node-mainnet/node.socket \
    --state-dir ledger-state/mainnet \
    --schema-dir schema/
```

### Run two chains with a single PostgreSQL instance

By running two `bcc-node`s and using two databases within a singe PostgresSQL instance it is
possible to sync two (or more chains).

The two nodes might be run in separate terminals using:
```
nix-build -A scripts.mainnet.node -o mainnet-node-remote && ./mainnet-node-remote
```
and
```
nix-build -A scripts.testnet.node -o testnet-node-remote && ./testnet-node-remote
```
and then the two `db-sync` process run as:
```
PGPASSFILE=config/pgpass-mainnet scripts/postgresql-setup.sh --createdb
PGPASSFILE=config/pgpass-mainnet ./bcc-db-sync-extended-exe \
    --config config/mainnet-config.yaml \
    --socket-path ../bcc-node/state-node-mainnet/node.socket \
    --state-dir ledger-state/mainnet \
    --schema-dir schema/
```
and
```
PGPASSFILE=config/pgpass-testnet scripts/postgresql-setup.sh --createdb
PGPASSFILE=config/pgpass-testnet ./bcc-db-sync-extended-exe \
    --config config/testnet-config.yaml \
    --socket-path ../bcc-node/state-node-testnet/node.socket \
    --state-dir ledger-state/testnet \
    --schema-dir schema/
```
