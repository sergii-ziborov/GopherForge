import { ImageResponse } from "next/og";
export const alt =
  "GopherForge MCP — encrypted Go Playground collaboration with your AI agent";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export default function MCPImage() {
  return new ImageResponse(
    <div
      style={{
        display: "flex",
        width: "100%",
        height: "100%",
        background: "#123d42",
        color: "#f8f6ec",
        padding: 64,
        flexDirection: "column",
        justifyContent: "space-between",
      }}
    >
      <div style={{ display: "flex", fontSize: 28, color: "#80d5d9" }}>
        GOPHERFORGE / JAVASCRIPT MCP
      </div>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          fontSize: 82,
          lineHeight: 1.08,
          fontWeight: 700,
          letterSpacing: -3,
        }}
      >
        <span>Your AI. Your Go.</span>
        <span style={{ color: "#80d5d9" }}>Encrypted rooms.</span>
      </div>
      <div style={{ display: "flex", fontSize: 28 }}>
        Named cursors · Local Run/Test · Web + iPhone + iPad
      </div>
    </div>,
    size,
  );
}
