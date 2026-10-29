export const NEWS_PAGE_SIZE = 9;
export const newsPageCount = (total: number) =>
  Math.max(1, Math.ceil(total / NEWS_PAGE_SIZE));
export const newsPageURL = (page: number) =>
  page === 1 ? "/news" : `/news/page/${page}`;
export function newsPageBounds(total: number, page: number) {
  if (!Number.isSafeInteger(page) || page < 1 || page > newsPageCount(total))
    return null;
  const start = (page - 1) * NEWS_PAGE_SIZE;
  return { start, end: Math.min(start + NEWS_PAGE_SIZE, total) };
}
// Only summaries cross the client boundary, never complete article bodies.
export type NewsCard = {
  url: string;
  title: string;
  description: string;
  category: string;
  edition: string;
  minutes: number;
  image: { src: string; width: number; height: number };
};
