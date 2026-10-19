import Foundation

/// The course, assembled from one file per unit.
///
/// The audience is not someone's first language. Go's own 2025 developer
/// survey found most people learn Go after starting their career, and that
/// applying idioms is a top reported friction, so every unit is written for a
/// programmer translating habits rather than meeting variables for the first
/// time.
enum GoCourseCatalog {
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
        ReadingLessonCatalog.unit("architecture", title: "Architecture and clean code",
            summary: "Package boundaries, ports and adapters, and choosing a useful architectural style.",
            note: "Start from one request and one reason to change. Architecture is a set of tradeoffs, not a required folder template."),
        ReadingLessonCatalog.unit("operations", title: "Around Go: command line",
            summary: "Bash, Git, Go tools, HTTP debugging and Linux service commands.",
            note: "Read commands and manifests here; use your own development environment to run them. These tools are useful deployment options, not prerequisites for every Go program."),
        ReadingLessonCatalog.unit("containers", title: "Around Go: containers",
            summary: "Build, run, inspect and publish with Docker, Compose and Podman.",
            note: "Use your own development machine for these command examples. Each lesson distinguishes images, instances, networking and stored data."),
        ReadingLessonCatalog.unit("kubernetes", title: "Around Go: Kubernetes",
            summary: "Contexts, deployments, logs, services, configuration, probes and rollbacks.",
            note: "Start with the context lesson and a disposable development cluster. Examples keep cluster and namespace explicit; replace placeholder names and images before use."),
    ]

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
        let ordered = units.flatMap(\.teachingLessons)
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
