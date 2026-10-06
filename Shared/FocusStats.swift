import Foundation

struct FocusStats: Equatable {
    /// Time actually spent, including cancelled sessions.
    var totalFocusTime: TimeInterval
    var completedCount: Int
    var cancelledCount: Int
    var averageCompletedLength: TimeInterval?
    var longestCompleted: TimeInterval?
    var todayFocusTime: TimeInterval
    var todaySessionCount: Int
    var weekFocusTime: TimeInterval
    var completionRate: Double?

    static let empty = FocusStats(
        totalFocusTime: 0,
        completedCount: 0,
        cancelledCount: 0,
        averageCompletedLength: nil,
        longestCompleted: nil,
        todayFocusTime: 0,
        todaySessionCount: 0,
        weekFocusTime: 0,
        completionRate: nil
    )

    static func compute(
        history: [FocusSession],
        active: FocusSession?,
        now: Date,
        calendar: Calendar = .current
    ) -> FocusStats {
        let finished = history.filter { $0.phase == .completed || $0.phase == .cancelled }
        let completed = finished.filter { $0.phase == .completed }
        let cancelled = finished.filter { $0.phase == .cancelled }
        let completedLengths = completed.map { $0.actualDuration ?? $0.plannedDuration }
        let total = finished.reduce(0) { $0 + ($1.actualDuration ?? 0) }
        let average = completedLengths.isEmpty ? nil : completedLengths.reduce(0, +) / Double(completedLengths.count)
        let longest = completedLengths.max()
        let finishedCount = completed.count + cancelled.count
        let rate = finishedCount == 0 ? nil : Double(completed.count) / Double(finishedCount)

        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let todayTime = focusTime(onSameDayAs: now, history: finished, active: active, now: now, calendar: calendar)
        let todayCount = sessionCount(onSameDayAs: now, history: finished, active: active, calendar: calendar)
        let weekTime = finished.reduce(0.0) { partial, session in
            guard let week, week.contains(session.startDate) else { return partial }
            return partial + (session.actualDuration ?? 0)
        } + elapsedIfActive(active, isInside: { week?.contains($0.startDate) == true }, now: now)

        return FocusStats(
            totalFocusTime: total + elapsedIfActive(active, isInside: { _ in true }, now: now),
            completedCount: completed.count,
            cancelledCount: cancelled.count,
            averageCompletedLength: average,
            longestCompleted: longest,
            todayFocusTime: todayTime,
            todaySessionCount: todayCount,
            weekFocusTime: weekTime,
            completionRate: rate
        )
    }

    private static func focusTime(
        onSameDayAs day: Date,
        history: [FocusSession],
        active: FocusSession?,
        now: Date,
        calendar: Calendar
    ) -> TimeInterval {
        let historical = history.reduce(0.0) { partial, session in
            guard calendar.isDate(session.startDate, inSameDayAs: day) else { return partial }
            return partial + (session.actualDuration ?? 0)
        }
        return historical + elapsedIfActive(active, isInside: { calendar.isDate($0.startDate, inSameDayAs: day) }, now: now)
    }

    private static func sessionCount(
        onSameDayAs day: Date,
        history: [FocusSession],
        active: FocusSession?,
        calendar: Calendar
    ) -> Int {
        let historical = history.filter { calendar.isDate($0.startDate, inSameDayAs: day) }.count
        let activeCount = active.map { calendar.isDate($0.startDate, inSameDayAs: day) } == true ? 1 : 0
        return historical + activeCount
    }

    private static func elapsedIfActive(
        _ active: FocusSession?,
        isInside: (FocusSession) -> Bool,
        now: Date
    ) -> TimeInterval {
        guard let active, active.phase == .active, isInside(active) else { return 0 }
        return SessionClock.elapsed(
            plannedDuration: active.plannedDuration,
            startDate: active.startDate,
            endDate: active.endDate,
            now: now
        )
    }
}
