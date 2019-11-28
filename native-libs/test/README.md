### New files to be copied from upstream

- `epee/include/storages`
- `epee/include/file_io_utils.h`

### Data needed for processing

- `txId`
- `pub` - `rawTx.prefix.extra.transaction_public_key`
- `version`
- `rv`
- `outputs`

### Needed to be returned for discovered UTXOs

- `txId`
- `vout`
- `amount`
- `keyImage`
- `txPub`
- `pub`
- `rct`
- `globalIndex`
- `blockHeight`

### Needed to be returned for all txs

#### Input format

```json
[
  {
    "i": "txId",
    "t": "timestamp",
    "m": "img",
    "n": "nonce",
    "f": "fee"
  }
]
```

### Pruned block format

```json
[
  {
    "i": "id",
    "t": "timestamp",
    "m": [
      {
        "i": "global_index",
        "p": "public_key",
        "r": "rct"
      }
    ]
  }
]
```
