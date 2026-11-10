import { ImageResponse } from "next/og";
export const alt = "GopherForge — Go compiler for iPhone, iPad and the web";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export default function OpenGraphImage() {
  return new ImageResponse(
    <div
      style={{
        display: "flex",
        width: "100%",
        height: "100%",
        background: "#f6f5f0",
        color: "#1a2d2d",
        padding: 65,
        flexDirection: "column",
        justifyContent: "space-between",
      }}
    >
      <div style={{ fontSize: 28, color: "#056c71" }}>
        GopherForge / A WORKBENCH FOR GO
      </div>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          fontSize: 91,
          fontWeight: 700,
          lineHeight: 1.08,
          letterSpacing: -5,
        }}
      >
        <span>Write Go. Learn Go.</span>
        <span style={{ color: "#056c71" }}>On your device.</span>
      </div>
      <div style={{ fontSize: 25, color: "#5c6a68" }}>
        iPhone · iPad · Browser Playground · Encrypted MCP
      </div>
    </div>,
    size,
  );
}
