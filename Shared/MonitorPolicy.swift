import Foundation

enum MonitorDecision: Equatable {
    case ignore
    case endSession
    case reapply
}

enum MonitorPolicy {
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
            return .ignore
        }
        return .endSession
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
