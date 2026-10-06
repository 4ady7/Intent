import Foundation

enum FocusFileIO {
    static func read<T: Decodable>(_ type: T.Type, name: String, in directory: URL) throws -> T? {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DecodedVersion<T>.self, from: data).value
    }

    static func write<T: Encodable>(_ value: T, name: String, in directory: URL) throws {
        let url = directory.appendingPathComponent(name)
        let data = try JSONEncoder().encode(EncodedVersion(schemaVersion: FocusIdentifiers.schemaVersion, value: value))
        try data.write(to: url, options: Data.WritingOptions.atomic)
    }

    static func remove(name: String, in directory: URL) throws {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    static func quarantine(name: String, in directory: URL) {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let destination = directory.appendingPathComponent("\(name).corrupt-\(Int(Date().timeIntervalSince1970))")
        try? FileManager.default.moveItem(at: url, to: destination)
    }
}

private struct EncodedVersion<Value: Encodable>: Encodable {
    var schemaVersion: Int
    var value: Value
}

private struct DecodedVersion<Value: Decodable>: Decodable {
    var schemaVersion: Int
    var value: Value

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == FocusIdentifiers.schemaVersion else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported schema"))
        }
        value = try container.decode(Value.self, forKey: .value)
    }
}
