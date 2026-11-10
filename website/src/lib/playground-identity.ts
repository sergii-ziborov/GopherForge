export function nickname(value: unknown): string {
  if (typeof value !== "string") throw new Error("Choose a nickname");
  const name = value.normalize("NFKC").trim().replace(/ +/g, " ");
  if (
    !name ||
    name.length > 32 ||
    /[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/.test(name)
  )
    throw new Error("Use 1–32 characters without control characters");
  return name;
}
export type PeerCursor = {
  id: string;
  name: string;
  color: string;
  path: string;
  anchor: number;
  head: number;
};
export const peerColor = (id: string) =>
  ["#63b8c4", "#f1b46b", "#a799ef", "#8bce93"][
    Array.from(id).reduce((n, c) => n + c.charCodeAt(0), 0) % 4
  ];
