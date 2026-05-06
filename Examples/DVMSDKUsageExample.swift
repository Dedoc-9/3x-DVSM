
let sdk = DVMSDK(system: dvsm)

await sdk.submit(
    id: "tx-1",
    vector: [0.1, 0.9],
    shard: "A"
)
