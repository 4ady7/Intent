import Foundation

final class FocusStore: @unchecked Sendable {
    let directory: URL
    let usesAppGroup: Bool
    private let coordinator = NSFileCoordinator(filePresenter: nil)

    init(directory: URL, usesAppGroup: Bool) throws {
        self.directory = directory
        self.usesAppGroup = usesAppGroup
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func live() throws -> FocusStore {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: FocusIdentifiers.appGroup
        ) else {
            throw FocusError.appGroupUnavailable
        }
        let url = container.appendingPathComponent("Library/Focus", isDirectory: true)
        return try FocusStore(directory: url, usesAppGroup: true)
    }

    static func liveAllowingLocalFallback() throws -> FocusStore {
        if let store = try? live() {
            return store
        }
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = base.appendingPathComponent("Focus", isDirectory: true)
        return try FocusStore(directory: url, usesAppGroup: false)
    }

    func loadActive() throws -> FocusSession? {
        try coordinate(writing: false) { directory in
            do {
                return try FocusFileIO.read(FocusSession.self, name: FocusFiles.active, in: directory)
            } catch is DecodingError {
                FocusFileIO.quarantine(name: FocusFiles.active, in: directory)
                throw FocusError.couldNotRestoreSession
            }
        }
    }

    func saveActive(_ session: FocusSession?) throws {
        try coordinate(writing: true) { directory in
            if let session {
                try FocusFileIO.write(session, name: FocusFiles.active, in: directory)
            } else {
                try FocusFileIO.remove(name: FocusFiles.active, in: directory)
            }
        }
    }

    func loadHistory() throws -> [FocusSession] {
        try coordinate(writing: true) { directory in
            do {
                return try FocusFileIO.read([FocusSession].self, name: FocusFiles.history, in: directory) ?? []
            } catch is DecodingError {
                FocusFileIO.quarantine(name: FocusFiles.history, in: directory)
                throw FocusError.historyUnreadable
            }
        }
    }

    func loadPresets() throws -> [FocusPreset] {
        try coordinate(writing: true) { directory in
            let saved = (try? FocusFileIO.read([FocusPreset].self, name: FocusFiles.presets, in: directory)) ?? []
            let merged = Self.mergePresets(saved)
            if merged != saved || saved.isEmpty {
                try FocusFileIO.write(merged, name: FocusFiles.presets, in: directory)
            }
            return merged
        }
    }

    func savePresets(_ presets: [FocusPreset]) throws {
        try coordinate(writing: true) { directory in
            try FocusFileIO.write(presets, name: FocusFiles.presets, in: directory)
        }
    }

    func loadPreferences() throws -> FocusPreferences {
        try coordinate(writing: false) { directory in
            (try? FocusFileIO.read(FocusPreferences.self, name: FocusFiles.preferences, in: directory)) ?? .initial
        }
    }

    func savePreferences(_ preferences: FocusPreferences) throws {
        try coordinate(writing: true) { directory in
            try FocusFileIO.write(preferences, name: FocusFiles.preferences, in: directory)
        }
    }

    func loadPendingSummary() throws -> FocusSession? {
        try coordinate(writing: false) { directory in
            try FocusFileIO.read(FocusSession.self, name: FocusFiles.summary, in: directory)
        }
    }

    func acknowledgeSummary() throws {
        try coordinate(writing: true) { directory in
            try FocusFileIO.remove(name: FocusFiles.summary, in: directory)
        }
    }

