import { readProgress, progressKey, type Progress } from "./progress.ts";
import {
  readStudy,
  readAssessments,
  studyKey,
  studyEvent,
  assessmentKey,
  type Study,
  type Assessment,
  type Bookmark,
} from "./study.ts";
import { transferOverlayKey } from "./progress-overlay.ts";

export const maximumTransferBytes = 2 * 1024 * 1024;
const keys = [progressKey, studyKey, assessmentKey];
type Catalog = { lessons: readonly string[]; interview: readonly string[] };
export type ProgressTransfer = {
  application: "GopherForge web learning";
  schemaVersion: 1;
  exportedAt: string;
  contentRevision: string;
  progress: Progress;
  study: Study;
  assessments: Record<string, Assessment>;
};
const id = (v: unknown): v is string =>
  typeof v === "string" && /^[a-zA-Z0-9._:-]{1,160}$/.test(v);
const object = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === "object" && !Array.isArray(v);
function mark(v: unknown): Bookmark | null {
  if (v === null) return null;
  if (
    !object(v) ||
    !id(v.id) ||
    typeof v.section !== "string" ||
    !/^[a-zA-Z0-9_-]{0,80}$/.test(v.section)
  )
    throw new Error("Invalid saved place in this file.");
  return { id: v.id, section: v.section };
}
export function parseTransfer(text: string): ProgressTransfer {
  if (new TextEncoder().encode(text).byteLength > maximumTransferBytes)
    throw new Error("Choose a progress file smaller than 2 MiB.");
  const v: unknown = JSON.parse(text);
  if (
    !object(v) ||
    v.application !== "GopherForge web learning" ||
    v.schemaVersion !== 1
  )
    throw new Error(
      "This is not a supported GopherForge web progress file. Your progress has not changed.",
    );
  if (
    typeof v.exportedAt !== "string" ||
    !Number.isFinite(Date.parse(v.exportedAt)) ||
    typeof v.contentRevision !== "string" ||
    v.contentRevision.length > 100
  )
    throw new Error("Invalid export metadata.");
  const p = v.progress,
    s = v.study,
    a = v.assessments;
  if (
    !object(p) ||
    p.version !== 1 ||
    !Array.isArray(p.completed) ||
    p.completed.length > 1000 ||
    !p.completed.every(id) ||
    !(p.last === null || id(p.last))
  )
    throw new Error("Invalid course progress.");
  if (
    !object(s) ||
    s.version !== 1 ||
    ![null, "course", "interview"].includes(s.area as string | null)
  )
    throw new Error("Invalid study bookmarks.");
  if (
    !object(a) ||
    Object.keys(a).length > 1000 ||
    !Object.entries(a).every(
      ([k, value]) =>
        id(k) && ["understood", "revisit"].includes(value as string),
    )
  )
    throw new Error("Invalid interview self-assessment.");
  return {
    application: "GopherForge web learning",
    schemaVersion: 1,
    exportedAt: v.exportedAt,
    contentRevision: v.contentRevision,
    progress: {
      version: 1,
      completed: [...new Set(p.completed as string[])],
      last: p.last as string | null,
    },
    study: {
      version: 1,
      area: s.area as Study["area"],
      course: mark(s.course),
      interview: mark(s.interview),
    },
    assessments: Object.fromEntries(Object.entries(a)) as Record<
      string,
      Assessment
    >,
  };
}
function assertWritableFormat() {
  const raw = localStorage.getItem(transferOverlayKey);
  if (raw) {
    const overlay = JSON.parse(raw);
    if (
      overlay?.schemaVersion !== 1 ||
      !object(overlay.base) ||
      !object(overlay.data)
    )
      throw new Error(
        "Existing progress uses an unsupported format. It has not been replaced.",
      );
  }
  for (const key of [progressKey, studyKey]) {
    const legacy = localStorage.getItem(key);
    if (legacy && JSON.parse(legacy)?.version !== 1)
      throw new Error(
        "Existing progress uses an unsupported format. It has not been replaced.",
      );
  }
}
export function exportTransfer(contentRevision: string): ProgressTransfer {
  assertWritableFormat();
  return {
    application: "GopherForge web learning",
    schemaVersion: 1,
    exportedAt: new Date().toISOString(),
    contentRevision,
    progress: readProgress(),
    study: readStudy(),
    assessments: readAssessments(),
  };
}
function mergeTransfer(value: ProgressTransfer, catalog: Catalog) {
  const courseIDs = new Set(catalog.lessons),
    interviewIDs = new Set(catalog.interview);
  const current = readProgress(),
    study = readStudy(),
    assessments = readAssessments();
  const known = value.progress.completed.filter((x) => courseIDs.has(x));
  const completed = [...new Set([...current.completed, ...known])];
  const incomingAssessments = Object.fromEntries(
    Object.entries(value.assessments).filter(([key]) => interviewIDs.has(key)),
  );
  const unknown = new Set([
    ...value.progress.completed.filter((x) => !courseIDs.has(x)),
    ...Object.keys(value.assessments).filter((x) => !interviewIDs.has(x)),
  ]);
  const knownBookmark = (b: Bookmark | null, ids: Set<string>) => {
    if (b && !ids.has(b.id)) {
      unknown.add(b.id);
      return null;
    }
    return b;
  };
  const course = knownBookmark(value.study.course, courseIDs),
    interview = knownBookmark(value.study.interview, interviewIDs);
  if (value.progress.last && !courseIDs.has(value.progress.last))
    unknown.add(value.progress.last);
  const mergedStudy: Study = {
    version: 1,
    area: study.area ?? value.study.area,
    course: study.course ?? course,
    interview: study.interview ?? interview,
  };
  if (mergedStudy.area && !mergedStudy[mergedStudy.area])
    mergedStudy.area = mergedStudy.course
      ? "course"
      : mergedStudy.interview
        ? "interview"
        : null;
  const mergedAssessments = { ...incomingAssessments, ...assessments };
  if (completed.length > 1000 || Object.keys(mergedAssessments).length > 1000)
    throw new Error(
      "The combined progress exceeds this version’s 1,000-record limit. No records were removed.",
    );
  return {
    progress: {
      version: 1,
      completed,
      last:
        current.last ??
        (value.progress.last && courseIDs.has(value.progress.last)
          ? value.progress.last
          : null),
    } as Progress,
    study: mergedStudy,
    assessments: mergedAssessments,
    preview: {
      addedLessons: known.filter((x) => !current.completed.includes(x)).length,
      matchingLessons: known.filter((x) => current.completed.includes(x))
        .length,
      addedAssessments: Object.keys(incomingAssessments).filter(
        (x) => !(x in assessments),
      ).length,
      keptAssessmentConflicts: Object.entries(incomingAssessments).filter(
        ([k, v]) => assessments[k] && assessments[k] !== v,
      ).length,
      unknownIDs: [...unknown],
      exportedAt: value.exportedAt,
      contentRevision: value.contentRevision,
    },
  };
}
export function previewTransfer(value: ProgressTransfer, catalog: Catalog) {
  return mergeTransfer(value, catalog).preview;
}
export function importTransfer(value: ProgressTransfer, catalog: Catalog) {
  // Revalidate and rebase at the click; marks made after Preview are preserved.
  const checked = parseTransfer(JSON.stringify(value));
  assertWritableFormat();
  const merged = mergeTransfer(checked, catalog);
  const base = Object.fromEntries(
    keys.map((key) => [key, localStorage.getItem(key) ?? null]),
  );
  const data = {
    [progressKey]: merged.progress,
    [studyKey]: merged.study,
    [assessmentKey]: merged.assessments,
  };
  localStorage.setItem(
    transferOverlayKey,
    JSON.stringify({ schemaVersion: 1, base, data }),
  );
  window.dispatchEvent(new Event("gopherforge:progress"));
  window.dispatchEvent(new Event(studyEvent));
  return merged.preview;
}
