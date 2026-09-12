// ABI for NFTMarketplace — kept in sync with contracts/src/NFTMarketplace.sol.
// Only the members the UI needs are included. `as const` lets wagmi/viem infer types.
export const nftMarketplaceAbi = [
  {
    type: "function",
    name: "getActiveListings",
    stateMutability: "view",
    inputs: [],
    outputs: [
      {
        type: "tuple[]",
        name: "",
        components: [
          { name: "seller", type: "address" },
          { name: "nftAddress", type: "address" },
          { name: "tokenId", type: "uint256" },
          { name: "price", type: "uint256" },
        ],
      },
    ],
  },
  {
    type: "function",
    name: "totalListings",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256", name: "" }],
  },
  {
    type: "function",
    name: "listNFT",
    stateMutability: "nonpayable",
    inputs: [
      { name: "nftAddress_", type: "address" },
      { name: "tokenId_", type: "uint256" },
      { name: "price_", type: "uint256" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "buyNFT",
    stateMutability: "payable",
    inputs: [
      { name: "nftAddress_", type: "address" },
      { name: "tokenId_", type: "uint256" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "cancelList",
    stateMutability: "nonpayable",
    inputs: [
      { name: "nftAddress_", type: "address" },
      { name: "tokenId_", type: "uint256" },
    ],
    outputs: [],
  },
  {
    type: "event",
    name: "NFTListed",
    inputs: [
      { name: "seller", type: "address", indexed: true },
      { name: "nftAddress", type: "address", indexed: true },
      { name: "tokenId", type: "uint256", indexed: true },
      { name: "price", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "NFTSold",
    inputs: [
      { name: "buyer", type: "address", indexed: true },
      { name: "seller", type: "address", indexed: true },
      { name: "nftAddress", type: "address", indexed: true },
      { name: "tokenId", type: "uint256", indexed: false },
      { name: "price", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "NFTCancelled",
    inputs: [
      { name: "seller", type: "address", indexed: true },
      { name: "nftAddress", type: "address", indexed: true },
      { name: "tokenId", type: "uint256", indexed: true },
    ],
  },
  { type: "error", name: "ZeroPrice", inputs: [] },
  { type: "error", name: "NotOwner", inputs: [] },
  { type: "error", name: "NotApproved", inputs: [] },
  { type: "error", name: "ListingNotFound", inputs: [] },
  { type: "error", name: "WrongPrice", inputs: [] },
  { type: "error", name: "NotSeller", inputs: [] },
  { type: "error", name: "PaymentFailed", inputs: [] },
] as const;
