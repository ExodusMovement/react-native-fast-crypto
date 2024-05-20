# Models

## download_and_process

### Introduce
We call this method at [Monero asset lib](https://github.com/ExodusMovement/assets/blob/main/monero/monero-lib/src/monero-interface.js#L65-L73)
```
 const resp = await this.send(method ?? 'download_and_process', {
    url,
    start_height: cursor,
    storage_path: storageSettings.path,
    storage_percent: storageSettings.percent,
    latest: storageSettings.latest,
    oldest: Number.isFinite(storageSettings.oldest) ? storageSettings.oldest : 1_099_511_627_776,
    size: storageSettings.size,
    params_by_wallet_account: nativeParams,
})
```

### Model of jsonParams

#### Fields definition
- url: string
- start_height: number
- storage_path: string
- storage_percent: number
- latest: number
- oldest: number
- size: number
- params_by_wallet_account: object


#### Example
```json
{   
    "url": "https://xmr-d.a.exodus.io/get_blocks.bin",
    "start_height": 3120123,
    "storage_path": "/tmp",
    "storage_percent": 10,
    "latest": 2077262,
    "oldest": 2075072,
    "size": 330,
    "params_by_wallet_account": {
        "exodus_0": {
            "subaddresses": 200,
            "key_images": [],
            "sec_viewKey_string": "12de640c5e8e7e318ee701ca4801287f13c657b8290073338b57caa44b21c505",
            "pub_spendKey_string": "df9cee70033050334f5b1b94b180fa2c08c96149354df0c5337c251b78f01d3a",
            "sec_spendKey_string": "f3be56ce634c13d47f8170e4f44f9643d4072a28a73d9dc080a5b0dc2ee4a90b"
        }
    }
}
```

