"use client";

import { ConnectBar } from "@/components/ConnectBar";
import { ListForm } from "@/components/ListForm";
import { ListingsGrid } from "@/components/ListingsGrid";
import { useListings } from "@/hooks/useListings";

export default function Home() {
  const { listings, isLoading, refetch } = useListings();

  return (
    <main className="container">
      <ConnectBar />
      <ListForm onListed={() => refetch()} />
      <ListingsGrid listings={listings} isLoading={isLoading} onChanged={() => refetch()} />
    </main>
  );
}
