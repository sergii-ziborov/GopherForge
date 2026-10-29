import type { Metadata } from "next";
import Link from "next/link";
import Image from "next/image";
import { appStore, github } from "@/lib/course";
import "./globals.css";
export const metadata: Metadata = {
  metadataBase: new URL("https://gopherforge.app"),
  title: {
    default: "GopherForge — Go Compiler, Course & Interview Prep",
    template: "%s — GopherForge",
  },
  description:
    "Learn Go with worked examples, interactive algorithms and interview guides. Compile, run and test Go offline on iPhone and iPad with GopherForge.",
  alternates: {
    canonical: "/",
    types: { "application/rss+xml": "/news/rss.xml" },
  },
  openGraph: {
    title: "GopherForge — Go Compiler, Course & Interview Prep",
    description:
      "Free Go lessons, interview preparation and a native offline Go workbench.",
    siteName: "GopherForge",
    type: "website",
    locale: "en_US",
    images: ["/images/news/launch-hero.webp"],
  },
  twitter: { card: "summary_large_image" },
};
export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <a className="skip" href="#main">
          Skip to content
        </a>
        <header className="site-header">
          <Link href="/" className="brand">
            <Image
              className="brand-mark"
              src="/images/app-icon.png"
              width={40}
              height={40}
              alt=""
              priority
            />
            <span>
              GopherForge<small>A WORKBENCH FOR GO</small>
            </span>
          </Link>
          <nav aria-label="Main">
            <Link href="/learn">Learn Go</Link>
            <Link href="/interview">Interview</Link>
            <Link href="/news">News</Link>
            <Link href="/guide">App guide</Link>
            <Link href="/playground">Playground</Link>
            <Link href="/updates">Updates</Link>
            <a className="nav-app" href={appStore}>
              Get the app <span aria-hidden="true">↗</span>
            </a>
          </nav>
        </header>
        <main id="main">{children}</main>
        <footer className="footer">
          <div>
            <Link className="footer-brand" href="/">
              GopherForge<span>Build something you understand.</span>
            </Link>
            <p>
              A native Go workbench and a practical learning library.
              <br />
              Independent of Google and the Go project.
            </p>
          </div>
          <div>
            <h2>Explore</h2>
            <Link href="/learn">Course</Link>
            <Link href="/interview">Interview</Link>
            <Link href="/news">News</Link>
            <Link href="/blog">Field notes</Link>
            <Link href="/news/feed">Community feed</Link>
            <Link href="/news/rss.xml">News RSS</Link>
            <Link href="/updates">Version history</Link>
            <a href={github}>GitHub</a>
          </div>
          <div>
            <h2>Help & details</h2>
            <Link href="/guide">App guide</Link>
            <Link href="/guide/mcp">MCP & AI collaboration</Link>
            <Link href="/support">Support</Link>
            <Link href="/support#package-limits">Package limits</Link>
            <Link href="/privacy">Privacy</Link>
            <Link href="/terms">Terms</Link>
          </div>
          <p className="copyright">
            © {new Date().getFullYear()} Serhii Ziborov. Native app: one-time
            paid purchase. Web lessons: freely readable without an account.
          </p>
        </footer>
      </body>
    </html>
  );
}
