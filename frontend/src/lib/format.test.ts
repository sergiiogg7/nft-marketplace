import { describe, it, expect } from "vitest";
import { shortenAddress, formatPrice, parsePriceToWei, isValidPrice } from "@/lib/format";

describe("shortenAddress", () => {
  it("shortens a full address", () => {
    expect(shortenAddress("0x1234567890abcdef1234567890abcdef12345678")).toBe("0x1234…5678");
  });

  it("leaves short strings unchanged", () => {
    expect(shortenAddress("0x12")).toBe("0x12");
  });
});

describe("formatPrice", () => {
  it("formats wei to an ETH string", () => {
    expect(formatPrice(1_000_000_000_000_000_000n)).toBe("1");
    expect(formatPrice(500_000_000_000_000_000n)).toBe("0.5");
  });
});

describe("parsePriceToWei", () => {
  it("parses valid amounts", () => {
    expect(parsePriceToWei("1")).toBe(1_000_000_000_000_000_000n);
    expect(parsePriceToWei("0.5")).toBe(500_000_000_000_000_000n);
    expect(parsePriceToWei(".5")).toBe(500_000_000_000_000_000n);
  });

  it("rejects empty, zero, and non-numeric input", () => {
    expect(parsePriceToWei("")).toBeNull();
    expect(parsePriceToWei("   ")).toBeNull();
    expect(parsePriceToWei("0")).toBeNull();
    expect(parsePriceToWei("abc")).toBeNull();
    expect(parsePriceToWei("-1")).toBeNull();
    expect(parsePriceToWei("1.2.3")).toBeNull();
  });
});

describe("isValidPrice", () => {
  it("mirrors parsePriceToWei", () => {
    expect(isValidPrice("1.5")).toBe(true);
    expect(isValidPrice("0")).toBe(false);
    expect(isValidPrice("")).toBe(false);
  });
});
