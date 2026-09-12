"use client";

import { useState } from "react";
import { useWriteContract, useConfig } from "wagmi";
import { waitForTransactionReceipt } from "@wagmi/core";
import type { Address } from "viem";
import { nftMarketplaceAbi } from "@/abi/nftMarketplace";
import { MARKETPLACE_ADDRESS } from "@/config/contracts";

/// Cancel a listing you own.
export function useCancelListing() {
  const config = useConfig();
  const { writeContractAsync } = useWriteContract();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function cancel(nftAddress: Address, tokenId: bigint) {
    setError(null);
    setPending(true);
    try {
      const hash = await writeContractAsync({
        address: MARKETPLACE_ADDRESS,
        abi: nftMarketplaceAbi,
        functionName: "cancelList",
        args: [nftAddress, tokenId],
      });
      await waitForTransactionReceipt(config, { hash });
    } catch (e) {
      setError(e && typeof e === "object" ? ((e as any).shortMessage ?? (e as any).message ?? "Cancel failed") : "Cancel failed");
      throw e;
    } finally {
      setPending(false);
    }
  }

  return { cancel, pending, error };
}
