import os

enum FocusLog {
    static let session = Logger(subsystem: "com.shady.Focus", category: "session")
    static let monitor = Logger(subsystem: "com.shady.Focus", category: "monitor")
    static let shield = Logger(subsystem: "com.shady.Focus", category: "shield")
}
