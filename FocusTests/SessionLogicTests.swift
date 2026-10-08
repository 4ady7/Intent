import DeviceActivity
import XCTest

final class SessionLogicTests: XCTestCase {
    func testAllowedTransitions() throws {
        XCTAssertEqual(try SessionStateMachine.transition(from: .idle, to: .configuring), .configuring)
        XCTAssertEqual(try SessionStateMachine.transition(from: .configuring, to: .starting), .starting)
        XCTAssertEqual(try SessionStateMachine.transition(from: .starting, to: .active), .active)
        XCTAssertEqual(try SessionStateMachine.transition(from: .active, to: .ending), .ending)
        XCTAssertEqual(try SessionStateMachine.transition(from: .ending, to: .completed), .completed)
        XCTAssertEqual(try SessionStateMachine.transition(from: .ending, to: .cancelled), .cancelled)
        XCTAssertEqual(try SessionStateMachine.transition(from: .completed, to: .idle), .idle)
        XCTAssertEqual(try SessionStateMachine.transition(from: .starting, to: .idle), .idle)
        XCTAssertEqual(try SessionStateMachine.transition(from: .ending, to: .active), .active)
    }

    func testIllegalTransitionsAreRejected() {
        XCTAssertThrowsError(try SessionStateMachine.transition(from: .idle, to: .active)) { error in
            XCTAssertEqual(error as? FocusError, .illegalTransition)
        }
        XCTAssertThrowsError(try SessionStateMachine.transition(from: .completed, to: .active))
        XCTAssertThrowsError(try SessionStateMachine.transition(from: .active, to: .completed))
        XCTAssertThrowsError(try SessionStateMachine.transition(from: .cancelled, to: .active))
        XCTAssertFalse(SessionStateMachine.canTransition(from: .idle, to: .ending))
    }

    func testRemainingTimeComesFromTheEndTimestamp() {
        let start = Date(timeIntervalSince1970: 1_000)
        let planned: TimeInterval = 45 * 60
        let end = start.addingTimeInterval(planned)

        XCTAssertEqual(SessionClock.remaining(plannedDuration: planned, startDate: start, endDate: end, now: start), planned)
        XCTAssertEqual(SessionClock.remaining(plannedDuration: planned, startDate: start, endDate: end, now: start.addingTimeInterval(15 * 60)), 30 * 60)
        XCTAssertEqual(SessionClock.remaining(plannedDuration: planned, startDate: start, endDate: end, now: end), 0)
        XCTAssertEqual(SessionClock.remaining(plannedDuration: planned, startDate: start, endDate: end, now: end.addingTimeInterval(30)), 0)
        XCTAssertEqual(
            SessionClock.remaining(plannedDuration: planned, startDate: start, endDate: end, now: start.addingTimeInterval(-120)),
            planned
        )
        XCTAssertEqual(SessionClock.elapsed(plannedDuration: planned, startDate: start, endDate: end, now: start.addingTimeInterval(10 * 60)), 10 * 60)
    }

    func testClockFormatDoesNotDependOnTickAccumulation() {
        XCTAssertEqual(FocusDurationFormat.clock(0), "0:00")
        XCTAssertEqual(FocusDurationFormat.clock(42 * 60 + 18), "42:18")
        XCTAssertEqual(FocusDurationFormat.clock(3600), "1:00:00")
        XCTAssertEqual(FocusDurationFormat.clock(3661), "1:01:01")
        XCTAssertEqual(FocusDurationFormat.compact(25 * 60), "25 min")
        XCTAssertEqual(FocusDurationFormat.compact(60 * 60), "1h")
        XCTAssertEqual(FocusDurationFormat.compact(90 * 60), "1h 30m")
        XCTAssertEqual(FocusDurationFormat.compact(2 * 3600 + 15 * 60), "2h 15m")
        XCTAssertEqual(FocusDurationFormat.compact(20), "20s")
        XCTAssertEqual(FocusDurationFormat.compact(0), "0s")
        XCTAssertEqual(FocusDurationFormat.phrase(30), "less than a minute")
        XCTAssertEqual(SessionNaming.sanitized("  Deep Work  "), "Deep Work")
        XCTAssertEqual(SessionNaming.sanitized("   "), "Focus")
        XCTAssertEqual(SessionNaming.sanitized(String(repeating: "a", count: 80)).count, 40)
    }

