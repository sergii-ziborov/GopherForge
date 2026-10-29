// Legacy editorial records have calendar-day precision. Normalize those dates
// to the start of that UTC day for metadata; this is not an exact publish clock.
// Records with an evidenced timestamp retain their original time and offset.
export function metadataDate(value: string): string {
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) return `${value}T00:00:00Z`;
  return value;
}
