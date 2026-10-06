import Foundation

enum RecoveryAction: Equatable {
    case none
    case discardIncompleteStart
    case finish(SessionOutcome)
    case expire
    case resume
}

enum SessionRecovery {
    static func action(for session: FocusSession?, now: Date) -> RecoveryAction {
        guard let session else { return .none }
        switch session.phase {
        case .starting:
            return .discardIncompleteStart
        case .ending:
            return .finish(session.requestedOutcome ?? .cancelled)
        case .active:
            let remaining = SessionClock.remaining(
                plannedDuration: session.plannedDuration,
                startDate: session.startDate,
                endDate: session.endDate,
                now: now
            )
            return remaining <= 0 ? .expire : .resume
        case .idle, .configuring, .completed, .cancelled, .error:
            return .discardIncompleteStart
        }
    }
}