    func testRecoveryDecisions() {
        let start = Date(timeIntervalSince1970: 5_000)
        var session = FocusSession.starting(
            name: "Study",
            presetID: nil,
            start: start,
            duration: 25 * 60,
            selection: PersistedSelection()
        )
        XCTAssertEqual(SessionRecovery.action(for: nil, now: start), .none)
        XCTAssertEqual(SessionRecovery.action(for: session, now: start.addingTimeInterval(10)), .discardIncompleteStart)

        session.phase = .active
        XCTAssertEqual(SessionRecovery.action(for: session, now: start.addingTimeInterval(60)), .resume)
        XCTAssertEqual(SessionRecovery.action(for: session, now: session.endDate.addingTimeInterval(1)), .expire)

        session.phase = .ending
        session.requestedOutcome = .cancelled
        XCTAssertEqual(SessionRecovery.action(for: session, now: start), .finish(.cancelled))

        session.phase = .completed
        XCTAssertEqual(SessionRecovery.action(for: session, now: start), .discardIncompleteStart)
    }

    func testDefaultPresets() {
        XCTAssertEqual(FocusPreset.defaults.count, 6)
        XCTAssertEqual(Set(FocusPreset.defaults.map(\.id)).count, 6)
        XCTAssertEqual(FocusPreset.defaults.first { $0.kind == .deepWork }?.duration, 45 * 60)
        XCTAssertEqual(FocusPreset.defaults.first { $0.kind == .reading }?.duration, 25 * 60)
        XCTAssertEqual(FocusPreset.defaults.first { $0.kind == .coding }?.duration, 90 * 60)
    }

