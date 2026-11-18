// Editorial directions group existing units; they do not introduce prerequisites
// or change the native course's order, lesson IDs or completion contracts.
export const directions = [
  {
    id: "foundations",
    title: "Go foundations",
    description:
      "From values and control flow to types, interfaces and packages.",
    units: [
      "core",
      "structs",
      "collections",
      "interfaces",
      "generics",
      "errors",
      "modules",
    ],
  },
  {
    id: "systems",
    title: "Concurrency & services",
    description:
      "Coordinate work, understand the runtime, and build useful services.",
    units: ["concurrency", "stdlib", "runtime", "services"],
  },
  {
    id: "design",
    title: "Architecture & clean code",
    description:
      "Choose boundaries deliberately. Keep the implementation clear.",
    units: [
      "architecture",
      "clean-code",
      "system-design",
      "clean-code-production",
    ],
  },
  {
    id: "patterns",
    title: "Design patterns",
    description:
      "Creation, composition, behavior and the patterns that fit concurrent Go.",
    units: [
      "patterns-creational",
      "patterns-structural",
      "patterns-behavioral",
      "patterns-go",
    ],
  },
  {
    id: "tooling",
    title: "Around Go",
    description:
      "The command line, containers, DevOps, databases and coding agents. Real commands, bounded services and evidence-driven Go workflows.",
    units: [
      "operations",
      "containers",
      "kubernetes",
      "devops",
      "datastores",
      "sql",
      "ai",
    ],
  },
  // Dedicated courses (see /courses). Each is also its own app download.
  {
    id: "gin",
    title: "Gin web services",
    description:
      "A Gin tutorial from the first route to a tested REST API: binding, validation, middleware, auth, rate limits and streaming.",
    units: ["gin-foundations", "gin", "gin-project", "gin-data", "gin-edge"],
  },
  {
    id: "blockchain",
    title: "Blockchain",
    description:
      "Hashes, Merkle proofs, signatures and RLP, then Ethereum RPC, fees, transactions, events and key custody.",
    units: ["blockchain-foundations", "blockchain"],
  },
  {
    id: "security",
    title: "Security",
    description:
      "Authorization, injection, XSS, CSRF, sessions, secrets, encryption, tokens, fuzzing and supply chain.",
    units: ["security", "security-web", "security-operations"],
  },
  {
    id: "gamedev",
    title: "Game development",
    description:
      "Game loops, Ebitengine structure, input, physics, collisions, pathfinding, procedural worlds and multiplayer.",
    units: ["gamedev-loop", "gamedev-systems"],
  },
] as const;
