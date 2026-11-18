import { ImageResponse } from "next/og";
import { specializedCourses } from "@/lib/specialized-courses";

export const alt = "A dedicated GopherForge course";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export function generateStaticParams() {
  return specializedCourses.map((c) => ({ id: c.id }));
}

export default async function CourseImage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const c = specializedCourses.find((c) => c.id === id);
  const title = c?.title ?? "GopherForge courses";
  const units = c?.courseUnits.length ?? 0;
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
        {`GopherForge / ${c?.eyebrow ?? "DEDICATED COURSES"}`}
      </div>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          fontSize: 84,
          fontWeight: 700,
          lineHeight: 1.08,
          letterSpacing: -4,
        }}
      >
        <span>{title}</span>
        <span style={{ color: "#056c71", fontSize: 48, letterSpacing: -1 }}>
          {c ? `${c.lessonCount} worked lessons · ${units} units · free` : ""}
        </span>
      </div>
      <div style={{ fontSize: 25, color: "#5c6a68" }}>
        gopherforge.app/courses · iPhone · iPad · Web
      </div>
    </div>,
    size,
  );
}
