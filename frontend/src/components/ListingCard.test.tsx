import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { ListingCard } from "@/components/ListingCard";
import type { Listing } from "@/hooks/useListings";

const listing: Listing = {
  seller: "0x1234567890abcdef1234567890abcdef12345678",
  nftAddress: "0xabc0000000000000000000000000000000000001",
  tokenId: 7n,
  price: 1_000_000_000_000_000_000n, // 1 ETH
};

describe("ListingCard", () => {
  it("shows price, shortened seller, and a Buy button for non-owners", () => {
    render(<ListingCard listing={listing} isOwner={false} onBuy={() => {}} onCancel={() => {}} />);

    expect(screen.getByText("1 ETH")).toBeInTheDocument();
    expect(screen.getByText(/0x1234…5678/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /buy/i })).toBeInTheDocument();
  });

  it("shows a Cancel button for the owner", () => {
    render(<ListingCard listing={listing} isOwner={true} onBuy={() => {}} onCancel={() => {}} />);

    expect(screen.getByRole("button", { name: /cancel/i })).toBeInTheDocument();
  });

  it("fires onBuy when the Buy button is clicked", () => {
    const onBuy = vi.fn();
    render(<ListingCard listing={listing} isOwner={false} onBuy={onBuy} onCancel={() => {}} />);

    screen.getByRole("button", { name: /buy/i }).click();
    expect(onBuy).toHaveBeenCalledOnce();
  });
});
