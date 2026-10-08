import Foundation

enum MonitorDecision: Equatable {
    case ignore
    case endSession
    case reapply
    /// The interval callback arrived before the session's absolute end. The current
    /// schedule is finished, so the monitor must arm another one or shields can stick.
    case reschedule
}

enum MonitorPolicy {
    static let maximumEarlyReschedules = 3

    static func endDecision(active: FocusSession?, activitySessionID: UUID, now: Date) -> MonitorDecision {
        guard let active else { return .endSession }
        guard active.id == activitySessionID else { return .ignore }
        switch active.phase {
        case .active, .ending:
            break
        default:
            return .ignore
        }
        let tolerance = FocusDuration.earlyEndTolerance(for: active.plannedDuration)
        if now.addingTimeInterval(tolerance) < active.endDate {
            return .reschedule
        }
        return .endSession
    }

    static func completionOutcome(for session: FocusSession) -> SessionOutcome {
        if session.phase == .ending {
            return session.requestedOutcome ?? .cancelled
        }
        return .completed
    }

    static func startDecision(active: FocusSession?, activitySessionID: UUID, now: Date) -> MonitorDecision {
        guard let active, active.id == activitySessionID, active.phase == .active else {
            return .ignore
        }
        if now >= active.endDate {
            return .ignore
        }
        return .reapply
    }
}
