# NFT Marketplace

A minimal NFT marketplace: a Solidity contract (Foundry) plus a Next.js + wagmi frontend.
Sellers list ERC721s they hold, buyers pay the exact price, the NFT transfers on purchase.

```
nft-marketplace/
├─ contracts/     # Foundry: NFTMarketplace, tests (MockNFT in test/mocks), deploy script
└─ frontend/      # Next.js + wagmi + viem + RainbowKit dapp
```

## 1. Contracts

```bash
cd contracts
forge build
forge test -vvv        # unit + integration + fuzz + invariant
forge coverage --no-match-coverage "script|test"   # coverage of src/
forge snapshot --check                              # gas regression check
```

Key functions on `NFTMarketplace`:
- `listNFT(nft, tokenId, price)` — list (requires you own it, price > 0, and the
  marketplace is approved for the token). Listing an already listed token updates
  its entry in place, so it never creates duplicates.
- `buyNFT(nft, tokenId)` payable — buy by sending exactly `price`.
- `cancelList(nft, tokenId)` — remove your listing.
- `getActiveListings()` — every active listing (used by the frontend grid).
- `getActiveListingsPage(offset, limit)` — paginated version for large lists.

### Security

| Measure | Location |
|---|---|
| Reentrancy guard on every state-changing function | `NFTMarketplace` (`nonReentrant`) |
| Effects before interactions: listing deleted before the NFT transfer and the payment | `buyNFT` |
| Exact-price payment with typed error `WrongPrice(expected, provided)` | `buyNFT` |
| Failed payment reverts the whole purchase (`PaymentFailed`) | `buyNFT` |
| Custom errors only, full NatSpec | `NFTMarketplace.sol` |
| Static analysis | Slither in CI (`contracts/slither.config.json`) |

See [SECURITY.md](SECURITY.md) for assumptions and known limits (escrow-less listings can become stale).

### Testing

Unit, integration, fuzz and invariant suites with mock NFTs and attacker contracts (reentrant buyer and seller, seller that cannot receive ETH). CI runs `forge fmt --check`, `forge build --sizes`, `forge test` (profile `ci`, higher fuzz runs), a 95% line-coverage gate on `src/`, `forge snapshot --check` and Slither.

## 2. Run a local chain + deploy

```bash
# terminal 1 — local node
anvil

# terminal 2 — deploy marketplace + a demo NFT with 3 minted tokens
cd contracts
forge script script/DeployLocal.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

The script prints the `NFTMarketplace` and `MockNFT` addresses and the owner of
tokens 0,1,2 (Anvil account #0). On a **fresh** anvil these match the defaults in
`frontend/src/config/contracts.ts`, so usually no config edit is needed. If they
differ, copy `frontend/.env.local.example` → `frontend/.env.local` and set them.

## 3. Frontend

```bash
cd frontend
npm install
npm run dev            # http://localhost:3000
npm run test           # Vitest unit tests
```

In MetaMask: add network `RPC http://127.0.0.1:8545`, `Chain ID 31337`, then import
an Anvil private key (account #0 owns the minted tokens; account #1 can be the buyer).

### Flow to try
1. Connect wallet (account #0).
2. List a token you own (Token ID 0, any price) — this signs **two** txs: approve, then list.
3. See it appear in the grid.
4. Switch MetaMask to account #1 → **Buy** → the NFT transfers and ETH moves.
5. Back on account #0 → **Cancel** a remaining listing.

## Notes
- `MockNFT` lives in `contracts/test/mocks/` and has an open `mint` — it's for local testing only, never deploy it for real.
- Real marketplaces (OpenSea) use off-chain indexers instead of an on-chain
  `getActiveListings` array; on-chain enumeration is fine for this learning project.
