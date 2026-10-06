import Foundation

enum FocusDuration {
    static let minimum: TimeInterval = 15 * 60
    static let maximum: TimeInterval = 6 * 60 * 60
    static let presets: [TimeInterval] = [15, 25, 45, 60, 90, 120].map { $0 * 60 }
    static let historyLimit = 1000
    static let interruptionDebounce: TimeInterval = 30

    static func earlyEndTolerance(for plannedDuration: TimeInterval) -> TimeInterval {
        min(120, max(15, plannedDuration * 0.05))
    }
}

enum FocusDurationFormat {
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func compact(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        if total < 60 {
            return "\(total) min"
        }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours == 0 {
            return "\(minutes) min"
        }
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    static func phrase(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return "less than a minute"
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute]
        formatter.maximumUnitCount = 2
        formatter.collapsesLargestUnit = true
        return formatter.string(from: interval) ?? compact(interval)
    }

    static func spokenClock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours) \(hours == 1 ? "hour" : "hours")")
        }
        if minutes > 0 {
            parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")")
        }
        if seconds > 0 || parts.isEmpty {
            parts.append("\(seconds) \(seconds == 1 ? "second" : "seconds")")
        }
        return parts.joined(separator: ", ")
    }
}

enum SessionNaming {
    static let maximumLength = 40

    static func sanitized(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(trimmed.prefix(maximumLength))
        return limited.isEmpty ? "Focus" : limited
    }
}
