import type { Metadata } from "next";

/** Keep the canonical page identity consistent in search and shared cards. */
export function pageMetadata(
  path: string,
  title: string,
  description: string,
): Metadata {
  const branded = `${title} — GopherForge`;
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: {
      title: branded,
      description,
      url: path,
      siteName: "GopherForge",
      type: "website",
      locale: "en_US",
      images: [
        {
          url: "/opengraph-image",
          width: 1200,
          height: 630,
          alt: "GopherForge Go compiler, Playground and learning library",
        },
      ],
    },
    twitter: { card: "summary_large_image", title: branded, description },
  };
}
