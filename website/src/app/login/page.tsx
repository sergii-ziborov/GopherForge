import type { Metadata } from "next";
import { AccountPreview } from "@/components/AccountPreview";
export const metadata: Metadata = {
  title: "Login preview — accounts coming soon",
  robots: { index: false, follow: true },
  alternates: { canonical: "/login" },
};
export default function Page() {
  return <AccountPreview mode="login" />;
}
