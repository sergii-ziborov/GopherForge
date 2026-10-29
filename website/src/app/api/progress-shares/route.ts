import { publishProgress } from "@/lib/progress-share";
import {
  errorResponse,
  guardRequest,
  noStore,
  readJSON,
} from "@/lib/relay-http";
export const runtime = "nodejs";
export async function POST(request: Request) {
  try {
    guardRequest(request, 20);
    return Response.json(
      await publishProgress(await readJSON(request, 96 * 1024)),
      { status: 201, headers: noStore },
    );
  } catch (error) {
    return errorResponse(error);
  }
}
