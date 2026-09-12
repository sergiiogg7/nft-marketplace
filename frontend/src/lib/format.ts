import { formatEther, parseEther } from "viem";

/// Shorten an address for display: 0x1234…abcd
export function shortenAddress(address: string, chars = 4): string {
  if (!address || address.length < 2 + chars * 2) return address;
  return `${address.slice(0, 2 + chars)}…${address.slice(-chars)}`;
}

/// wei (bigint) -> human ETH string.
export function formatPrice(wei: bigint): string {
  return formatEther(wei);
}

/// Parse a user-entered ETH amount to wei. Returns null if invalid or not > 0.
export function parsePriceToWei(input: string): bigint | null {
  const trimmed = input.trim();
  if (!trimmed) return null;
  // digits with an optional single decimal point (e.g. "1", "0.5", ".5")
  if (!/^\d*\.?\d+$/.test(trimmed)) return null;
  try {
    const wei = parseEther(trimmed);
    return wei > 0n ? wei : null;
  } catch {
    return null;
  }
}

/// True when the input is a valid, positive ETH amount.
export function isValidPrice(input: string): boolean {
  return parsePriceToWei(input) !== null;
}
