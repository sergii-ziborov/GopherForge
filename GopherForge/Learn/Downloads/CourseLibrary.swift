import CryptoKit
import Foundation

/// Only complete, validated documents enter the catalog. Removing content never
/// touches attempts, bookmarks, lesson drafts or the user's projects.
final class CourseLibrary: @unchecked Sendable {
    static let maximumPackageBytes = 8 * 1024 * 1024
    static let shared = CourseLibrary()
    let catalog: [CourseDownload]
    private let directory: URL
    private let lock = NSLock()
    private var installed: [String: CoursePackage] = [:]
    private var installedDescriptors: [String: CourseDownload] = [:]
    private struct InstalledCourse: Codable {
        let descriptor: CourseDownload
        let document: Data
    }

    var packages: [CoursePackage] {
        lock.withLock { catalog.compactMap { installed[$0.id] } }
    }
    var knownLessonIDs: Set<String> { Set(catalog.flatMap(\.lessonIDs)) }
    var knownInterviewIDs: Set<String> { Set(catalog.flatMap { $0.interviewIDs ?? [] }) }

    init(directory: URL? = nil, catalog: [CourseDownload]? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "GopherForge/Courses", directoryHint: .isDirectory)
        self.catalog = (catalog ?? Self.bundledCatalog()).filter(Self.safeDescriptor)
        for descriptor in self.catalog {
            // A newer catalog never silently removes or replaces an installed
            // offline revision. This private receipt was validated at install.
            if let bytes = try? Self.readBounded(self.directory.appending(path: descriptor.id + ".installed.json"), limit: 16 * 1024 * 1024),
               let saved = try? JSONDecoder().decode(InstalledCourse.self, from: bytes),
               saved.descriptor.id == descriptor.id,
               let package = try? Self.validate(saved.document, against: saved.descriptor) {
                installed[descriptor.id] = package
                installedDescriptors[descriptor.id] = saved.descriptor
            }
        }
        #if COURSE_FIXTURES
        // QA fixtures are absent from Release. Production never seeds or fetches.
        if directory == nil, !ProcessInfo.processInfo.arguments.contains("-GopherForgeEmptyCourses"),
           NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || ProcessInfo.processInfo.arguments.contains("-GopherForgeCourseFixtures") {
            for descriptor in self.catalog where installedDescriptors[descriptor.id]?.sha256 != descriptor.sha256 {
                if let url = Bundle.main.url(forResource: descriptor.fileName, withExtension: nil, subdirectory: "CourseFixtures"),
                   let data = try? Self.readBounded(url), let package = try? Self.validate(data, against: descriptor) {
                    installed[descriptor.id] = package
                    installedDescriptors[descriptor.id] = descriptor
                    try? install(data, descriptor: descriptor)
                }
            }
        }
        #endif
    }

    private static func bundledCatalog() -> [CourseDownload] {
        guard let url = Bundle.main.url(forResource: "CourseDownloads", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode([CourseDownload].self, from: data) else { return [] }
        return result
    }

    private static func safeDescriptor(_ item: CourseDownload) -> Bool {
        func identifier(_ value: String) -> Bool {
            !value.isEmpty && value.utf8.count <= 80 && value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == ".") }
        }
        return identifier(item.id) && identifier(item.revision)
            && item.fileName == "\(item.id)-\(item.revision).gfcourse.json"
            && item.byteCount > 0 && item.byteCount <= maximumPackageBytes
            && item.sha256.count == 64 && item.sha256.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    static func readBounded(_ url: URL, limit: Int = maximumPackageBytes) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= limit else {
            throw CourseContentError.invalid("The course file is invalid or exceeds 8 MiB.")
        }
        return try Data(contentsOf: url)
    }

    static func validate(_ data: Data, against descriptor: CourseDownload) throws -> CoursePackage {
        guard safeDescriptor(descriptor), data.count <= maximumPackageBytes, data.count == descriptor.byteCount,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == descriptor.sha256 else {
            throw CourseContentError.invalid("The complete course did not match its published checksum. The previous download is unchanged.")
        }
        let package = try JSONDecoder().decode(CoursePackage.self, from: data)
        let lessons = package.units.flatMap(\.lessons)
        let ids = lessons.map(\.id)
        guard package.schemaVersion == 1, package.id == descriptor.id, package.revision == descriptor.revision,
              ids == descriptor.lessonIDs, Set(ids).count == ids.count,
              Set(package.units.map(\.id)).count == package.units.count,
              package.units.count == descriptor.unitCount,
              lessons.filter({ !$0.isChallenge }).count == descriptor.teachingCount,
              lessons.filter(\.isChallenge).count == descriptor.challengeCount,
              (package.interview?.questions.count ?? 0) == descriptor.interviewCount,
              descriptor.interviewIDs.map({ $0 == (package.interview?.questions.map(\.id) ?? []) }) ?? true,
              package.labs.count == descriptor.labCount,
              Set(package.labs.map(\.id)).count == package.labs.count,
              Set(package.readings.map(\.id)) == Set(lessons.filter(\.isReading).map(\.id)),
              lessons.filter(\.requiresCompiler).allSatisfy({ package.solutions[$0.id] != nil }) else {
            throw CourseContentError.invalid("This course is incomplete or requires another app version.")
        }
        return package
    }

    func isInstalled(_ id: String) -> Bool { lock.withLock { installed[id] != nil } }
    func installedRevision(_ id: String) -> String? { lock.withLock { installedDescriptors[id]?.revision } }

    func install(_ data: Data, descriptor: CourseDownload) throws {
        guard catalog.contains(where: { $0.id == descriptor.id && $0.sha256 == descriptor.sha256 && $0.fileName == descriptor.fileName }) else {
            throw CourseContentError.invalid("This course is not in the app's catalog.")
        }
        let package = try Self.validate(data, against: descriptor)
        try lock.withLock {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var location = directory
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try location.setResourceValues(values)
            let saved = InstalledCourse(descriptor: descriptor, document: data)
            try JSONEncoder().encode(saved).write(to: directory.appending(path: descriptor.id + ".installed.json"), options: .atomic)
            installed[descriptor.id] = package
            installedDescriptors[descriptor.id] = descriptor
        }
    }

    func remove(_ descriptor: CourseDownload) throws {
        guard catalog.contains(where: { $0.id == descriptor.id && $0.fileName == descriptor.fileName }) else { throw CourseContentError.invalid("Unknown course.") }
        try lock.withLock {
            let url = directory.appending(path: descriptor.id + ".installed.json")
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            installed[descriptor.id] = nil
            installedDescriptors[descriptor.id] = nil
        }
    }

    func export(_ descriptor: CourseDownload) throws -> URL {
        guard catalog.contains(where: { $0.id == descriptor.id && $0.fileName == descriptor.fileName }) else { throw CourseContentError.invalid("Unknown course.") }
        guard isInstalled(descriptor.id) else { throw CourseContentError.invalid("Download this course first.") }
        let source = directory.appending(path: descriptor.id + ".installed.json")
        let saved = try JSONDecoder().decode(InstalledCourse.self, from: Self.readBounded(source, limit: 16 * 1024 * 1024))
        guard saved.descriptor.id == descriptor.id else { throw CourseContentError.invalid("The saved course identity is invalid.") }
        _ = try Self.validate(saved.document, against: saved.descriptor)
        let folder = FileManager.default.temporaryDirectory.appending(path: "CourseExports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appending(path: saved.descriptor.fileName)
        try saved.document.write(to: target, options: .atomic)
        return target
    }
}

enum LessonSolutionCatalog {
    static func solution(for lessonID: String) -> String? {
        CourseLibrary.shared.packages.lazy.compactMap { $0.solutions[lessonID] }.first
    }
    static var coveredLessonIDs: Set<String> { Set(CourseLibrary.shared.packages.flatMap { $0.solutions.keys }) }
}

enum LessonHintCatalog {
    static var allAuthored: [String: LessonHint] {
        Dictionary(uniqueKeysWithValues: CourseLibrary.shared.packages.flatMap(\.hints).map { ($0.id, $0) })
    }
    static var authoredIDs: Set<String> { Set(allAuthored.keys) }
    static func hint(for lesson: Lesson) -> LessonHint {
        allAuthored[lesson.id] ?? synthesized(from: lesson)
    }
    static func synthesized(from lesson: Lesson) -> LessonHint {
        LessonHint(lessonID: lesson.id, hint: "Edit the code until the check on this page agrees.", nuance: String(lesson.explanation.prefix(160)))
    }
    static func realizeSource(for lesson: Lesson) -> String? { lesson.verifiedSolution }
}
