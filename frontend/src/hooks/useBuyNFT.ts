"use client";

import { useState } from "react";
import { useWriteContract, useConfig } from "wagmi";
import { waitForTransactionReceipt } from "@wagmi/core";
import type { Address } from "viem";
import { nftMarketplaceAbi } from "@/abi/nftMarketplace";
import { MARKETPLACE_ADDRESS } from "@/config/contracts";

/// Buy a listing by sending its exact price as msg.value.
export function useBuyNFT() {
  const config = useConfig();
  const { writeContractAsync } = useWriteContract();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function buy(nftAddress: Address, tokenId: bigint, priceWei: bigint) {
    setError(null);
    setPending(true);
    try {
      const hash = await writeContractAsync({
        address: MARKETPLACE_ADDRESS,
        abi: nftMarketplaceAbi,
        functionName: "buyNFT",
        args: [nftAddress, tokenId],
        value: priceWei,
      });
      await waitForTransactionReceipt(config, { hash });
    } catch (e) {
      setError(e && typeof e === "object" ? ((e as any).shortMessage ?? (e as any).message ?? "Buy failed") : "Buy failed");
      throw e;
    } finally {
      setPending(false);
    }
  }

  return { buy, pending, error };
}
