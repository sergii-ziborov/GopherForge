export function GET() {
  return Response.json(
    { status: "ok", service: "gopherforge-web" },
    { headers: { "Cache-Control": "no-store" } },
  );
}
