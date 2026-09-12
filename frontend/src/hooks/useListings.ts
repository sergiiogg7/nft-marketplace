"use client";

import { useReadContract } from "wagmi";
import { marketplaceContract } from "@/config/contracts";

export type Listing = {
  seller: `0x${string}`;
  nftAddress: `0x${string}`;
  tokenId: bigint;
  price: bigint;
};

/// Read every active listing from the marketplace.
export function useListings() {
  const { data, isLoading, error, refetch } = useReadContract({
    ...marketplaceContract,
    functionName: "getActiveListings",
  });

  return {
    listings: (data ?? []) as readonly Listing[],
    isLoading,
    error,
    refetch,
  };
}
