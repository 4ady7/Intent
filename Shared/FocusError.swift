import Foundation

enum FocusError: LocalizedError, Equatable {
    case nothingSelected
    case durationTooShort
    case durationTooLong
    case notAuthorized
    case authorizationUnavailable
    case restrictionsNotApplied
    case restrictionsNotCleared
    case scheduleFailed(String)
    case persistenceFailed
    case historyUnreadable
    case sessionAlreadyActive
    case noActiveSession
    case illegalTransition
    case appGroupUnavailable
    case couldNotRestoreSession

    var errorDescription: String? {
        switch self {
        case .nothingSelected:
            return "Choose at least one app to start a focus session."
        case .durationTooShort:
            return "Choose at least 15 minutes. Apple only schedules an automatic end for sessions of 15 minutes or longer."
        case .durationTooLong:
            return "Choose 6 hours or less."
        case .notAuthorized:
            return "Focus can't block apps until Screen Time access is enabled."
        case .authorizationUnavailable:
            return "No Screen Time access is currently available."
        case .restrictionsNotApplied:
            return "We couldn't start the focus session. Your selected restrictions were not applied."
        case .restrictionsNotCleared:
            return "The session ended, but Focus couldn't remove the restrictions. Open Focus again to retry."
        case .scheduleFailed(let message):
            return message
        case .persistenceFailed:
            return "Your session could not be saved."
        case .historyUnreadable:
            return "Older sessions could not be read."
        case .sessionAlreadyActive:
            return "A focus session is already running."
        case .noActiveSession:
            return "There's no focus session to end."
        case .illegalTransition:
            return "That action isn't available right now."
        case .appGroupUnavailable:
            return "Focus needs its App Group to share the session with Screen Time. Add the App Group capability to the app and its extensions."
        case .couldNotRestoreSession:
            return "A saved session could not be restored. Focus tried to remove any leftover restrictions."
        }
    }
}
