import { newProject, encrypt, decrypt, encryptionKey, secureLink, Y } from "../../../website/src/lib/secure-collab.ts";
import { secureAction } from "../../../website/src/lib/secure-relay.ts";
export { Y, decrypt };
export const files = { "main.go": 'package main\nimport "fmt"\nfunc main() { fmt.Println("private Go draft") }\n', "go.mod": "module playground\ngo 1.27.1\n" };
export async function fixture(origin = "https://gopherforge.app") {
  const secret = encryptionKey(), doc = newProject(files);
  const room = secureAction({ op: "create", ttlSeconds: 60, snapshot: await encrypt(secret, Y.encodeStateAsUpdate(doc)) });
  doc.destroy();
  const state = {
    room, secret, origin, calls: [],
    link: role => secureLink(origin, room.id, room.capabilities[role], secret),
    async fetch(url, options) {
      state.calls.push({ url: String(url), options: { ...options, signal: undefined } });
      const body = JSON.parse(options.body), token = options.headers.Authorization.slice(7);
      if (body.op === "publish" && state.beforePublish) { const fn = state.beforePublish; state.beforePublish = undefined; await fn(); }
      try { return Response.json(secureAction(body, token)); }
      catch (error) { return Response.json({ error: error.message }, { status: error.status || 500 }); }
    },
    close() { secureAction({ op: "close" }, room.capabilities.owner); },
    join(role = "edit") { return secureAction({ op: "join" }, room.capabilities[role]); },
    state(token) { return secureAction({ op: "sync" }, token); },
    async document(token) {
      const reply = state.state(token), next = new Y.Doc();
      if (reply.snapshot) Y.applyUpdate(next, await decrypt(secret, reply.snapshot));
      for (const event of reply.events) Y.applyUpdate(next, await decrypt(secret, event.packet));
      return { doc: next, head: reply.head };
    },
    async publish(token, next, head) { return secureAction({ op: "publish", head, snapshot: await encrypt(secret, Y.encodeStateAsUpdate(next)) }, token); },
  };
  return state;
}
