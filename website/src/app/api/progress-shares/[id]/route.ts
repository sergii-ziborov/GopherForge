import { readSharedProgress, revokeProgress } from "@/lib/progress-share";
import {
  errorResponse,
  guardRequest,
  noStore,
  readJSON,
} from "@/lib/relay-http";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const value = await readSharedProgress((await context.params).id);
  return Response.json(
    value ?? { error: "This progress link expired or was revoked." },
    {
      status: value ? 200 : 404,
      headers: { ...noStore, "X-Robots-Tag": "noindex, nofollow" },
    },
  );
}
export async function DELETE(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  try {
    guardRequest(request, 20);
    const body = await readJSON(request, 1024);
    return Response.json(
      await revokeProgress((await context.params).id, body.revokeToken),
      { headers: noStore },
    );
  } catch (error) {
    return errorResponse(error);
  }
}
