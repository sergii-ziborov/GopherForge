import { NewsListing, newsListingMetadata } from "@/components/NewsListing";
export const metadata = newsListingMetadata(1);
export default function NewsPage() {
  return <NewsListing />;
}
