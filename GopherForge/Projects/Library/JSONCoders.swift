import Foundation

/// One date strategy for everything the app persists, so a document written by
/// one component always reads back in another.
extension JSONEncoder {
    static var gopherForge: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }
}

extension JSONDecoder {
    static var gopherForge: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
