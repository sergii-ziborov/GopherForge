import { roomAction } from "@/lib/playground-core";
import {
  errorResponse,
  guardRequest,
  noStore,
  readJSON,
} from "@/lib/relay-http";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export async function POST(request: Request) {
  try {
    guardRequest(request, 240);
    const input = await readJSON(request);
    if (input.op === "create") guardRequest(request, 6, "room-create");
    return Response.json(
      roomAction(
        input,
        request.headers.get("authorization")?.replace(/^Bearer /, ""),
      ),
      { headers: noStore },
    );
  } catch (error) {
    return errorResponse(error);
  }
}
