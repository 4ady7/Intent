import Foundation

enum ShieldCopy {
    static let title = "Focus is active"
    static let button = "Close"

    static func subtitle(endDate: Date?, now: Date) -> String {
        let choice = "You chose to protect your attention."
        guard let endDate else {
            return "\(choice) This app is temporarily blocked."
        }
        if now >= endDate {
            return "\(choice) This session is ending."
        }
        let remaining = endDate.timeIntervalSince(now)
        if remaining < 60 {
            return "\(choice) Focus ends in less than a minute."
        }
        let minutes = Int(ceil(remaining / 60))
        let unit = minutes == 1 ? "minute" : "minutes"
        return "\(choice) Focus ends in \(minutes) \(unit)."
    }
}
