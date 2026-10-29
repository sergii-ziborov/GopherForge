import { transferredSlice, taggedWrite } from "./progress-overlay.ts";
// Small, versioned bookmarks. Existing lesson completions and interview marks
// keep their original keys so an upgrade never resets a learner's work.
export type StudyArea = "course" | "interview";
export type Bookmark = { id: string; section: string };
export type Study = {
  version: 1;
  area: StudyArea | null;
  course: Bookmark | null;
  interview: Bookmark | null;
};
export const studyKey = "gopherforge.study.v1";
export const studyEvent = "gopherforge:study";
export const assessmentKey = "gopherforge.interview.self-assessment.v1";
export type Assessment = "revisit" | "understood";
export const emptyStudy: Study = {
  version: 1,
  area: null,
  course: null,
  interview: null,
};
function bookmark(value: unknown): Bookmark | null {
  if (!value || typeof value !== "object") return null;
  const b = value as Record<string, unknown>;
  return typeof b.id === "string" && b.id.length > 0 && b.id.length <= 160
    ? {
        id: b.id,
        section:
          typeof b.section === "string" &&
          /^[a-zA-Z0-9_-]{0,80}$/.test(b.section)
            ? b.section
            : "",
      }
    : null;
}
export function readStudy(): Study {
  try {
    const raw = localStorage.getItem(studyKey) ?? null;
    const p = transferredSlice(studyKey, raw) ?? JSON.parse(raw ?? "null");
    if (p?.version === 1)
      return {
        version: 1,
        area: p.area === "course" || p.area === "interview" ? p.area : null,
        course: bookmark(p.course),
        interview: bookmark(p.interview),
      };
  } catch {}
  return { ...emptyStudy };
}
export function visitStudy(area: StudyArea, id: string, section = ""): boolean {
  const value = bookmark({ id, section });
  if (!value) return false;
  const current = readStudy();
  if (
    current.area === area &&
    current[area]?.id === id &&
    current[area]?.section === value.section
  )
    return true;
  try {
    localStorage.setItem(
      studyKey,
      JSON.stringify(taggedWrite({ ...current, area, [area]: value })),
    );
    window.dispatchEvent(new Event(studyEvent));
    return true;
  } catch {
    return false;
  }
}
export function clearStudyArea(area: StudyArea): boolean {
  const current = readStudy();
  const other = area === "course" ? "interview" : "course";
  try {
    localStorage.setItem(
      studyKey,
      JSON.stringify(
        taggedWrite({
          ...current,
          [area]: null,
          area:
            current.area === area
              ? current[other]
                ? other
                : null
              : current.area,
        }),
      ),
    );
    window.dispatchEvent(new Event(studyEvent));
    return true;
  } catch {
    return false;
  }
}
export function studyURL(area: StudyArea, value: Bookmark): string {
  return `/${area === "course" ? "learn" : "interview"}/${encodeURIComponent(value.id)}${value.section ? `#${value.section}` : ""}`;
}
export function readAssessments(): Record<string, Assessment> {
  try {
    const raw = localStorage.getItem(assessmentKey) ?? null;
    const value =
      transferredSlice(assessmentKey, raw) ?? JSON.parse(raw ?? "{}");
    if (value && typeof value === "object" && !Array.isArray(value))
      return Object.fromEntries(
        Object.entries(value)
          .filter(([, v]) => v === "revisit" || v === "understood")
          .slice(0, 1000),
      ) as Record<string, Assessment>;
  } catch {}
  return {};
}
export function saveAssessment(id: string, value: Assessment | ""): boolean {
  const marks = readAssessments();
  if (value) marks[id] = value;
  else delete marks[id];
  try {
    localStorage.setItem(assessmentKey, JSON.stringify(taggedWrite(marks)));
    window.dispatchEvent(new Event(studyEvent));
    return true;
  } catch {
    return false;
  }
}
