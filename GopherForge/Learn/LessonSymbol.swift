import Foundation

/// A symbol per lesson, chosen by what the lesson is about.
///
/// It used to be chosen by whether the lesson needed the compiler, which is two
/// symbols for forty-nine lessons — and since most lessons are compile lessons,
/// a unit was a column of identical hammers. A symbol that is the same on every
/// row is not a symbol, it is decoration, and it costs the one thing an icon is
/// there for: telling two rows apart at a glance.
///
/// The concept tag is the right key because it is the vocabulary the whole
/// product already shares with the compiler and the review queue, so a lesson
/// about closing channels looks the same wherever it appears.
enum LessonSymbol {
    private static let environmentSymbols: [String: String] = [
        "modules.identity-versions": "shippingbox",
        "modules.version-graph": "arrow.triangle.branch",
        "modules.checksums-private": "checkmark.shield",
        "modules.workspace-replace": "square.stack.3d.up",
        "modules.vendor-embed": "doc.zipper",
        "modules.parallel-tests": "checkmark.seal",
        "modules.benchmark-load": "gauge.with.dots.needle.50percent",
        "modules.profiles-contention": "waveform.path.ecg",
        "modules.build-capacity": "cpu",
        "modules.tools-toolchain": "wrench.and.screwdriver",
        "modules.fuzz-vulnerability": "ladybug",
        "modules.startup-ownership": "power",
        "datastores.mongo-client": "externaldrive",
        "datastores.mongo-indexes": "magnifyingglass",
        "datastores.mongo-atomic": "checkmark.shield",
        "datastores.mongo-transactions": "arrow.triangle.2.circlepath",
        "datastores.mongo-cursors": "list.bullet",
        "datastores.mongo-load": "gauge.with.dots.needle.50percent",
        "datastores.redis-client": "externaldrive",
        "datastores.redis-cache": "clock",
        "datastores.redis-pipeline": "square.stack.3d.up",
        "datastores.redis-coordination": "lock",
        "datastores.redis-streams": "tray.full",
        "datastores.redis-load": "waveform.path.ecg",
    ]

    static func symbol(for lesson: Lesson) -> String {
        if let symbol = byLesson[lesson.id] { return symbol }
        for tag in lesson.conceptTags {
            if let symbol = byConcept[tag] { return symbol }
        }
        // Nothing recognised: fall back to the shape of the task, which at
        // least separates reading from building.
        return lesson.requiresCompiler ? "hammer" : "text.book.closed"
    }

    // Several design lessons share a review concept; their path icons still
    // identify the actual design instead of repeating the group icon.
    private static let byLesson: [String: String] = [
        "operations.docker-build": "shippingbox",
        "operations.docker-run": "play",
        "operations.docker-compose": "square.stack.3d.up",
        "operations.docker-volumes": "magnifyingglass",
        "operations.podman-runtime": "terminal",
        "operations.container-registry": "arrow.up.doc",
        "operations.kubernetes-contexts": "globe",
        "operations.kubernetes-workloads": "square.stack.3d.up",
        "operations.kubernetes-inspect": "magnifyingglass",
        "operations.kubernetes-network": "network",
        "operations.kubernetes-config": "slider.horizontal.3",
        "operations.probes-and-shutdown": "heart",
        "operations.kubernetes-apply": "gauge.with.dots.needle.50percent",
        "operations.kubernetes-rollout": "clock.arrow.circlepath",
        "architecture.simple-monolith": "app",
        "architecture.layered": "square.stack.3d.up",
        "architecture.modular-monolith": "shippingbox",
        "architecture.clean-onion": "circle.circle",
        "architecture.vertical-slice": "rectangle.split.3x1",
        "architecture.ddd": "cube",
        "architecture.cqrs": "arrow.left.arrow.right",
        "architecture.event-sourcing": "clock.arrow.circlepath",
        "architecture.event-driven": "bell",
        "architecture.microservices": "network",
        "architecture.soa": "point.3.connected.trianglepath.dotted",
        "architecture.bff": "iphone",
        "architecture.serverless": "bolt",
        "architecture.pipes-filters": "line.3.horizontal.decrease",
        "architecture.microkernel": "puzzlepiece",
        "architecture.web-queue-worker": "tray.2",
        "clean.names": "textformat",
        "clean.interfaces": "puzzlepiece",
        "clean.errors": "exclamationmark.triangle",
        "clean.ownership": "lock.shield",
        "clean.configuration": "slider.horizontal.3",
        "clean.table-tests": "checkmark.seal",
        "clean.refactoring": "arrow.triangle.2.circlepath",
        "clean.solid": "square.stack.3d.up",
        "patterns.factory-method": "cube.box",
        "patterns.abstract-factory": "square.grid.2x2",
        "patterns.builder": "hammer",
        "patterns.prototype": "doc.on.doc",
        "patterns.singleton": "1.circle",
        "patterns.adapter": "arrow.2.squarepath",
        "patterns.bridge": "link",
        "patterns.composite": "folder",
        "patterns.decorator": "square.stack",
        "patterns.facade": "app",
        "patterns.flyweight": "leaf",
        "patterns.proxy": "hand.raised",
        "patterns.strategy": "function",
        "patterns.command": "play",
        "patterns.chain": "link",
        "patterns.iterator": "repeat",
        "patterns.mediator": "person.3",
        "patterns.memento": "clock.arrow.circlepath",
        "patterns.observer": "eye",
        "patterns.state": "arrow.triangle.branch",
        "patterns.template-method": "doc.text",
        "patterns.visitor": "figure.walk",
        "patterns.interpreter": "curlybraces",
        "patterns.worker-pool": "person.3",
        "patterns.fan-in": "arrow.triangle.merge",
        "patterns.cancellation": "nosign",
        "patterns.actor-owner": "person.crop.circle",
        "patterns.retry": "arrow.clockwise",
        "patterns.circuit-breaker": "bolt.slash",
    ]

