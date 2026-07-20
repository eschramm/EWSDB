# EWSDB

Thin SQLite wrapper built on FMDB, predating the move to `Blackbird` for newer apps.

- `DBModel` — protocol for records that can read/write themselves to a `DBTable` via a `dataDictionary`.
- `DBManager` — connection/query management around FMDB.

Mostly kept around for older apps that haven't been migrated to `Blackbird`/`BBWrapper`.
