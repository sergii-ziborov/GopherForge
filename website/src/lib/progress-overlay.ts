// A transfer commits all three progress slices with one atomic storage write.
// A later ordinary save overrides only its own slice. Legacy keys are retained.
export const transferOverlayKey = "gopherforge.progress-transfer.overlay.v1";
export function transferredSlice(key: string, raw: string | null): unknown {
  try {
    const value = JSON.parse(
      localStorage.getItem(transferOverlayKey) ?? "null",
    );
    if (
      value?.schemaVersion === 1 &&
      value.base?.[key] === raw &&
      Object.hasOwn(value.data ?? {}, key)
    )
      return value.data[key];
  } catch {
    /* No usable overlay; the original storage remains authoritative. */
  }
  return undefined;
}

// Ordinary writes must invalidate an imported slice even when the user resets
// it to exactly the value that existed before import. This is not a secret.
export function taggedWrite<T extends object>(value: T) {
  return { ...value, __gopherforgeWrite: crypto.randomUUID() };
}
