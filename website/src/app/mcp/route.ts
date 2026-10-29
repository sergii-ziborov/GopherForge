import { mcpMessage } from "@/lib/playground-mcp";
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
    guardRequest(request, 180);
    const message = await readJSON(request);
    const response = await mcpMessage(
      message,
      request.headers.get("authorization")?.replace(/^Bearer /, ""),
    );
    return response
      ? Response.json(response, { headers: noStore })
      : new Response(null, { status: 202, headers: noStore });
  } catch (error) {
    return errorResponse(error);
  }
}
// Stateless Streamable HTTP uses JSON responses; a GET/SSE stream is optional.
export function GET() {
  return new Response(null, {
    status: 405,
    headers: { ...noStore, Allow: "POST" },
  });
}
