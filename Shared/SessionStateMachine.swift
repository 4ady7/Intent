import Foundation

enum SessionStateMachine {
    private static let allowed: [SessionPhase: Set<SessionPhase>] = [
        .idle: [.configuring],
        .configuring: [.idle, .starting],
        .starting: [.active, .idle, .error],
        .active: [.ending],
        .ending: [.completed, .cancelled, .error, .active],
        .error: [.idle, .active],
        .completed: [.idle],
        .cancelled: [.idle]
    ]

    static func canTransition(from: SessionPhase, to: SessionPhase) -> Bool {
        allowed[from]?.contains(to) == true
    }

    static func transition(from: SessionPhase, to: SessionPhase) throws -> SessionPhase {
        guard canTransition(from: from, to: to) else {
            throw FocusError.illegalTransition
        }
        return to
    }
}
