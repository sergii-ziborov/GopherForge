// Existing articles keep their three-image layout. Longer guides can place
// additional figures at named sections without relying on shifting indices.
export const newsDetailSection: Record<string, string> = {
  unicodefield: "a-tiny-substring-can-keep-a-large-allocation-reachable",
  mongocursor: "transaction-callbacks-may-execute-again",
};

export const newsDetailCaptions: Record<string, string> = {
  mongocursor:
    "A conceptual counterexample: repeating a transaction callback can repeat an independent external effect. The database transaction does not make those external calls atomic; see the separate delivery-boundary discussion.",
};

export const newsExtraFigures: Record<
  string,
  { suffix: string; afterSection: string; caption: string }[]
> = {
  unicodefield: [
    {
      suffix: "normalization",
      afterSection: "canonical-equivalence-does-not-mean-the-bytes-match",
      caption:
        "Canonical equivalence can join different representations under an explicit policy. Visual lookalikes do not automatically become equivalent. Conceptual illustration, not a complete normalization or security algorithm.",
    },
    {
      suffix: "stream",
      afterSection: "network-chunks-are-not-utf-8-boundaries",
      caption:
        "A decoder carries an incomplete sequence across chunks and checks it at the actual end of input. Transport boundaries do not define code-point boundaries. Conceptual illustration; see the tested reader below.",
    },
  ],
};

export const newsImageSuffixes = (prefix: string) => [
  "hero",
  "detail",
  "infographic",
  ...(newsExtraFigures[prefix] ?? []).map((f) => f.suffix),
];
