"use client";
import { useEffect, useState } from "react";
import { exportTransfer } from "@/lib/progress-transfer";
export function ProgressShare({ revision }: { revision: string }) {
  const [message, setMessage] = useState(""),
    [url, setURL] = useState(""),
    [busy, setBusy] = useState(false);
  useEffect(() => {
    try {
      const saved = JSON.parse(
        localStorage.getItem("gopherforge.progress.shares.v1") ?? "[]",
      );
      const last = saved.at(-1);
      if (
        typeof last?.url === "string" &&
        last.url.startsWith(location.origin + "/progress/")
      )
        setURL(last.url);
    } catch {
      /* publishing still works without storage */
    }
  }, []);
  async function share() {
    setBusy(true);
    try {
      const data = exportTransfer(revision);
      const response = await fetch("/api/progress-shares", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          schemaVersion: 1,
          source: "web",
          completed: data.progress.completed,
          compilerVerified: [],
          assessments: data.assessments,
          lastLessonID: data.study.course?.id ?? null,
          lastInterviewID: data.study.interview?.id ?? null,
        }),
      });
      const value = await response.json();
      if (!response.ok) throw new Error(value.error);
      const link = location.origin + value.path;
      setURL(link);
      // Save the revocation key before exposing the share as successfully published.
      try {
        const old = JSON.parse(
          localStorage.getItem("gopherforge.progress.shares.v1") ?? "[]",
        );
        localStorage.setItem(
          "gopherforge.progress.shares.v1",
          JSON.stringify([...old, { ...value, url: link }].slice(-30)),
        );
      } catch {
        setMessage(
          "Link published. Browser storage is unavailable; keep the revocation key: " +
            value.revokeToken,
        );
        return;
      }
      setMessage(
        "Published for 90 days. Anyone with this link, including an AI, can read these marks. Your drafts and source were not uploaded.",
      );
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Could not publish.");
    } finally {
      setBusy(false);
    }
  }
  async function revoke() {
    try {
      const values = JSON.parse(
        localStorage.getItem("gopherforge.progress.shares.v1") ?? "[]",
      ) as { url: string; shareID: string; revokeToken: string }[];
      const record = values.find((v) => v.url === url);
      if (!record)
        throw new Error("The revocation key is not in this browser.");
      const response = await fetch("/api/progress-shares/" + record.shareID, {
        method: "DELETE",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ revokeToken: record.revokeToken }),
      });
      if (!response.ok) throw new Error("Could not revoke this link.");
      setURL("");
      setMessage("Link revoked. Your local progress did not change.");
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Could not revoke.");
    }
  }
  return (
    <details className="progress-transfer">
      <summary>Share a progress link with a person or AI</summary>
      <p>
        Publish an explicit read-only snapshot of completed lesson IDs,
        interview marks and Continue places. It is public to anyone with the
        link for 90 days. It does not update automatically or change anyone’s
        progress. No code, attempts, names or account.
      </p>
      <button
        className="button secondary"
        disabled={busy}
        onClick={() => void share()}
      >
        Publish my progress snapshot
      </button>
      {url && (
        <>
          <p>
            <a href={url}>{url}</a>
          </p>
          <button
            onClick={() =>
              void navigator.clipboard.writeText(url).then(
                () => setMessage("Link copied."),
                () => setMessage("Select and copy the link above."),
              )
            }
          >
            Copy link
          </button>
          <button onClick={() => void revoke()}>Revoke this link</button>
        </>
      )}
      <p role="status">{message}</p>
    </details>
  );
}
