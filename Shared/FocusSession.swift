import Foundation

struct FocusSession: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var presetID: UUID?
    var startDate: Date
    var endDate: Date
    var plannedDuration: TimeInterval
    var actualDuration: TimeInterval?
    var phase: SessionPhase
    var selection: PersistedSelection
    var interruptionCount: Int
    var createdAt: Date
    var endedAt: Date?
    var requestedOutcome: SessionOutcome?
    var failureMessage: String?

    static func starting(
        id: UUID = UUID(),
        name: String,
        presetID: UUID?,
        start: Date,
        duration: TimeInterval,
        selection: PersistedSelection
    ) -> FocusSession {
        FocusSession(
            id: id,
            name: name,
            presetID: presetID,
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            plannedDuration: duration,
            actualDuration: nil,
            phase: .starting,
            selection: selection,
            interruptionCount: 0,
            createdAt: start,
            endedAt: nil,
            requestedOutcome: nil,
            failureMessage: nil
        )
    }

    func remaining(at now: Date) -> TimeInterval {
        SessionClock.remaining(
            plannedDuration: plannedDuration,
            startDate: startDate,
            endDate: endDate,
            now: now
        )
    }
}

struct FocusPreferences: Codable, Equatable {
    var hasFinishedOnboarding: Bool
    var notifyOnCompletion: Bool

    static let initial = FocusPreferences(hasFinishedOnboarding: false, notifyOnCompletion: true)
}

struct InterruptionLedger: Codable, Equatable {
    var sessionID: UUID
    var count: Int
    var lastRecordedAt: Date?
}
