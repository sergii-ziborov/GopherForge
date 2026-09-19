import Foundation

/// Files a program left behind in its one writable directory.
///
/// Interactive Go graphics cannot run in this app and never will: Ebiten and
/// Fyne need a window and a GPU, and WASI has neither. What does run — and runs
/// perfectly — is a program that draws into a buffer and encodes a PNG. So the
/// app looks in the sandbox afterwards and shows what was drawn, which turns
/// "no graphics" into "graphics you can actually reason about".
struct GoProgramArtifacts: Sendable, Equatable {
    struct Image: Sendable, Equatable, Identifiable {
        let name: String
        let data: Data
        var id: String { name }
    }

    let images: [Image]

    static let empty = GoProgramArtifacts(images: [])

    var isEmpty: Bool { images.isEmpty }

    /// Big enough for anything worth looking at on a phone, small enough that a
    /// runaway program cannot fill memory by writing one enormous file.
    static let maximumImageBytes = 8 * 1024 * 1024
    static let maximumImages = 6

    /// Collects images the program wrote, newest last, before the sandbox is
    /// removed. Extensions only — the bytes are handed to the image decoder,
    /// which is the thing that actually decides whether they are an image.
    static func collect(from sandbox: URL, fileManager: FileManager = .default) -> GoProgramArtifacts {
        let recognised = ["png", "jpg", "jpeg", "gif"]
        guard let names = try? fileManager.contentsOfDirectory(atPath: sandbox.path) else {
            return .empty
        }

        var images: [Image] = []
        for name in names.sorted() where recognised.contains((name as NSString).pathExtension.lowercased()) {
            guard images.count < maximumImages else { break }
            let url = sandbox.appendingPathComponent(name)
            guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= maximumImageBytes,
                  let data = try? Data(contentsOf: url)
            else {
                continue
            }
            images.append(Image(name: name, data: data))
        }
        return GoProgramArtifacts(images: images)
    }
}
