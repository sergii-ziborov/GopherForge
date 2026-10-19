import Link from "next/link";
export default function NotFound() {
  return (
    <section className="page narrow">
      <p className="eyebrow">404 · Lost in the imports</p>
      <h1>This page isn’t here.</h1>
      <p>
        The lesson may have moved. Every current lesson is in the course
        library.
      </p>
      <Link className="button" href="/learn">
        Find a lesson →
      </Link>
    </section>
  );
}
