export const progressKey = "gopherforge.learning.v1";
export type Progress = { version: 1; completed: string[]; last: string | null };
export const emptyProgress: Progress = {
  version: 1,
  completed: [],
  last: null,
};
export function readProgress(): Progress {
  try {
    const p = JSON.parse(localStorage.getItem(progressKey) ?? "null");
    if (p?.version === 1 && Array.isArray(p.completed))
      return {
        version: 1,
        completed: p.completed
          .filter((x: unknown) => typeof x === "string")
          .slice(0, 1000),
        last: typeof p.last === "string" ? p.last : null,
      };
  } catch {}
  return { ...emptyProgress, completed: [] };
}
export function saveProgress(p: Progress) {
  try {
    localStorage.setItem(progressKey, JSON.stringify(p));
    window.dispatchEvent(new Event("gopherforge:progress"));
    return true;
  } catch {
    return false;
  }
}
