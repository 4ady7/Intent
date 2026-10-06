import Foundation

enum PresetKind: String, Codable, Equatable {
    case study
    case deepWork
    case reading
    case coding
    case work
    case custom
}

struct FocusPreset: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: PresetKind
    var name: String
    var duration: TimeInterval
    var selection: PersistedSelection

    static let defaults: [FocusPreset] = [
        make(.study, "Study", 60 * 60),
        make(.deepWork, "Deep Work", 45 * 60),
        make(.reading, "Reading", 25 * 60),
        make(.coding, "Coding", 90 * 60),
        make(.work, "Work", 60 * 60),
        make(.custom, "Custom", 25 * 60)
    ]

    private static func make(_ kind: PresetKind, _ name: String, _ duration: TimeInterval) -> FocusPreset {
        FocusPreset(
            id: StableID.uuid(kind.rawValue),
            kind: kind,
            name: name,
            duration: duration,
            selection: PersistedSelection()
        )
    }
}

enum StableID {
    private static let identifiers: [String: String] = [
        PresetKind.study.rawValue: "A1000000-0000-4000-8000-000000000001",
        PresetKind.deepWork.rawValue: "A1000000-0000-4000-8000-000000000002",
        PresetKind.reading.rawValue: "A1000000-0000-4000-8000-000000000003",
        PresetKind.coding.rawValue: "A1000000-0000-4000-8000-000000000004",
        PresetKind.work.rawValue: "A1000000-0000-4000-8000-000000000005",
        PresetKind.custom.rawValue: "A1000000-0000-4000-8000-000000000006"
    ]

    static func uuid(_ key: String) -> UUID {
        let value = identifiers[key].flatMap(UUID.init(uuidString:))
        if let value {
            return value
        }
        preconditionFailure("Missing preset identifier for \(key)")
    }
}