    @discardableResult
    func completeActive(id: UUID?, at now: Date, outcome: SessionOutcome) throws -> FocusSession? {
        try coordinate(writing: true) { directory in
            guard var session = try FocusFileIO.read(FocusSession.self, name: FocusFiles.active, in: directory) else {
                return nil
            }
            if let id, session.id != id {
                return nil
            }
            guard session.phase == .active || session.phase == .ending else {
                return nil
            }
            if session.phase == .active {
                session.phase = try SessionStateMachine.transition(from: .active, to: .ending)
            }
            let destination: SessionPhase = outcome == .completed ? .completed : .cancelled
            session.phase = try SessionStateMachine.transition(from: session.phase, to: destination)
            session.requestedOutcome = outcome
            session.endedAt = now
            session.actualDuration = Self.actualDuration(for: session, outcome: outcome, now: now)
            session.interruptionCount = Self.ledger(in: directory, sessionID: session.id)?.count ?? 0

            var history = (try? FocusFileIO.read([FocusSession].self, name: FocusFiles.history, in: directory)) ?? []
            if !history.contains(where: { $0.id == session.id }) {
                history.append(session)
            }
            history.sort { $0.startDate < $1.startDate }
            if history.count > FocusDuration.historyLimit {
                history.removeFirst(history.count - FocusDuration.historyLimit)
            }
            try FocusFileIO.write(history, name: FocusFiles.history, in: directory)
            try FocusFileIO.write(session, name: FocusFiles.summary, in: directory)
            try FocusFileIO.remove(name: FocusFiles.active, in: directory)
            try FocusFileIO.remove(name: FocusFiles.interruptions, in: directory)
            return session
        }
    }

    func recordShieldPresentation(at date: Date) throws {
        try coordinate(writing: true) { directory in
            guard let session = try FocusFileIO.read(FocusSession.self, name: FocusFiles.active, in: directory),
                  session.phase == .active,
                  date < session.endDate else {
                return
            }
            var ledger = Self.ledger(in: directory, sessionID: session.id) ?? InterruptionLedger(
                sessionID: session.id,
                count: 0,
                lastRecordedAt: nil
            )
            if ledger.sessionID != session.id {
                ledger = InterruptionLedger(sessionID: session.id, count: 0, lastRecordedAt: nil)
            }
            if let last = ledger.lastRecordedAt, date.timeIntervalSince(last) < FocusDuration.interruptionDebounce {
                return
            }
            ledger.count += 1
            ledger.lastRecordedAt = date
            try FocusFileIO.write(ledger, name: FocusFiles.interruptions, in: directory)
        }
    }

    func interruptionCount(for sessionID: UUID) throws -> Int {
        try coordinate(writing: false) { directory in
            Self.ledger(in: directory, sessionID: sessionID)?.count ?? 0
        }
    }

    func resetInterruptions(for sessionID: UUID) throws {
        try coordinate(writing: true) { directory in
            let ledger = InterruptionLedger(sessionID: sessionID, count: 0, lastRecordedAt: nil)
            try FocusFileIO.write(ledger, name: FocusFiles.interruptions, in: directory)
        }
    }

    private static func ledger(in directory: URL, sessionID: UUID) -> InterruptionLedger? {
        guard let ledger = try? FocusFileIO.read(InterruptionLedger.self, name: FocusFiles.interruptions, in: directory) else {
            return nil
        }
        return ledger.sessionID == sessionID ? ledger : nil
    }

    private static func actualDuration(for session: FocusSession, outcome: SessionOutcome, now: Date) -> TimeInterval {
        if outcome == .completed {
            return session.plannedDuration
        }
        return SessionClock.elapsed(
            plannedDuration: session.plannedDuration,
            startDate: session.startDate,
            endDate: session.endDate,
            now: now
        )
    }

    private static func mergePresets(_ saved: [FocusPreset]) -> [FocusPreset] {
        var byID = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
        for preset in FocusPreset.defaults where byID[preset.id] == nil {
            byID[preset.id] = preset
        }
        let ordered = FocusPreset.defaults.compactMap { byID[$0.id] }
        let extras = saved.filter { preset in !FocusPreset.defaults.contains(where: { $0.id == preset.id }) }
        return ordered + extras
    }

    private func coordinate<T>(writing: Bool, _ work: (URL) throws -> T) throws -> T {
        var result: Result<T, Error>?
        var coordinationError: NSError?
        if writing {
            coordinator.coordinate(writingItemAt: directory, options: [], error: &coordinationError) { url in
                result = Result { try work(url) }
            }
        } else {
            coordinator.coordinate(readingItemAt: directory, options: [], error: &coordinationError) { url in
                result = Result { try work(url) }
            }
        }
        if let result {
            return try result.get()
        }
        if coordinationError != nil {
            throw FocusError.persistenceFailed
        }
        return try work(directory)
    }
}
