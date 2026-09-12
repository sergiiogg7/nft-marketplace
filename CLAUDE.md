# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Contracts (run from `contracts/`)

```bash
forge build
forge test -vvv                                           # all tests
forge test --match-test test_Revert_WhenPriceZero -vvv   # single test
forge fmt                                                 # format (CI enforces this)
forge script script/DeployLocal.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

### Frontend (run from `frontend/`)

```bash
npm run dev      # http://localhost:3000
npm run test     # Vitest unit tests (run from frontend/)
npm run build
npm run lint
```

### Local chain

```bash
anvil            # terminal 1 — Hardhat/Anvil node on :8545, Chain ID 31337
```

## Architecture

Monorepo with two independent packages — `contracts/` and `frontend/` — no shared build tooling between them.

### Contracts (`contracts/`)

Single contract: `NFTMarketplace.sol`. No upgradability, no fees, no escrow. Core invariant: ETH and NFT transfer atomically in `buyNFT` — delete listing, then `safeTransferFrom`, then `seller.call{value}`.

Active listing enumeration uses a swap-and-pop array (`activeListings`) with a `_indexOf` mapping (stores `index + 1`, zero = not present). This lets `getActiveListings()` return all listings in one call — intentional for this learning project, not production-grade.

`MockNFT` has an open `mint` — only for local dev, never deploy to mainnet.

Deploy script (`DeployLocal.s.sol`) mints tokens 0,1,2 to Anvil account #0. On a fresh anvil the deployed addresses match the hardcoded defaults in `frontend/src/config/contracts.ts`, so `.env.local` is usually not needed.

### Frontend (`frontend/`)

Next.js 15 + wagmi v2 + viem + RainbowKit. Targets Anvil only (`wagmi.ts` configures a single chain: `anvil`, transport `http://127.0.0.1:8545`).

**Data flow:**
- `useListings` → `useReadContract(getActiveListings)` — polls on-chain array
- `useListNFT` — two sequential txs: `approve(marketplace, tokenId)` on the NFT contract, then `listNFT(...)` on marketplace; exposes a `step` state machine (`idle | approving | listing | done | error`)
- `useBuyNFT`, `useCancelListing` — single-tx wrappers

ABIs live in `src/abi/` as TypeScript const objects (not imported from build artifacts). When the contract changes, update both the Solidity and the ABI file manually.

Contract addresses are read from `NEXT_PUBLIC_MARKETPLACE_ADDRESS` / `NEXT_PUBLIC_MOCK_NFT_ADDRESS` env vars, falling back to the fresh-anvil defaults in `src/config/contracts.ts`.

### CI (`.github/workflows/test.yml`)

Runs only the Foundry suite: `forge fmt --check`, `forge build --sizes`, `forge test -vvv`. No frontend CI.
