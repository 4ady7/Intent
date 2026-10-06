import Foundation

enum ScreenTimeAuthorizationState: String, Equatable, Sendable {
    case notDetermined
    case approved
    case denied
    case unavailable
}

@MainActor
protocol ScreenTimeAuthorizing: AnyObject {
    var state: ScreenTimeAuthorizationState { get }
    func refresh()
    func requestAccess() async throws
}

@MainActor
protocol RestrictionApplying: AnyObject {
    func apply(_ selection: PersistedSelection) throws
    func clear() throws
}

@MainActor
protocol FocusScheduling: AnyObject {
    func start(sessionID: UUID, at start: Date, duration: TimeInterval) throws
    func stop(sessionID: UUID)
    func stopAll()
}

@MainActor
protocol SessionNotifying: AnyObject {
    func scheduleCompletion(at date: Date, sessionName: String, plannedDuration: TimeInterval) async
    func cancelCompletion() async
}