    func testStatistics() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 15))!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 9))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 18))!
        let lastMonth = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 9))!

        let completedToday = makeFinished(start: today, planned: 60 * 60, actual: 60 * 60, outcome: .completed)
        let cancelledToday = makeFinished(start: today.addingTimeInterval(4 * 3600), planned: 45 * 60, actual: 15 * 60, outcome: .cancelled)
        let yesterdaySession = makeFinished(start: yesterday, planned: 90 * 60, actual: 90 * 60, outcome: .completed)
        let old = makeFinished(start: lastMonth, planned: 30 * 60, actual: 30 * 60, outcome: .completed)
        var active = FocusSession.starting(name: "Reading", presetID: nil, start: now.addingTimeInterval(-10 * 60), duration: 25 * 60, selection: PersistedSelection())
        active.phase = .active

        let stats = FocusStats.compute(
            history: [completedToday, cancelledToday, yesterdaySession, old],
            active: active,
            now: now,
            calendar: calendar
        )

        let minute: TimeInterval = 60
        let expectedTotal = (60 + 15 + 90 + 30 + 10) * minute
        let expectedToday = (60 + 15 + 10) * minute
        let expectedWeek = (60 + 15 + 90 + 10) * minute
        let expectedAverage = ((60 + 90 + 30) * minute) / 3

        XCTAssertEqual(stats.completedCount, 3)
        XCTAssertEqual(stats.cancelledCount, 1)
        XCTAssertEqual(stats.totalFocusTime, expectedTotal, accuracy: 0.1)
        XCTAssertEqual(stats.todayFocusTime, expectedToday, accuracy: 0.1)
        XCTAssertEqual(stats.todaySessionCount, 3)
        XCTAssertEqual(stats.longestCompleted, 90 * minute)
        XCTAssertEqual(stats.averageCompletedLength ?? 0, expectedAverage, accuracy: 0.1)
        XCTAssertEqual(stats.completionRate ?? 0, 0.75, accuracy: 0.001)
        XCTAssertEqual(stats.weekFocusTime, expectedWeek, accuracy: 0.1)
    }

    func testEmptyStatisticsUseNoCompletionRate() {
        let stats = FocusStats.compute(history: [], active: nil, now: Date())
        XCTAssertNil(stats.completionRate)
        XCTAssertNil(stats.averageCompletedLength)
        XCTAssertNil(stats.longestCompleted)
        XCTAssertEqual(stats.totalFocusTime, 0)
    }

    func testShieldCopyStaysCalm() {
        let now = Date()
        XCTAssertEqual(ShieldCopy.title, "Focus is active")
        XCTAssertEqual(ShieldCopy.button, "Close")
        XCTAssertTrue(ShieldCopy.subtitle(endDate: nil, now: now).contains("You chose to protect your attention"))
        XCTAssertTrue(ShieldCopy.subtitle(endDate: now.addingTimeInterval(23 * 60), now: now).contains("23 minutes"))
        XCTAssertTrue(ShieldCopy.subtitle(endDate: now.addingTimeInterval(30), now: now).contains("less than a minute"))
        XCTAssertFalse(ShieldCopy.subtitle(endDate: now.addingTimeInterval(600), now: now).contains("failed"))
        XCTAssertFalse(ShieldCopy.subtitle(endDate: now, now: now).localizedCaseInsensitiveContains("wasting"))
    }

    func testMonitorIgnoresEarlyAndForeignCallbacks() {
        let start = Date()
        var session = FocusSession.starting(name: "Work", presetID: nil, start: start, duration: 45 * 60, selection: PersistedSelection())
        session.phase = .active
        let other = UUID()

        XCTAssertEqual(MonitorPolicy.endDecision(active: session, activitySessionID: other, now: session.endDate), .ignore)
        XCTAssertEqual(MonitorPolicy.endDecision(active: session, activitySessionID: session.id, now: start.addingTimeInterval(60)), .reschedule)
        XCTAssertEqual(MonitorPolicy.completionOutcome(for: session), .completed)
        session.requestedOutcome = .cancelled
        session.phase = .ending
        XCTAssertEqual(MonitorPolicy.completionOutcome(for: session), .cancelled)
        session.phase = .active
        session.requestedOutcome = nil
        XCTAssertEqual(MonitorPolicy.endDecision(active: session, activitySessionID: session.id, now: session.endDate), .endSession)
        XCTAssertEqual(MonitorPolicy.endDecision(active: nil, activitySessionID: session.id, now: start), .endSession)
        XCTAssertEqual(MonitorPolicy.startDecision(active: session, activitySessionID: session.id, now: start.addingTimeInterval(30)), .reapply)
        XCTAssertEqual(MonitorPolicy.startDecision(active: session, activitySessionID: other, now: start), .ignore)
        XCTAssertEqual(MonitorPolicy.startDecision(active: nil, activitySessionID: session.id, now: start), .ignore)

        session.phase = .starting
        XCTAssertEqual(MonitorPolicy.endDecision(active: session, activitySessionID: session.id, now: session.endDate), .ignore)
    }

    func testScheduleWindowRejectsOutOfRangeDurations() {
        XCTAssertThrowsError(try ScheduleWindow.make(start: Date(), duration: 14 * 60)) { error in
            XCTAssertEqual(error as? FocusError, .durationTooShort)
        }
        XCTAssertThrowsError(try ScheduleWindow.make(start: Date(), duration: FocusDuration.maximum + 60)) { error in
            XCTAssertEqual(error as? FocusError, .durationTooLong)
        }
    }

    func testDeviceActivityIntervalMatchesRequestedDuration() throws {
        let start = Date()
        for duration in [15 * 60, 45 * 60, 2 * 60 * 60] as [TimeInterval] {
            let window = try ScheduleWindow.make(start: start, duration: duration)
            let schedule = DeviceActivitySchedule(
                intervalStart: window.intervalStart,
                intervalEnd: window.intervalEnd,
                repeats: false,
                warningTime: window.warningTime
            )
            let next = try XCTUnwrap(schedule.nextInterval, "No interval for \(duration)")
            XCTAssertEqual(next.duration, duration, accuracy: 2, "Duration \(duration)")
        }
    }

    func testDeviceActivityIntervalCanCrossMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let start = calendar.date(bySettingHour: 23, minute: 50, second: 0, of: Date())!
        let window = try ScheduleWindow.make(start: start, duration: 30 * 60, calendar: calendar)
        let schedule = DeviceActivitySchedule(
            intervalStart: window.intervalStart,
            intervalEnd: window.intervalEnd,
            repeats: false,
            warningTime: window.warningTime
        )
        let next = try XCTUnwrap(schedule.nextInterval)
        XCTAssertEqual(next.duration, 30 * 60, accuracy: 2)
    }

    private func makeFinished(start: Date, planned: TimeInterval, actual: TimeInterval, outcome: SessionOutcome) -> FocusSession {
        var session = FocusSession.starting(name: "Focus", presetID: nil, start: start, duration: planned, selection: PersistedSelection())
        session.phase = outcome == .completed ? .completed : .cancelled
        session.actualDuration = actual
        session.endedAt = start.addingTimeInterval(actual)
        return session
    }
}
