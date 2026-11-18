import Foundation

/// The course, assembled from one file per unit.
///
/// The audience is not someone's first language. Go's own 2025 developer
/// survey found most people learn Go after starting their career, and that
/// applying idioms is a top reported friction, so every unit is written for a
/// programmer translating habits rather than meeting variables for the first
/// time.
enum GoCourseCatalog {
    #if LESSON_CATALOG_EXPORT
    private static let originalUnits: [CourseUnit] = [
        CourseUnitCore.unit,
        // Types you declare come straight after the basics: everything below
        // this line is written in terms of them.
        CourseUnitStructs.unit,
        CourseUnitCollections.unit,
        CourseUnitInterfaces.unit,
        // After interfaces on purpose — a constraint is an interface, so the
        // unit has something to build on rather than a new idea to introduce.
        CourseUnitGenerics.unit,
        CourseUnitErrors.unit,
        CourseUnitModules.unit,
        CourseUnitConcurrency.unit,
        CourseUnitStandardLibrary.unit,
    ]

    static let units: [CourseUnit] = originalUnits.map(ReadingLessonCatalog.expanding) + [
        ReadingLessonCatalog.unit("runtime", title: "Runtime and memory",
            summary: "Stacks, GC, goroutines, threads and diagnostic evidence.",
            note: "Read worked examples without compiling. Native service behavior can differ from the app's WebAssembly execution environment."),
        ReadingLessonCatalog.unit("services", title: "Go services",
            summary: "HTTP, Gin, Redis and the capacity of downstream services.",
            note: "These reading lessons explain native service designs. They do not add guest network sockets or remote services to the iOS sandbox."),
        ReadingLessonCatalog.unit("architecture", title: "Go architectures",
            summary: "Compare monoliths, layers, hexagonal and clean designs, DDD, CQRS, events and distributed services.",
            note: "Ratings are editorial fit for a task, not performance measurements. Styles overlap: compare boundaries, consistency and operational cost."),
        ReadingLessonCatalog.unit("clean-code", title: "Clean code in Go",
            summary: "Names, interfaces, errors, ownership, tests and safe refactoring.",
            note: "Prefer clear concrete code until a real boundary needs abstraction. Follow the worked examples and explain why each change helps."),
        ReadingLessonCatalog.unit("system-design", title: "Architecture: consistency and evolution",
            summary: "Transactions, outbox/inbox, sagas, compatible changes, tenant isolation and observability.",
            note: "Work through ownership, durable state and failure recovery. Models distinguish in-memory behavior from the native infrastructure required in production."),
        ReadingLessonCatalog.unit("clean-code-production", title: "Clean code: production contracts",
            summary: "Composition roots, context ownership, package APIs and exact time/money contracts.",
            note: "Readable Go also needs explicit lifetime, units and failure contracts. These worked examples complement the foundational clean-code unit."),
        ReadingLessonCatalog.unit("patterns-creational", title: "Patterns: creation",
            summary: "Factory Method, Abstract Factory, Builder, Prototype and Singleton.",
            note: "Classic intent, Go implementation: constructors, function values and composition instead of inheritance."),
        ReadingLessonCatalog.unit("patterns-structural", title: "Patterns: composition",
            summary: "Adapter, Bridge, Composite, Decorator, Facade, Flyweight and Proxy.",
            note: "Follow data ownership and delegated calls. Wrappers should preserve the contracts their callers depend on."),
        ReadingLessonCatalog.unit("patterns-behavioral", title: "Patterns: behavior",
            summary: "Eleven classic patterns, from Strategy and Command to State, Visitor and Interpreter.",
            note: "Introduce machinery only when the variation exists. Each lesson includes a simpler alternative and the cost of the pattern."),
        ReadingLessonCatalog.unit("patterns-go", title: "Patterns: concurrent Go",
            summary: "Worker pools, fan-in, cancellation, ownership, retries and circuit breakers.",
            note: "Every goroutine needs an owner and an exit path. Production systems also need budgets, observability and failure tests."),
        ReadingLessonCatalog.unit("operations", title: "Around Go: command line",
            summary: "Bash, Git, Go tools, HTTP debugging and Linux service commands.",
            note: "Read commands and manifests here; use your own development environment to run them. These tools are useful deployment options, not prerequisites for every Go program."),
        ReadingLessonCatalog.unit("containers", title: "Around Go: containers",
            summary: "Build, run, inspect and publish with Docker, Compose and Podman.",
            note: "Use your own development machine for these command examples. Each lesson distinguishes images, instances, networking and stored data."),
        ReadingLessonCatalog.unit("kubernetes", title: "Around Go: Kubernetes",
            summary: "Contexts, deployments, logs, services, configuration, probes and rollbacks.",
            note: "Start with the context lesson and a disposable development cluster. Examples keep cluster and namespace explicit; replace placeholder names and images before use."),
        ReadingLessonCatalog.unit("devops", title: "Around Go: DevOps and reliability",
            summary: "Operational CLIs, reconciliation, verified delivery, SLOs, incidents and data-safe recovery.",
            note: "Begin with command line, containers and Kubernetes. Go models run locally; real infrastructure, process and monitoring exercises need your own disposable native environment."),
        ReadingLessonCatalog.unit("datastores", title: "Around Go: MongoDB and Redis",
            summary: "Clients, queries, atomic writes, caching, streams and behavior under load.",
            note: "Read worked native-service examples here. Run them against an isolated development database on your own machine; these lessons do not add network sockets to the app sandbox."),
        ReadingLessonCatalog.unit("sql", title: "Around Go: SQL services",
            summary: "Shared pools, rows, transactions, isolation, deadlocks and retry-safe commands.",
            note: "Worked native Go and PostgreSQL examples. Use an isolated database in your own development environment; the app does not open database sockets."),
        // The Gin, blockchain, security and game-development units are
        // published as dedicated courses; see CourseMembership.
        ReadingLessonCatalog.unit("gin-foundations", title: "Gin foundations",
            summary: "Engines, routes, parameters, groups, binding sources, validators, JSON, uploads, templates and 404/405 handling.",
            note: "Every example runs against upstream Gin v1.12 through httptest in your native development environment. The app's teaching adapter does not promise every Gin API or network-server capability."),
        ReadingLessonCatalog.unit("gin", title: "Gin in production",
            summary: "Middleware, bounded input, authentication, CORS, rate limits, logging, timeouts, streaming, health, caching and shutdown.",
            note: "Worked upstream Gin examples for your native development environment. The app's teaching adapter does not promise every Gin API or network-server capability."),
        ReadingLessonCatalog.unit("gin-project", title: "Gin project: a complete REST API",
            summary: "Layout, dependencies, CRUD, pagination, problem details, idempotency keys, optimistic concurrency, API tests and startup.",
            note: "One service grows lesson by lesson. The models run in memory; a deployment adds a database, TLS and observability in your own environment."),
        ReadingLessonCatalog.unit("gin-data", title: "Gin and your data",
            summary: "Request contexts, JSON Merge Patch, safe filters, batched includes, response caches, streaming import and export, async jobs and signed webhooks.",
            note: "Stores are in-memory models driven through httptest. Point the same handlers at your own isolated database in a native development environment."),
        ReadingLessonCatalog.unit("gin-edge", title: "Gin in the wider system",
            summary: "Upstream clients, retries and circuit breakers, compression, ranged downloads, content negotiation, versioning, contract tests, admin endpoints, release builds and rolling deploys.",
            note: "Upstreams, listeners and signals are modeled in-process. Real deployments, load balancers and clusters belong to your own environment."),
        ReadingLessonCatalog.unit("blockchain-foundations", title: "Blockchain foundations in Go",
            summary: "Hash chains, Merkle proofs, signatures, addresses, account and UTXO ledgers, RLP, proof of work and fork choice.",
            note: "Local models with reviewed Go libraries and fixed test keys. Nothing here creates a wallet, connects to a node or signs a real transaction."),
        ReadingLessonCatalog.unit("blockchain", title: "Blockchain infrastructure",
            summary: "Package roles, RPC, exact units, ABI, nonces, key custody, reorg-safe indexing, fees, raw transactions, receipts, message signing and providers.",
            note: "Developer preparation using local models, reviewed protocol libraries and test environments. This section does not add a wallet, node, signing service or guest networking to GopherForge."),
        ReadingLessonCatalog.unit("security", title: "Service security foundations",
            summary: "Authentication and authorization, cryptographic purposes, controlled egress and TLS peer identity.",
            note: "Apply these patterns in your own native services with an explicit threat model. These lessons do not introduce GopherForge accounts or registration."),
        ReadingLessonCatalog.unit("security-web", title: "Web application security",
            summary: "SQL injection, XSS, CSRF, session cookies, path traversal, command injection, open redirects and security headers.",
            note: "Each attack is shown against a local model and fixed with the standard library. Test only systems you own or are authorized to assess."),
        ReadingLessonCatalog.unit("security-operations", title: "Secrets, cryptography and supply chain",
            summary: "Redaction, constant-time checks, AEAD encryption, password storage, token design, fuzzing and dependency hygiene.",
            note: "Use reviewed standard and x/crypto primitives rather than inventing constructions. Production key storage and rotation need your own infrastructure."),
        ReadingLessonCatalog.unit("ai", title: "Around Go: coding agents",
            summary: "Use Codex, Claude Code and Cursor with concrete contracts, repository context and meaningful checks.",
            note: "Ordinary projects stay local. The separate development Playground adds explicit opt-in MCP sharing; read the guide for local execution and provider boundaries."),
        ReadingLessonCatalog.unit("gamedev-loop", title: "Game loop, input and physics",
            summary: "Fixed timesteps, Ebitengine structure, vectors, input actions, state machines, components, collisions and spatial hashing.",
            note: "Runnable models are engine-free and deterministic. Build windowed games with Ebitengine in your own native environment; GopherForge does not run a graphics engine."),
        ReadingLessonCatalog.unit("gamedev-systems", title: "Worlds, AI and multiplayer",
            summary: "Tilemaps and cameras, A* pathfinding, seeded generation, tweens, save files, authoritative servers, prediction and frame budgets.",
            note: "Headless simulations stand in for rendering and sockets. Real transports, assets and platform builds belong to your own native project."),
    ]

