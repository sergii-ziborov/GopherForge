import type { Metadata } from "next";
import { AccountPreview } from "@/components/AccountPreview";
export const metadata: Metadata = {
  title: "Registration preview — accounts coming soon",
  robots: { index: false, follow: true },
  alternates: { canonical: "/register" },
};
export default function Page() {
  return <AccountPreview mode="register" />;
}
