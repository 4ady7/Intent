import Foundation

struct ScheduleWindow: Equatable {
    var intervalStart: DateComponents
    var intervalEnd: DateComponents
    var warningTime: DateComponents?
    var absoluteStart: Date
    var absoluteEnd: Date

    static func make(start: Date, duration: TimeInterval, calendar: Calendar = .current) throws -> ScheduleWindow {
        guard duration + 0.001 >= FocusDuration.minimum else {
            throw FocusError.durationTooShort
        }
        guard duration <= FocusDuration.maximum + 0.001 else {
            throw FocusError.durationTooLong
        }

        let end = start.addingTimeInterval(duration)
        let fields: Set<Calendar.Component> = [.hour, .minute, .second]
        var intervalStart = calendar.dateComponents(fields, from: start)
        var intervalEnd = calendar.dateComponents(fields, from: end)
        intervalStart.calendar = calendar
        intervalEnd.calendar = calendar
        intervalStart.timeZone = calendar.timeZone
        intervalEnd.timeZone = calendar.timeZone

        let warning: DateComponents? = duration >= 20 * 60 ? DateComponents(minute: 1) : nil
        return ScheduleWindow(
            intervalStart: intervalStart,
            intervalEnd: intervalEnd,
            warningTime: warning,
            absoluteStart: start,
            absoluteEnd: end
        )
    }
}
