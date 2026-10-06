import DeviceActivity
import Foundation

@MainActor
final class DeviceActivityScheduler: FocusScheduling {
    private let center = DeviceActivityCenter()

    func start(sessionID: UUID, at start: Date, duration: TimeInterval) throws {
        let window = try ScheduleWindow.make(start: start, duration: duration)
        let name = DeviceActivityName(FocusIdentifiers.activityName(for: sessionID))
        stop(sessionID: sessionID)
        let warned = makeSchedule(window, includeWarning: true)
        let plain = makeSchedule(window, includeWarning: false)
        let schedule = Self.closer(warned, plain, to: duration)
        guard Self.matches(schedule, duration: duration) else {
            throw FocusError.scheduleFailed("The session time could not be scheduled.")
        }
        do {
            try center.startMonitoring(name, during: schedule)
        } catch {
            guard schedule.warningTime != nil, Self.isInvalidComponents(error), Self.matches(plain, duration: duration) else {
                throw Self.map(error)
            }
            do {
                try center.startMonitoring(name, during: plain)
            } catch {
                throw Self.map(error)
            }
        }
    }

    private static func closer(
        _ first: DeviceActivitySchedule,
        _ second: DeviceActivitySchedule,
        to duration: TimeInterval
    ) -> DeviceActivitySchedule {
        let firstDistance = first.nextInterval.map { abs($0.duration - duration) }
        let secondDistance = second.nextInterval.map { abs($0.duration - duration) }
        switch (firstDistance, secondDistance) {
        case (nil, nil):
            return first
        case (.some, nil):
            return first
        case (nil, .some):
            return second
        case let (.some(left), .some(right)):
            return left <= right ? first : second
        }
    }

    private static func matches(_ schedule: DeviceActivitySchedule, duration: TimeInterval) -> Bool {
        guard let next = schedule.nextInterval else { return true }
        return abs(next.duration - duration) <= 90
    }

    func stop(sessionID: UUID) {
        let name = DeviceActivityName(FocusIdentifiers.activityName(for: sessionID))
        center.stopMonitoring([name])
    }

    func stopAll() {
        let names = center.activities.filter { $0.rawValue.hasPrefix(FocusIdentifiers.activityPrefix) }
        guard !names.isEmpty else { return }
        center.stopMonitoring(names)
    }

    private func makeSchedule(_ window: ScheduleWindow, includeWarning: Bool) -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: window.intervalStart,
            intervalEnd: window.intervalEnd,
            repeats: false,
            warningTime: includeWarning ? window.warningTime : nil
        )
    }

    private static func isInvalidComponents(_ error: Error) -> Bool {
        guard let monitoring = error as? DeviceActivityCenter.MonitoringError else { return false }
        if case .invalidDateComponents = monitoring {
            return true
        }
        return false
    }

    private static func map(_ error: Error) -> FocusError {
        FocusLog.session.error("Device Activity scheduling failed: \(error.localizedDescription, privacy: .public)")
        guard let monitoring = error as? DeviceActivityCenter.MonitoringError else {
            return .scheduleFailed("We couldn't start the focus session. The end of the session could not be scheduled.")
        }
        switch monitoring {
        case .intervalTooShort:
            return .durationTooShort
        case .intervalTooLong:
            return .scheduleFailed("That session is too long to schedule.")
        case .invalidDateComponents:
            return .scheduleFailed("The session time could not be scheduled.")
        case .unauthorized:
            return .notAuthorized
        case .excessiveActivities:
            return .scheduleFailed("This iPhone is already monitoring too many schedules. End another activity and try again.")
        @unknown default:
            return .scheduleFailed("We couldn't start the focus session. The end of the session could not be scheduled.")
        }
    }
}
