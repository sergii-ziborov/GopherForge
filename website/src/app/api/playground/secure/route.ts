import { secureAction } from "@/lib/secure-relay";
import {
  guardRequest,
  readJSON,
  noStore,
  errorResponse,
} from "@/lib/relay-http";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export async function POST(request: Request) {
  try {
    guardRequest(request, 2400);
    const input = await readJSON(request, 2300 * 1024);
    if (input.op === "create") guardRequest(request, 6, "secure-room-create");
    return Response.json(
      secureAction(
        input,
        request.headers.get("authorization")?.replace(/^Bearer /, ""),
      ),
      { headers: noStore },
    );
  } catch (e) {
    return errorResponse(e);
  }
}
