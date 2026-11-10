export async function sourceFingerprint(files: Record<string, string>) {
  const bytes = new TextEncoder().encode(
    JSON.stringify(
      Object.entries(files).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)),
    ),
  );
  return Array.from(
    new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
}
