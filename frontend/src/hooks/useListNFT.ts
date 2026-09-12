"use client";

import { useState } from "react";
import { useWriteContract, useConfig } from "wagmi";
import { waitForTransactionReceipt } from "@wagmi/core";
import type { Address } from "viem";
import { mockNftAbi } from "@/abi/mockNft";
import { nftMarketplaceAbi } from "@/abi/nftMarketplace";
import { MARKETPLACE_ADDRESS } from "@/config/contracts";

export type ListStep = "idle" | "approving" | "listing" | "done" | "error";

/// Two-step list: approve the marketplace for the token, then create the listing.
/// The approval is required because buyNFT pulls the NFT from the seller.
export function useListNFT() {
  const config = useConfig();
  const { writeContractAsync } = useWriteContract();
  const [step, setStep] = useState<ListStep>("idle");
  const [error, setError] = useState<string | null>(null);

  async function list(nftAddress: Address, tokenId: bigint, priceWei: bigint) {
    setError(null);
    try {
      // Step 1 — approve
      setStep("approving");
      const approveHash = await writeContractAsync({
        address: nftAddress,
        abi: mockNftAbi,
        functionName: "approve",
        args: [MARKETPLACE_ADDRESS, tokenId],
      });
      await waitForTransactionReceipt(config, { hash: approveHash });

      // Step 2 — list
      setStep("listing");
      const listHash = await writeContractAsync({
        address: MARKETPLACE_ADDRESS,
        abi: nftMarketplaceAbi,
        functionName: "listNFT",
        args: [nftAddress, tokenId, priceWei],
      });
      await waitForTransactionReceipt(config, { hash: listHash });

      setStep("done");
    } catch (e) {
      setError(extractError(e));
      setStep("error");
    }
  }

  function reset() {
    setStep("idle");
    setError(null);
  }

  return { list, step, error, reset };
}

function extractError(e: unknown): string {
  if (e && typeof e === "object") {
    const anyErr = e as { shortMessage?: string; message?: string };
    return anyErr.shortMessage ?? anyErr.message ?? "Transaction failed";
  }
  return "Transaction failed";
}
