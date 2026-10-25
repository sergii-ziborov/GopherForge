import { newsImage } from "@/lib/news";

type Illustration =
  | "launch-hero"
  | "slices-hero"
  | "gopls24-detail"
  | "rebuild-hero"
  | "survey-detail"
  | "dapr-hero";

export function EditorialIllustration({
  id,
  alt = "",
  loading = "lazy",
  sizes = "(max-width: 760px) calc(100vw - 46px), 420px",
}: {
  id: Illustration;
  alt?: string;
  loading?: "eager" | "lazy";
  sizes?: string;
}) {
  const image = newsImage(id);
  return (
    <img
      className="editorial-illustration"
      src={`/images/news/${id}-small.webp`}
      srcSet={`/images/news/${id}-small.webp 720w, ${image.src} ${image.width}w`}
      sizes={sizes}
      width={image.width}
      height={image.height}
      alt={alt}
      loading={loading}
      decoding="async"
    />
  );
}
