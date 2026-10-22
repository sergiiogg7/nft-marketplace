# Security

## Status

This repository has not been externally audited. Do not use it with real funds without an independent review.

## Assumptions and known limits

- Listings are not escrowed. If a seller transfers the NFT or revokes the approval, the listing stays in the enumeration but cannot be bought (the transfer reverts). Only the seller can cancel it. A new owner can list the token again, which replaces the stale entry.
- A seller that is a contract and rejects ETH blocks the purchase of its own listing (`PaymentFailed`). Other listings are not affected.
- There are no fees, no owner and no upgradability, so there is no privileged role to compromise.
- `getActiveListings` is unbounded. Use `getActiveListingsPage` when the list can grow large.
- The ERC721 collection is chosen by the seller. A malicious collection can misbehave in `ownerOf`, `getApproved` or `safeTransferFrom`, but only affects listings of that collection and cannot reenter the marketplace (`nonReentrant`).

## Invariants

- Each listed token appears exactly once in `activeListings` and mirrors the `listing` mapping.
- The marketplace never retains ETH.

## Reporting a vulnerability

Open a private security advisory on the GitHub repository. Do not open a public issue.
