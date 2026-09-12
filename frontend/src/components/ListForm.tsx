"use client";

import { useState } from "react";
import type { Address } from "viem";
import { useListNFT } from "@/hooks/useListNFT";
import { MOCK_NFT_ADDRESS } from "@/config/contracts";
import { isValidPrice, parsePriceToWei } from "@/lib/format";

const STEP_LABEL: Record<string, string> = {
  idle: "List NFT",
  approving: "1/2 Approving…",
  listing: "2/2 Listing…",
  done: "Listed ✓ — list another",
  error: "List NFT",
};

export function ListForm({ onListed }: { onListed: () => void }) {
  const { list, step, error, reset } = useListNFT();
  const [nftAddress, setNftAddress] = useState<string>(MOCK_NFT_ADDRESS);
  const [tokenId, setTokenId] = useState("");
  const [price, setPrice] = useState("");

  const priceOk = isValidPrice(price);
  const tokenOk = /^\d+$/.test(tokenId.trim());
  const inFlight = step === "approving" || step === "listing";
  const canSubmit = priceOk && tokenOk && !inFlight;

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    const wei = parsePriceToWei(price);
    if (!wei || !tokenOk) return;
    await list(nftAddress as Address, BigInt(tokenId.trim()), wei);
    onListed();
  }

  return (
    <form className="panel" onSubmit={onSubmit}>
      <h2 style={{ marginTop: 0, fontSize: 16 }}>List an NFT</h2>
      <label>NFT contract address</label>
      <input value={nftAddress} onChange={(e) => setNftAddress(e.target.value)} spellCheck={false} />
      <div className="row">
        <div style={{ flex: 1 }}>
          <label>Token ID</label>
          <input
            value={tokenId}
            onChange={(e) => {
              setTokenId(e.target.value);
              reset();
            }}
            placeholder="0"
          />
        </div>
        <div style={{ flex: 1 }}>
          <label>Price (ETH)</label>
          <input
            value={price}
            onChange={(e) => {
              setPrice(e.target.value);
              reset();
            }}
            placeholder="1.0"
          />
        </div>
      </div>
      <button type="submit" disabled={!canSubmit}>
        {STEP_LABEL[step]}
      </button>
      {price.length > 0 && !priceOk && <div className="error">Enter a price greater than 0.</div>}
      {error && <div className="error">{error}</div>}
    </form>
  );
}
