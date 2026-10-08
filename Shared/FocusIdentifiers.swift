import Foundation

enum FocusIdentifiers {
    /// Used when the Info.plist value has not been substituted. Keep it identical to Config/Shared.xcconfig.
    static let fallbackAppGroup = "group.com.shady.Focus"
    static let settingsStoreName = "focus"
    static let activityPrefix = "focus.session."
    static let completionNotificationID = "focus.session.complete"
    static let schemaVersion = 1

    static var appGroup: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "FocusAppGroupIdentifier") as? String else {
            return fallbackAppGroup
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else {
            return fallbackAppGroup
        }
        return trimmed
    }

    static func activityName(for sessionID: UUID) -> String {
        activityPrefix + sessionID.uuidString
    }

    static func sessionID(fromActivityName name: String) -> UUID? {
        guard name.hasPrefix(activityPrefix) else { return nil }
        return UUID(uuidString: String(name.dropFirst(activityPrefix.count)))
    }
}

enum FocusFiles {
    static let active = "active-session.json"
    static let history = "history.json"
    static let presets = "presets.json"
    static let preferences = "preferences.json"
    static let summary = "pending-summary.json"
    static let interruptions = "interruptions.json"
    static let monitorCursor = "monitor-cursor.json"
}
