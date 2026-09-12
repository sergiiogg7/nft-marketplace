import type { Address } from "viem";
import { nftMarketplaceAbi } from "@/abi/nftMarketplace";
import { mockNftAbi } from "@/abi/mockNft";

// Deterministic addresses for a FRESH anvil (deployer = account #0, nonces 0 and 1).
// If your deploy logs different addresses, set them in frontend/.env.local:
//   NEXT_PUBLIC_MARKETPLACE_ADDRESS=0x...
//   NEXT_PUBLIC_MOCK_NFT_ADDRESS=0x...
export const MARKETPLACE_ADDRESS = (process.env.NEXT_PUBLIC_MARKETPLACE_ADDRESS ??
  "0x5FbDB2315678afecb367f032d93F642f64180aa3") as Address;

export const MOCK_NFT_ADDRESS = (process.env.NEXT_PUBLIC_MOCK_NFT_ADDRESS ??
  "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512") as Address;

// Reusable contract descriptor for wagmi read/write hooks.
export const marketplaceContract = {
  address: MARKETPLACE_ADDRESS,
  abi: nftMarketplaceAbi,
} as const;

export { nftMarketplaceAbi, mockNftAbi };
