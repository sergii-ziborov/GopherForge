import Foundation

/// Whole small programs rather than one-idea snippets.
///
/// These have more than one package, which is the point: a project teaches how
/// Go is laid out, and a single file cannot teach that however good it is. Each
/// one lives in its own file because the content is long and this project keeps
/// files short.
enum GoExampleLibraryProjects {
    static let all: [GoExample] = [
        GoExampleProjectWordCount.wordCount,
        GoExampleProjectLedger.ledger,
        GoExampleProjectPipeline.pipeline,
        GoExampleProjectPlot.plot,
    ]
}
