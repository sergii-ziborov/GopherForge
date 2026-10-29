import { notFound, permanentRedirect } from "next/navigation";
import { news } from "@/lib/news";
import { newsPageBounds, newsPageCount } from "@/lib/news-pagination";
import { NewsListing, newsListingMetadata } from "@/components/NewsListing";
export const dynamicParams = false;
export function generateStaticParams() {
  return Array.from({ length: newsPageCount(news.length) }, (_, i) => ({
    page: String(i + 1),
  }));
}
type Props = { params: Promise<{ page: string }> };
async function pageNumber(params: Props["params"]) {
  const { page } = await params;
  if (!/^[1-9]\d*$/.test(page) || !newsPageBounds(news.length, Number(page)))
    notFound();
  return Number(page);
}
export async function generateMetadata({ params }: Props) {
  return newsListingMetadata(await pageNumber(params));
}
export default async function ArchivePage({ params }: Props) {
  const page = await pageNumber(params);
  if (page === 1) permanentRedirect("/news");
  return <NewsListing page={page} />;
}
