import Foundation

enum SessionClock {
    /// Remaining time is always derived from absolute timestamps, then clamped to the planned duration.
    static func remaining(
        plannedDuration: TimeInterval,
        startDate: Date,
        endDate: Date,
        now: Date
    ) -> TimeInterval {
        let planned = max(0, plannedDuration)
        if now <= startDate {
            return planned
        }
        let raw = endDate.timeIntervalSince(now)
        if raw <= 0 {
            return 0
        }
        return min(raw, planned)
    }

    static func elapsed(
        plannedDuration: TimeInterval,
        startDate: Date,
        endDate: Date,
        now: Date
    ) -> TimeInterval {
        let planned = max(0, plannedDuration)
        return min(planned, max(0, planned - remaining(
            plannedDuration: planned,
            startDate: startDate,
            endDate: endDate,
            now: now
        )))
    }
}