    /// One symbol per concept the course teaches.
    static let byConcept: [String: String] = [
        GoConcept.runtimeGC: "arrow.triangle.2.circlepath",
        GoConcept.runtimeAllocation: "memorychip",
        GoConcept.runtimeScheduler: "cpu",
        GoConcept.runtimeProfiling: "waveform.path.ecg",
        GoConcept.serviceCapacity: "gauge.with.dots.needle.50percent",
        GoConcept.serviceRedis: "externaldrive",
        GoConcept.serviceGin: "network",
        GoConcept.architectureBoundaries: "square.stack.3d.up",
        GoConcept.architectureDesign: "square.grid.3x3",
        GoConcept.toolingGit: "arrow.triangle.branch",
        GoConcept.toolingGo: "wrench.and.screwdriver",
        GoConcept.toolingNetworking: "network",
        GoConcept.toolingLinux: "server.rack",
        GoConcept.toolingBash: "terminal",
        GoConcept.toolingContainers: "shippingbox",
        GoConcept.toolingKubernetes: "point.3.connected.trianglepath.dotted",
        GoConcept.varsUnused: "trash",
        GoConcept.shortDeclaration: "equal.square",
        GoConcept.unusedImport: "shippingbox",
        GoConcept.undefinedSymbol: "questionmark.circle",
        GoConcept.importPath: "arrow.triangle.branch",
        GoConcept.missingReturn: "arrow.uturn.left",
        GoConcept.typeAssignment: "arrow.left.arrow.right",

        GoConcept.sliceCapacity: "ruler",
        GoConcept.sliceBounds: "arrow.left.and.right.square",
        GoConcept.sliceAliasing: "link",
        GoConcept.mapZeroValue: "square.grid.3x3",
        GoConcept.mapOrder: "shuffle",
        GoConcept.stringRunes: "textformat",
        GoConcept.stringsBuilder: "text.alignleft",

        GoConcept.methodSet: "function",
        GoConcept.nilInterface: "circle.slash",
        GoConcept.smallInterface: "puzzlepiece",
        GoConcept.typeAssertion: "questionmark.diamond",
        GoConcept.embedding: "square.stack.3d.down.right",

        GoConcept.explicitErrorCheck: "exclamationmark.triangle",
        GoConcept.errorWrapping: "shippingbox.and.arrow.backward",
        GoConcept.errorSentinel: "flag",
        GoConcept.deferCleanup: "clock.arrow.circlepath",
        GoConcept.customError: "exclamationmark.bubble",
        GoConcept.panicIsNotAnError: "bolt.trianglebadge.exclamationmark",

        GoConcept.packageInit: "power",

        GoConcept.deadlock: "lock",
        GoConcept.channelClose: "xmark.circle",
        GoConcept.channelDirection: "arrow.right.circle",
        GoConcept.selectBranch: "arrow.triangle.pull",
        GoConcept.contextCancel: "nosign",
        GoConcept.contextFirstParameter: "list.number",
        GoConcept.goroutineLeak: "drop",
        GoConcept.waitGroup: "person.3",
        GoConcept.mutex: "lock.shield",

        GoConcept.constants: "number",
        GoConcept.switchNoFallthrough: "arrow.triangle.swap",
        GoConcept.conversion: "arrow.2.squarepath",

        GoConcept.structLiteral: "cube",
        GoConcept.pointerReceiver: "arrow.up.forward.square",
        GoConcept.closure: "curlybraces.square",

        GoConcept.typeParameter: "chevron.left.forwardslash.chevron.right",
        GoConcept.rangeOverFunc: "arrow.trianglehead.clockwise",
        GoConcept.genericMethod: "point.forward.to.point.capsulepath",
        GoConcept.constraint: "line.3.horizontal.decrease",
        GoConcept.genericsOveruse: "exclamationmark.questionmark",

        GoConcept.stdlibTime: "clock",
        GoConcept.stdlibSort: "arrow.up.arrow.down",
        GoConcept.stdlibIO: "arrow.left.arrow.right.circle",
        GoConcept.stdlibJSON: "doc.text",
        GoConcept.stdlibTesting: "checkmark.seal",
        GoConcept.stdlibHTTP: "network",
        GoConcept.stdlibImage: "photo",
        GoConcept.stdlibStrconv: "textformat.123",

        GoConcept.namedResults: "return",
        GoConcept.makeVsNew: "plus.square.on.square",
        GoConcept.arrays: "rectangle.split.3x1",
        GoConcept.mapCommaOK: "checkmark.circle",
        GoConcept.stringer: "text.quote",
        GoConcept.emptyInterface: "circle.dashed",
        GoConcept.bufferedChannel: "tray.2",
        GoConcept.rangeOverChannel: "arrow.forward.to.line",
        GoConcept.selectDefault: "arrow.uturn.forward",
        GoConcept.syncOnce: "1.circle",
        GoConcept.functionValue: "function",
    ].merging(byLesson) { original, _ in original }
        .merging(environmentSymbols) { original, _ in original }
}
