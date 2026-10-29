"use client";
import { useId, useState } from "react";
import { ProgressShare } from "./ProgressShare";
import {
  exportTransfer,
  importTransfer,
  maximumTransferBytes,
  parseTransfer,
  previewTransfer,
  type ProgressTransfer as Transfer,
} from "@/lib/progress-transfer";

export function ProgressTransfer({
  lessons,
  interview,
  revision,
}: {
  lessons: string[];
  interview: string[];
  revision: string;
}) {
  const inputID = useId();
  const [pending, setPending] = useState<{
    value: Transfer;
    preview: ReturnType<typeof previewTransfer>;
  } | null>(null);
  const [message, setMessage] = useState("");
  const catalog = { lessons, interview };
  const preview = pending?.preview;
  function download() {
    try {
      const data = exportTransfer(revision);
      const url = URL.createObjectURL(
        new Blob([JSON.stringify(data, null, 2)], { type: "application/json" }),
      );
      const link = document.createElement("a");
      link.href = url;
      link.download = `gopherforge-web-progress-${data.exportedAt.slice(0, 10)}.json`;
      document.body.append(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setMessage(
        "Progress file downloaded. Keep it somewhere safe; browser data is not a backup.",
      );
    } catch {
      setMessage(
        "Progress could not be exported. Browser storage may be blocked or use an unsupported format.",
      );
    }
  }
  async function choose(file: File | undefined) {
    setPending(null);
    setMessage("");
    if (!file) return;
    try {
      if (file.size > maximumTransferBytes)
        throw new Error("Choose a progress file smaller than 2 MiB.");
      const value = parseTransfer(await file.text());
      setPending({ value, preview: previewTransfer(value, catalog) });
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "This progress file could not be read.",
      );
    }
  }
  function apply() {
    if (!pending) return;
    try {
      const result = importTransfer(pending.value, catalog);
      setMessage(
        `Imported ${result.addedLessons} lesson marks and ${result.addedAssessments} interview marks. Your current saved places and existing answers were kept.`,
      );
      setPending(null);
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Import failed. Your existing progress was kept.",
      );
    }
  }
  return (
    <>
      <ProgressShare revision={revision} />
      <details className="progress-transfer">
        <summary>Back up or move your local progress</summary>
        <p>
          Download your course marks, interview self-assessments and Continue
          bookmarks. No account, upload or automatic app sync. Web marks are
          self-reported, not compiler results.
        </p>
        <button className="button secondary" type="button" onClick={download}>
          Download progress
        </button>
        <div className="progress-transfer-file">
          <label htmlFor={inputID}>Preview a saved progress file</label>
          <input
            id={inputID}
            type="file"
            accept="application/json,.json"
            onChange={(event) => {
              const file = event.currentTarget.files?.[0];
              event.currentTarget.value = "";
              void choose(file);
            }}
          />
        </div>
        {preview && (
          <section
            className="progress-transfer-preview"
            aria-label="Import preview"
          >
            <h3>Review before importing</h3>
            <p>
              Exported {preview.exportedAt.slice(0, 10)} · content revision{" "}
              {preview.contentRevision}
            </p>
            <ul>
              <li>
                {preview.addedLessons} lesson marks to add;{" "}
                {preview.matchingLessons} already present.
              </li>
              <li>{preview.addedAssessments} interview marks to add.</li>
              <li>
                {preview.keptAssessmentConflicts} conflicting interview answers:
                this browser’s answers will stay.
              </li>
              <li>
                Your current Continue bookmarks will stay; missing bookmarks can
                be filled from this file.
              </li>
            </ul>
            {preview.unknownIDs.length > 0 && (
              <p>
                {preview.unknownIDs.length} unknown material IDs will be
                skipped: {preview.unknownIDs.slice(0, 8).join(", ")}
                {preview.unknownIDs.length > 8 ? "…" : ""}. Keep the original
                backup file.
              </p>
            )}
            <div className="progress-transfer-actions">
              <button className="button" type="button" onClick={apply}>
                Merge into this browser
              </button>
              <button
                className="button secondary"
                type="button"
                onClick={() => setPending(null)}
              >
                Cancel
              </button>
            </div>
          </section>
        )}
        <p role="status" aria-live="polite">
          {message}
        </p>
      </details>
    </>
  );
}
