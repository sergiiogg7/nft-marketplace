"use client";

import { createConfig, http } from "wagmi";
import { anvil } from "wagmi/chains";
import { injected } from "wagmi/connectors";

// Local Anvil chain (id 31337) with the injected (MetaMask) connector.
// Plain wagmi config — no RainbowKit, to avoid the Base Account / Coinbase dep tree.
export const config = createConfig({
  chains: [anvil],
  connectors: [injected()],
  transports: {
    [anvil.id]: http("http://127.0.0.1:8545"),
  },
  ssr: true,
});
