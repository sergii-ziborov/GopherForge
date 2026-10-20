"use client";
import { useEffect } from "react";
import { visitStudy, type StudyArea } from "@/lib/study";

export function StudyBookmark({ area, id }: { area: StudyArea; id: string }) {
  useEffect(() => {
    const hash = () => window.location.hash.slice(1);
    visitStudy(area, id, hash());
    let timer: ReturnType<typeof setTimeout>;
    const saveHash = () => visitStudy(area, id, hash());
    const savePosition = () => {
      clearTimeout(timer);
      timer = setTimeout(() => {
        const sections = Array.from(
          document.querySelectorAll<HTMLElement>(".lesson-article [id]"),
        );
        const current = sections
          .filter(
            (section) =>
              section.getBoundingClientRect().top <= window.innerHeight * 0.35,
          )
          .at(-1);
        if (current) visitStudy(area, id, current.id);
      }, 180);
    };
    window.addEventListener("hashchange", saveHash);
    window.addEventListener("scroll", savePosition, { passive: true });
    return () => {
      clearTimeout(timer);
      window.removeEventListener("hashchange", saveHash);
      window.removeEventListener("scroll", savePosition);
    };
  }, [area, id]);
  return null;
}
