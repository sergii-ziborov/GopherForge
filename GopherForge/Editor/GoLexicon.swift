import Foundation

/// Go's fixed vocabulary.
///
/// The keyword list is the complete one from the language specification — all
/// twenty-five — because a highlighter that knows most of them looks broken on
/// exactly the words a learner is least sure about.
enum GoLexicon {
    static let keywords: Set<String> = [
        "break", "case", "chan", "const", "continue", "default", "defer", "else",
        "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
        "map", "package", "range", "return", "select", "struct", "switch", "type", "var",
    ]

    /// Predeclared types, constants and functions. These are identifiers rather
    /// than keywords — they can legally be shadowed — but reading them as
    /// built-ins is what a Go programmer's eye does.
    static let predeclared: Set<String> = [
        "any", "bool", "byte", "comparable", "complex64", "complex128", "error",
        "float32", "float64", "int", "int8", "int16", "int32", "int64", "rune",
        "string", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr",
        "true", "false", "iota", "nil",
        "append", "cap", "clear", "close", "complex", "copy", "delete", "imag",
        "len", "make", "max", "min", "new", "panic", "print", "println", "real", "recover",
    ]

    /// Standard-library packages the course and templates use. Highlighting the
    /// package qualifier makes import-heavy code easier to scan.
    static let commonPackages: Set<String> = [
        "bufio", "bytes", "context", "encoding", "errors", "flag", "fmt", "io",
        "json", "log", "math", "net", "os", "path", "regexp", "sort", "strconv",
        "strings", "sync", "testing", "text", "time", "unicode",
    ]

    static func isIdentifierStart(_ character: Character) -> Bool {
        character.isLetter || character == "_"
    }

    static func isIdentifierBody(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
