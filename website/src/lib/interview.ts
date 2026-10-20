import raw from "@/content/interview.json";
export type TraceRow = { label: string; values: string[]; active: number[] };
export type TraceStep = { title: string; note: string; rows: TraceRow[] };
export type Demonstration = {
  id: string;
  cases: { name: string; input: string; result: string; steps: TraceStep[] }[];
};
export type InterviewGuide = {
  id: string;
  topic: string;
  level: number;
  title: string;
  prompt: string;
  answerPoints: string[];
  trap: string;
  exercise: string;
  solution: string;
  followUp: string;
  references: string[];
  code: string;
  complexity: string;
};
export const interview = raw as {
  schemaVersion: number;
  reviewedOn: string;
  levels: string[];
  topics: { id: string; title: string; route: string }[];
  questions: InterviewGuide[];
  demonstrations: Demonstration[];
};
export const interviewURL = (id: string) =>
  `/interview/${encodeURIComponent(id)}`;
