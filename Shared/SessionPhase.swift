import Foundation

enum SessionPhase: String, Codable, Equatable, Sendable {
    case idle
    case configuring
    case starting
    case active
    case ending
    case completed
    case cancelled
    case error
}

enum SessionOutcome: String, Codable, Equatable, Sendable {
    case completed
    case cancelled
}
