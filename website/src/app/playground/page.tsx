import type { Metadata } from "next";
import "./playground.css";
import { Playground } from "@/components/Playground";
import Link from "next/link";
import { StructuredData } from "@/components/StructuredData";
import { pageMetadata } from "@/lib/page-metadata";
export const metadata: Metadata = pageMetadata(
  "/playground",
  "Online Go Playground — Run, Debug & Collaborate",
  "Run, debug, test and format Go locally in your browser. Edit multiple files, prepare Go modules and connect your AI agent through GopherForge's encrypted MCP.",
);
export default function PlaygroundPage() {
  return (
    <>
      <Playground />
      <section className="page">
        <h2>A Go compiler in your browser</h2>
        <p>
          Write a multi-file Go project, run tests, step through source and
          inspect Output. Compilation and execution happen locally in a browser
          worker. Your draft stays on this device until you deliberately share
          it. No account is required.
        </p>
        <p>
          Encrypted rooms connect browser participants, native GopherForge 1.3.3
          and your agent through the{" "}
          <Link href="/guide/mcp">GopherForge JavaScript MCP companion</Link>.
          See the <Link href="/guide#browser-playground">Playground guide</Link>{" "}
          for limits, packages and recovery, or start with{" "}
          <Link href="/learn/units/core">Go fundamentals</Link>.
        </p>
      </section>
      <StructuredData
        data={{
          "@context": "https://schema.org",
          "@type": "WebApplication",
          "@id": "https://gopherforge.app/playground#application",
          name: "GopherForge Go Playground",
          url: "https://gopherforge.app/playground",
          applicationCategory: "DeveloperApplication",
          operatingSystem: "Modern web browser with WebAssembly",
          browserRequirements: "JavaScript, WebAssembly and Web Crypto enabled",
          description:
            "Local browser Go compiler, source debugger, tests and encrypted collaboration with a GopherForge MCP agent.",
          isAccessibleForFree: true,
          offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
          publisher: { "@id": "https://gopherforge.app/#organization" },
        }}
      />
    </>
  );
}
