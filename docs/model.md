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
- url: string
- start_height: number
- storage_path: string
- storage_percent: number
- latest: number
- oldest: number
- size: number
- params_by_wallet_account: object