    #else
    static var units: [CourseUnit] { CourseLibrary.shared.packages.flatMap(\.units) }
    #endif

    static var lessons: [Lesson] {
        units.flatMap(\.lessons)
    }

    /// The lessons the course presents as steps, which is what every count on
    /// the Learn screen is counting.
    ///
    /// Separate from `lessons` because challenges are lessons too and live in
    /// Practice instead. Describing the course by `lessons.count` quotes a
    /// number nobody can see: the app says 44 while that total includes Practice.
    static var teachingLessons: [Lesson] {
        units.flatMap(\.teachingLessons)
    }

    /// The question-and-answer challenges, which Practice offers.
    static var challenges: [Lesson] {
        units.flatMap(\.challenges)
    }

    static func unit(id: String) -> CourseUnit? {
        units.first { $0.id == id }
    }

    static func lesson(id: String) -> Lesson? {
        lessons.first { $0.id == id }
    }

    /// The unit a lesson belongs to.
    static func unit(containing lessonID: String) -> CourseUnit? {
        units.first { unit in unit.lessons.contains { $0.id == lessonID } }
    }

    /// Where the lesson sits in its unit, counting only what the unit teaches.
    static func position(of lessonID: String) -> (index: Int, total: Int)? {
        guard let unit = unit(containing: lessonID) else { return nil }
        let teaching = unit.teachingLessons
        guard let index = teaching.firstIndex(where: { $0.id == lessonID }) else { return nil }
        return (index, teaching.count)
    }

