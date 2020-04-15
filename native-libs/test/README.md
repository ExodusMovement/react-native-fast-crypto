### Input format

```json
{
  "storage_path": "/tmp",
  "storage_percent": 10,
  "latest": 2077262,
  "oldest": 2075072,
  "size": 330,
  "params_by_wallet_account": {
    "exodus_0": {
      "send_txs": [
        "a3aa1e4e3565d9e0122013576f8197fe3e0d0552cc5e7ab0afd0abe5260fef36"
      ],
      "sec_viewKey_string": "0000000000000000000000000000000000000000000000000000000000000000",
      "pub_spendKey_string": "0000000000000000000000000000000000000000000000000000000000000000"
    },
    "exodus_1": {
      "key_images": [
        "599a3d0f3064ad088449bfbb71d2ef72ef4b84d786f9cb796cc65e8d26f65deb"
      ],
      "sec_viewKey_string": "0000000000000000000000000000000000000000000000000000000000000000",
      "pub_spendKey_string": "0000000000000000000000000000000000000000000000000000000000000000",
      "sec_spendKey_string": "0000000000000000000000000000000000000000000000000000000000000000"
    }
  }
}
```

### Output format

```json
{
  "current_height": "1971749",
  "end_height": "1971748",
  "latest": "2077262",
  "oldest": "1971010",
  "size": "331",
  "txs_by_wallet_accounts": {
    "exodus_0": [
      {
        "id": "a3aa1e4e3565d9e0122013576f8197fe3e0d0552cc5e7ab0afd0abe5260fef36",
        "timestamp": "1574262755",
        "height": "1971100",
        "pub": "815315f6b25c26fd309b8de73197269263f249003d751e539e94e2058823a025",
        "fee": "37370000",
        "epid": "7229840319f07c53",
        "inputs": [
          "4826deeff1b32151c2bfc612162bc1b800a3f82f09e1131a5ede7b2b88f69d83",
          "0ed2a535c0bcda7636224644c974ca7a369548723676ec7946950e3a40390f1b"
        ],
        "utxos": ""
      }
    ],
    "exodus_1": [
      {
        "id": "599a3d0f3064ad088449bfbb71d2ef72ef4b84d786f9cb796cc65e8d26f65deb",
        "timestamp": "1574275165",
        "height": "1971222",
        "pub": "94223f05cc7747d02658fff46b30191db67077c03693b7df78d6185c1ddf43f7",
        "fee": "37450000",
        "epid": "99dd0b7fe1df4f5d",
        "inputs": [
          "6e18d72efc34451d207fb679d18959f8f216b70e34eae84c460c5856b890fffc",
          "28df8dc7e44dbc08d27681dbbce6ae999bf9a5e61b44154a4b42e83584c92b4f"
        ],
        "utxos": ""
      }
    ]
  }
}
```
