import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A project, turned into a gzipped tar only when something actually asks for
/// one.
///
/// The archive used to be built inside a SwiftUI `body`: opening the Projects
/// screen tarred the whole project, gzipped it and wrote it to the temporary
/// directory, and it did that again on every recomputation. SwiftUI recomputes
/// a body whenever anything it reads changes, and since every keystroke now
/// reaches the project, that is constantly — for a file nobody had asked to
/// share yet.
///
/// `Transferable` is the right shape for this: the work happens when the share
/// sheet asks for a file, which is the only moment it is needed.
struct ProjectExport: Transferable {
    let project: GopherForgeProject

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .gzip) { export in
            SentTransferredFile(try export.writeArchive())
        }
        .suggestedFileName { export in
            ProjectArchiveNaming.archiveName(for: export.project.name)
        }
    }

    func writeArchive() throws -> URL {
        let name = ProjectArchiveNaming.archiveName(for: project.name)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let root = ProjectArchiveNaming.rootDirectory(for: project.name)
        let data = try ProjectArchive.gzip(ProjectArchive.tar(files: project.files, root: root))
        try data.write(to: url, options: .atomic)
        return url
    }
}
