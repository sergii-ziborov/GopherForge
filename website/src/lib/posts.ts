import data from "@/content/posts.json";
export type Post = {
  slug: string;
  title: string;
  description: string;
  category: string;
  date: string;
  readingMinutes: number;
  related: string[];
  sections: { title: string; body: string; code?: string; language?: string }[];
  references: string[];
};
export const posts = data as Post[];
