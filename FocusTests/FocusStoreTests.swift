import XCTest

final class FocusStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSessionRoundTripAndIdempotentCompletion() throws {
        let store = try FocusStore(directory: directory, usesAppGroup: true)
        var session = FocusSession.starting(
            name: "Deep Work",
            presetID: FocusPreset.defaults[1].id,
            start: Date(timeIntervalSince1970: 10_000),
            duration: 45 * 60,
            selection: PersistedSelection()
        )
        session.phase = .active
        try store.saveActive(session)
        let loaded = try XCTUnwrap(try store.loadActive())
        XCTAssertEqual(loaded.name, "Deep Work")
        XCTAssertEqual(loaded.plannedDuration, 45 * 60)

        let finished = try XCTUnwrap(try store.completeActive(id: session.id, at: session.endDate, outcome: .completed))
        XCTAssertEqual(finished.phase, .completed)
        XCTAssertEqual(finished.actualDuration, 45 * 60)
        XCTAssertNil(try store.loadActive())
        XCTAssertEqual(try store.loadHistory().count, 1)
        XCTAssertEqual(try store.loadPendingSummary()?.id, session.id)
        XCTAssertNil(try store.completeActive(id: session.id, at: session.endDate, outcome: .completed))
        XCTAssertEqual(try store.loadHistory().count, 1)

        try store.acknowledgeSummary()
        XCTAssertNil(try store.loadPendingSummary())
    }

    func testCancelledSessionRecordsElapsedTime() throws {
        let store = try FocusStore(directory: directory, usesAppGroup: true)
        let start = Date(timeIntervalSince1970: 20_000)
        var session = FocusSession.starting(name: "Reading", presetID: nil, start: start, duration: 25 * 60, selection: PersistedSelection())
        session.phase = .active
        try store.saveActive(session)
        let finished = try XCTUnwrap(try store.completeActive(id: session.id, at: start.addingTimeInterval(5 * 60), outcome: .cancelled))
        XCTAssertEqual(finished.phase, .cancelled)
        XCTAssertEqual(finished.actualDuration ?? 0, 5 * 60, accuracy: 0.1)
    }

    func testStartingSessionIsNotCompletedEarly() throws {
        let store = try FocusStore(directory: directory, usesAppGroup: true)
        let session = FocusSession.starting(name: "Work", presetID: nil, start: Date(), duration: 15 * 60, selection: PersistedSelection())
        try store.saveActive(session)
        XCTAssertNil(try store.completeActive(id: session.id, at: Date(), outcome: .completed))
        XCTAssertNotNil(try store.loadActive())
    }

    func testPresetMergeKeepsSavedSelectionAndAddsMissingDefaults() throws {
        let store = try FocusStore(directory: directory, usesAppGroup: true)
        var saved = FocusPreset.defaults
        saved[0].duration = 50 * 60
        saved.removeAll { $0.kind == .custom }
        try store.savePresets(saved)
        let loaded = try store.loadPresets()
        XCTAssertEqual(loaded.first { $0.kind == .study }?.duration, 50 * 60)
        XCTAssertNotNil(loaded.first { $0.kind == .custom })
    }

    func testInterruptionsAreDebouncedPerSession() throws {
        let store = try FocusStore(directory: directory, usesAppGroup: true)
        var session = FocusSession.starting(name: "Coding", presetID: nil, start: Date(), duration: 60 * 60, selection: PersistedSelection())
        session.phase = .active
        try store.saveActive(session)
        let first = Date()
        try store.recordShieldPresentation(at: first)
        try store.recordShieldPresentation(at: first.addingTimeInterval(5))
        XCTAssertEqual(try store.interruptionCount(for: session.id), 1)
        try store.recordShieldPresentation(at: first.addingTimeInterval(FocusDuration.interruptionDebounce + 1))
        XCTAssertEqual(try store.interruptionCount(for: session.id), 2)

        let finished = try XCTUnwrap(try store.completeActive(id: session.id, at: session.endDate, outcome: .completed))
        XCTAssertEqual(finished.interruptionCount, 2)
    }

    func testCorruptActiveSessionIsQuarantined() throws {
        let store = try FocusStore(directory: directory, usesAppGroup: true)
        let url = directory.appendingPathComponent(FocusFiles.active)
        try Data("not json".utf8).write(to: url)
        XCTAssertThrowsError(try store.loadActive()) { error in
            XCTAssertEqual(error as? FocusError, .couldNotRestoreSession)
        }
        XCTAssertNil(try store.loadActive())
    }

    func testPreferencesPersist() throws {
        let store = try FocusStore(directory: directory, usesAppGroup: true)
        XCTAssertFalse(try store.loadPreferences().hasFinishedOnboarding)
        try store.savePreferences(FocusPreferences(hasFinishedOnboarding: true, notifyOnCompletion: false))
        let loaded = try store.loadPreferences()
        XCTAssertTrue(loaded.hasFinishedOnboarding)
        XCTAssertFalse(loaded.notifyOnCompletion)
    }
}
