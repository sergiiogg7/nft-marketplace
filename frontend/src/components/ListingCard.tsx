"use client";

import type { Listing } from "@/hooks/useListings";
import { formatPrice, shortenAddress } from "@/lib/format";

type Props = {
  listing: Listing;
  isOwner: boolean;
  busy?: boolean;
  onBuy: () => void;
  onCancel: () => void;
};

/// Pure presentational card. No chain logic — parent wires the callbacks.
export function ListingCard({ listing, isOwner, busy, onBuy, onCancel }: Props) {
  const tokenId = listing.tokenId.toString();

  return (
    <div className="card">
      {/* placeholder art keyed off tokenId — no on-chain metadata needed for the demo */}
      <img src={`https://picsum.photos/seed/nft-${tokenId}/300/300`} alt={`Token ${tokenId}`} />
      <div className="card-body">
        <div className="row" style={{ justifyContent: "space-between" }}>
          <span className="badge">#{tokenId}</span>
          {isOwner && <span className="badge">yours</span>}
        </div>
        <span className="price">{formatPrice(listing.price)} ETH</span>
        <span className="muted">Seller: {shortenAddress(listing.seller)}</span>
        {isOwner ? (
          <button className="danger" onClick={onCancel} disabled={busy}>
            {busy ? "…" : "Cancel"}
          </button>
        ) : (
          <button onClick={onBuy} disabled={busy}>
            {busy ? "…" : "Buy"}
          </button>
        )}
      </div>
    </div>
  );
}
