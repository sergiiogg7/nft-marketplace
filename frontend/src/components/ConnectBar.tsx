"use client";

import { useAccount, useConnect, useDisconnect } from "wagmi";
import { shortenAddress } from "@/lib/format";

export function ConnectBar() {
  const { address, isConnected } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();

  return (
    <div className="header">
      <h1>
        🖼️ NFT Marketplace <span className="badge">Anvil · 31337</span>
      </h1>
      {isConnected ? (
        <div className="row" style={{ alignItems: "center" }}>
          <span className="badge">{shortenAddress(address ?? "")}</span>
          <button className="secondary" onClick={() => disconnect()}>
            Disconnect
          </button>
        </div>
      ) : (
        <button onClick={() => connect({ connector: connectors[0] })} disabled={isPending}>
          {isPending ? "Connecting…" : "Connect Wallet"}
        </button>
      )}
    </div>
  );
}
