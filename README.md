# NFT Marketplace

A minimal NFT marketplace: a Solidity contract (Foundry) plus a Next.js + wagmi frontend.
Sellers list ERC721s they hold, buyers pay the exact price, the NFT transfers on purchase.

```
nft-marketplace/
├─ contracts/     # Foundry: NFTMarketplace + MockNFT, tests, deploy script
└─ frontend/      # Next.js + wagmi + viem + RainbowKit dapp
```

## 1. Contracts

```bash
cd contracts
forge build
forge test -vvv        # unit + integration + fuzz + invariant
```

Key functions on `NFTMarketplace`:
- `listNFT(nft, tokenId, price)` — list (requires you own it, price > 0, and the
  marketplace is approved for the token).
- `buyNFT(nft, tokenId)` payable — buy by sending exactly `price`.
- `cancelList(nft, tokenId)` — remove your listing.
- `getActiveListings()` — every active listing (used by the frontend grid).

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
- `MockNFT` has an open `mint` — it's for local testing only, never deploy it for real.
- Real marketplaces (OpenSea) use off-chain indexers instead of an on-chain
  `getActiveListings` array; on-chain enumeration is fine for this learning project.