    /// What to read next: the following lesson in this unit, or the first of
    /// the next unit once this one runs out.
    ///
    /// Challenges are not offered. They are questions with answers rather than
    /// something to build, they live in Practice, and ending a unit by dropping
    /// someone into one would be asking a question nobody walked them to.
    static func lesson(after lessonID: String) -> Lesson? {
        #if LESSON_CATALOG_EXPORT
        let ordered = units.flatMap(\.teachingLessons)
        #else
        let ordered = CourseLibrary.shared.packages.first { $0.units.contains { $0.lessons.contains { $0.id == lessonID } } }?.units.flatMap(\.teachingLessons) ?? []
        #endif
        guard let index = ordered.firstIndex(where: { $0.id == lessonID }),
              ordered.indices.contains(index + 1)
        else {
            return nil
        }
        return ordered[index + 1]
    }

    static func lessons(taggedWith conceptTag: String) -> [Lesson] {
        lessons.filter { $0.conceptTags.contains(conceptTag) }
    }

    /// Every tag the course teaches. Checked against `GoConcept.all` by the
    /// test suite so a lesson cannot introduce a tag the review scheduler and
    /// the compiler do not share.
    static var taughtConcepts: Set<String> {
        Set(lessons.flatMap(\.conceptTags))
    }
}
