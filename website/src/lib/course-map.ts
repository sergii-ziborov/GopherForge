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
    units: ["architecture", "clean-code"],
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
      "The command line, containers and Kubernetes. Real commands, one layer at a time.",
    units: ["operations", "containers", "kubernetes"],
  },
] as const;
