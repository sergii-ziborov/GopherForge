import type { Metadata } from "next";
import Link from "next/link";
import { Playground } from "@/components/Playground";
export const metadata: Metadata = {
  title: "Go Playground with Claude & Codex MCP",
  description:
    "Collaborate on Go source with Claude or Codex through MCP. Share device-attributed output, preserve local copies, and run only by pressing Run in the native app.",
  alternates: { canonical: "/playground" },
};
export default function PlaygroundPage() {
  return (
    <div className="page">
      <header className="page-heading">
        <p className="eyebrow">GUEST WORKSPACE · DEVELOPMENT PREVIEW</p>
        <h1>
          Code together.
          <br />
          <em>Run on your device.</em>
        </h1>
        <p>
          A shared Go editor for people and AI. No account. Temporary rooms,
          separate local copies, and output labelled with the device and exact
          source revision.
        </p>
        <p>
          <Link href="/guide/mcp">
            MCP setup, mobile use and execution rules →
          </Link>
        </p>
      </header>
      <Playground />
    </div>
  );
}
