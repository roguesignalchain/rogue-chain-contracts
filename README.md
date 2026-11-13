# Rogue Signal Smart Contracts (`rogue-chain-contracts`)

Official Foundry repository for protocol-level and ecosystem smart contracts on **Rogue Signal (Chain ID `800055`)**.

## Contracts

### `RogueMinerReputation` (`0x0000000000000000000000000000000000000020`)
* **Deployed at Block 0** via `Genesis.Alloc` in `rogue-core-chain`.
* **Single source of truth** for on-chain PoW miner reputation, cyberpunk rank levels (`0..6`), localized titles (`en`, `es`, `zh`, expandable via `onlyOwner`), badge image URIs, XP progress (`progressBps`), and anti-Sybil gating (`meetsLevel`).
* **Storage Layout**:
  * `Slot 0`: `Ownable._owner` (initialized in `Genesis.Alloc.Storage` to `RogueTreasuryAddress` `0xe9aaE535B7971A9AC8C6af0e4B524D02260D3a03`).
  * `Slot 1`: `_blocksMined` (`mapping(address => uint256)` written directly by consensus in `AccumulateRewards` using `keccak256(abi.encode(miner, 1))`).
  * `Slot 2`: `_rankImageOverrides`.
  * `Slot 3`: `_rankTitleOverrides`.

## Development

```bash
# Build & verify storage layout
forge build
forge inspect RogueMinerReputation storage-layout

# Run full test suite
forge test -vvv
```

## Exporting Genesis Bytecode to `rogue-core-chain`

When `rogue-chain-contracts` and `rogue-core-chain` are checked out as sibling directories:

```bash
./scripts/export-genesis-bytecode.sh
```

If `rogue-core-chain` is located elsewhere (or when running repositories independently), pass `ROGUE_CORE_CHAIN_DIR`:

```bash
ROGUE_CORE_CHAIN_DIR=/path/to/rogue-core-chain ./scripts/export-genesis-bytecode.sh
```

The script always writes `out/rogue_reputation_bytecode.go` locally and copies it to `<ROGUE_CORE_CHAIN_DIR>/params/rogue_reputation_bytecode.go` when available.

## Administration Scripts

Copy `.env.example` to `.env`, set `PRIVATE_KEY` (never commit `.env`), and broadcast `--legacy` transactions (Rogue Signal accepts Type 0 legacy transactions):

```bash
source .env
forge script script/AdminReputation.s.sol:SetRankTitle \
  --sig "run(uint32,string,string)" 1 "es" "Corredor de Reconocimiento" \
  --rpc-url "$ROGUE_RPC_URL" --broadcast --legacy
```
