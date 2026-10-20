import { news, newsURL } from "@/lib/news";
const xml = (s: string) =>
  s.replace(
    /[<>&"']/g,
    (c) =>
      ({
        "<": "&lt;",
        ">": "&gt;",
        "&": "&amp;",
        '"': "&quot;",
        "'": "&apos;",
      })[c]!,
  );
export function GET() {
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?><rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>GopherForge Go News</title><link>https://gopherforge.app/news</link><description>Original Go news and practical engineering analysis.</description><language>en</language><atom:link href="https://gopherforge.app/news/rss.xml" rel="self" type="application/rss+xml"/>${news.map((n) => `<item><title>${xml(n.title)}</title><link>https://gopherforge.app${newsURL(n.slug)}</link><guid isPermaLink="true">https://gopherforge.app${newsURL(n.slug)}</guid><pubDate>${new Date(n.publishedAt).toUTCString()}</pubDate><description>${xml(n.description)}</description></item>`).join("")}</channel></rss>`,
    {
      headers: {
        "Content-Type": "application/rss+xml; charset=utf-8",
        "Cache-Control": "public, max-age=3600",
      },
    },
  );
}
