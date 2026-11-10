import { releases } from "@/lib/releases";

export function AppPrice() {
  return (
    <span className="sale-price">
      <del aria-label="Regular price">${releases.regularPriceUSD}</del>{" "}
      <strong aria-label="Sale price">${releases.priceUSD} USD</strong>{" "}
      <span className="sale-badge">
        Save{" "}
        {Math.round(
          (1 - Number(releases.priceUSD) / Number(releases.regularPriceUSD)) *
            100,
        )}
        %
      </span>
    </span>
  );
}
