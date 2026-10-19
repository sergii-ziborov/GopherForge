import raw from "@/content/course.json";
export type Section = {
  title: string;
  body: string;
  code?: string;
  language?: string;
  walkthrough?: string;
};
export type Guide = {
  family: string;
  flow: string[];
  strengths: string[];
  cautions: string[];
  cost: string;
  ratings: { scenario: string; score: number }[];
};
export type Quiz = {
  question: string;
  correct: string;
  alternatives: string[];
  explanation: string;
  hint: string;
};
export type Lesson = {
  id: string;
  title: string;
  objective: string;
  explanation: string;
  kind: string;
  source?: string;
  question?: string;
  tags: string[];
  guide?: {
    id: string;
    title: string;
    mode: "flow" | "sequence" | "comparison" | "stack" | "shared" | "fanout";
    nodes: { label: string; code: string; detail: string }[];
    caption: string;
    practical: string;
    watchOut: string;
    reference: string;
  };
  reading?: {
    sections: Section[];
    takeaway: string;
    references: string[];
    designGuide?: Guide;
    review?: { prompt: string; answer: string };
    quiz?: Quiz;
  };
};
export type Unit = {
  id: string;
  title: string;
  summary: string;
  translationNote: string;
  lessons: Lesson[];
};
export const units = raw as Unit[];
export const lessons = units.flatMap((u) =>
  u.lessons.map((l) => ({ ...l, unitID: u.id, unitTitle: u.title })),
);
export const lessonByID = new Map(lessons.map((l) => [l.id, l]));
export const readings = lessons.filter((l) => l.kind === "reading");
export const teachingCount = lessons.filter((l) => l.kind !== "predict").length;
export const minutes = (lesson: Lesson) =>
  Math.max(
    3,
    Math.ceil(
      [
        lesson.explanation,
        ...(lesson.reading?.sections.map(
          (s) => s.body + " " + (s.walkthrough ?? ""),
        ) ?? []),
      ]
        .join(" ")
        .split(/\s+/).length / 180,
    ),
  );
export const lessonURL = (id: string) => `/learn/${encodeURIComponent(id)}`;
export const github = "https://github.com/sergii-ziborov/GopherForge";
export const appStore = "https://apps.apple.com/app/id6809702319";
