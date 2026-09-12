"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import type { Listing } from "@/hooks/useListings";
import { useBuyNFT } from "@/hooks/useBuyNFT";
import { useCancelListing } from "@/hooks/useCancelListing";
import { ListingCard } from "./ListingCard";

type Props = {
  listings: readonly Listing[];
  isLoading: boolean;
  onChanged: () => void;
};

const keyOf = (l: Listing) => `${l.nftAddress}-${l.tokenId}`;

export function ListingsGrid({ listings, isLoading, onChanged }: Props) {
  const { address } = useAccount();
  const { buy } = useBuyNFT();
  const { cancel } = useCancelListing();
  const [busyKey, setBusyKey] = useState<string | null>(null);

  async function handleBuy(l: Listing) {
    setBusyKey(keyOf(l));
    try {
      await buy(l.nftAddress, l.tokenId, l.price);
      onChanged();
    } catch {
      // error surfaced by the hook; keep the card in place
    } finally {
      setBusyKey(null);
    }
  }

  async function handleCancel(l: Listing) {
    setBusyKey(keyOf(l));
    try {
      await cancel(l.nftAddress, l.tokenId);
      onChanged();
    } catch {
      // ignore; user can retry
    } finally {
      setBusyKey(null);
    }
  }

  if (isLoading) return <p className="muted">Loading listings…</p>;
  if (listings.length === 0) return <p className="muted">No active listings. List one above.</p>;

  return (
    <div className="grid">
      {listings.map((l) => (
        <ListingCard
          key={keyOf(l)}
          listing={l}
          isOwner={!!address && address.toLowerCase() === l.seller.toLowerCase()}
          busy={busyKey === keyOf(l)}
          onBuy={() => handleBuy(l)}
          onCancel={() => handleCancel(l)}
        />
      ))}
    </div>
  );
}
