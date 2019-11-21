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
- `pub`
- `rct`
- `outPub`
- `globalIndex`
- `blockHeight`

### Needed to be returned for all txs

- `inputs` -`tx.prefix.inputs`
