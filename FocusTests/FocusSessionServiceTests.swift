import XCTest

@MainActor
final class FocusSessionServiceTests: XCTestCase {
    func testStartAppliesSelectionAndSchedulesTheEnd() async throws {
        let harness = try ServiceHarness()
        await harness.service.bootstrap()
        harness.restrictions.clearCount = 0

        try await harness.service.start(harness.request())

        XCTAssertEqual(harness.service.phase, .active)
        XCTAssertEqual(harness.service.activeSession?.name, "Deep Work")
        XCTAssertEqual(harness.restrictions.applied.count, 1)
        XCTAssertEqual(harness.restrictions.applied.first?.distractionCount, 3)
        XCTAssertEqual(harness.scheduler.started.count, 1)
        XCTAssertEqual(harness.scheduler.started.first?.duration, 45 * 60)
        XCTAssertEqual(try harness.store.loadActive()?.phase, .active)
        XCTAssertEqual(harness.notifier.scheduled.count, 1)
        XCTAssertEqual(harness.service.presets.first { $0.kind == .deepWork }?.duration, 45 * 60)
        XCTAssertEqual(harness.service.presets.first { $0.kind == .deepWork }?.name, "Deep Work")
    }

    func testEmptySelectionAndShortDurationAreRejected() async throws {
        let harness = try ServiceHarness()
        await harness.service.bootstrap()
        var request = harness.request()
        request.selection = PersistedSelection()
        await assertStart(harness, request, .nothingSelected)

        request = harness.request()
        request.duration = 10 * 60
        await assertStart(harness, request, .durationTooShort)
        XCTAssertTrue(harness.restrictions.applied.isEmpty)
    }

    func testDeniedAuthorizationDoesNotApplyRestrictions() async throws {
        let harness = try ServiceHarness()
        harness.authorizer.state = .denied
        await harness.service.bootstrap()
        await assertStart(harness, harness.request(), .notAuthorized)
        XCTAssertTrue(harness.restrictions.applied.isEmpty)
        XCTAssertNil(try harness.store.loadActive())
    }

    func testMissingAppGroupDoesNotApplyRestrictions() async throws {
        let harness = try ServiceHarness(usesAppGroup: false)
        await harness.service.bootstrap()
        await assertStart(harness, harness.request(), .appGroupUnavailable)
        XCTAssertTrue(harness.restrictions.applied.isEmpty)
    }

    func testFailedApplyRollsBack() async throws {
        let harness = try ServiceHarness()
        await harness.service.bootstrap()
        harness.restrictions.clearCount = 0
        harness.restrictions.applyError = FocusError.restrictionsNotApplied
        await assertStart(harness, harness.request(), .restrictionsNotApplied)
        XCTAssertEqual(harness.service.phase, .idle)
        XCTAssertNil(try harness.store.loadActive())
        XCTAssertTrue(harness.scheduler.started.isEmpty)
        XCTAssertGreaterThan(harness.restrictions.clearCount, 0)
    }

    func testFailedScheduleClearsRestrictions() async throws {
        let harness = try ServiceHarness()
        await harness.service.bootstrap()
        harness.restrictions.clearCount = 0
        harness.scheduler.startError = FocusError.scheduleFailed("The session time could not be scheduled.")
        await assertStart(harness, harness.request(), .scheduleFailed("The session time could not be scheduled."))
        XCTAssertEqual(harness.restrictions.applied.count, 1)
        XCTAssertGreaterThan(harness.restrictions.clearCount, 0)
        XCTAssertNil(try harness.store.loadActive())
        XCTAssertEqual(harness.service.phase, .idle)
    }

    func testSecondSessionIsRejectedWhileOneIsActive() async throws {
        let harness = try ServiceHarness()
        await harness.service.bootstrap()
        try await harness.service.start(harness.request())
        let first = try XCTUnwrap(harness.service.activeSession?.id)
        do {
            try await harness.service.start(harness.request(name: "Other"))
            XCTFail("Expected the second start to fail")
        } catch let error as FocusError {
            XCTAssertEqual(error, .sessionAlreadyActive)
        }
        XCTAssertEqual(harness.service.activeSession?.id, first)
        XCTAssertEqual(harness.scheduler.started.count, 1)
    }

    func testManualEndCancelsAndRemovesRestrictions() async throws {
        let harness = try ServiceHarness()
        await harness.service.bootstrap()
        try await harness.service.start(harness.request())
        harness.restrictions.clearCount = 0
        harness.clock.date = harness.clock.date.addingTimeInterval(5 * 60)

        try await harness.service.endManually()

        XCTAssertEqual(harness.service.phase, .idle)
        XCTAssertNil(harness.service.activeSession)
        XCTAssertEqual(harness.service.history.count, 1)
        XCTAssertEqual(harness.service.history.first?.phase, .cancelled)
        XCTAssertEqual(harness.service.history.first?.actualDuration ?? 0, 5 * 60, accuracy: 0.1)
        XCTAssertEqual(harness.service.pendingSummary?.phase, .cancelled)
        XCTAssertGreaterThan(harness.restrictions.clearCount, 0)
        XCTAssertEqual(harness.scheduler.stopped.count, 1)
        XCTAssertEqual(harness.notifier.cancelled, 1)
    }

    func testExpiryWhileClosedCompletesTheSession() async throws {
        let harness = try ServiceHarness()
        await harness.service.bootstrap()
        try await harness.service.start(harness.request())
        harness.clock.date = harness.clock.date.addingTimeInterval(45 * 60 + 5)
        await harness.service.reconcile()

        XCTAssertEqual(harness.service.phase, .idle)
        XCTAssertEqual(harness.service.history.first?.phase, .completed)
        XCTAssertEqual(harness.service.history.first?.actualDuration, 45 * 60)
        XCTAssertNotNil(harness.service.pendingSummary)
        XCTAssertGreaterThan(harness.restrictions.clearCount, 0)
    }

    func testReopeningAnActiveSessionResumesIt() async throws {
        let harness = try ServiceHarness()
        await harness.service.bootstrap()
        try await harness.service.start(harness.request())
        let session = try XCTUnwrap(try harness.store.loadActive())
        let resumed = try ServiceHarness(directory: harness.directory, clock: harness.clock)
        resumed.clock.date = session.startDate.addingTimeInterval(10 * 60)
        await resumed.service.bootstrap()
        XCTAssertEqual(resumed.service.phase, .active)
        XCTAssertEqual(resumed.service.activeSession?.id, session.id)
        XCTAssertEqual(resumed.restrictions.applied.count, 1)
        XCTAssertEqual(resumed.scheduler.started.first?.duration ?? 0, 35 * 60, accuracy: 1)
    }

    func testIncompleteStartIsDiscardedOnLaunch() async throws {
        let harness = try ServiceHarness()
        let session = FocusSession.starting(name: "Work", presetID: nil, start: harness.clock.date, duration: 60 * 60, selection: PersistedSelection(testDistractionCount: 1))
        try harness.store.saveActive(session)
        await harness.service.bootstrap()
        XCTAssertEqual(harness.service.phase, .idle)
        XCTAssertNil(try harness.store.loadActive())
        XCTAssertTrue(harness.service.history.isEmpty)
        XCTAssertGreaterThan(harness.restrictions.clearCount, 0)
    }

    func testCustomPresetRemembersItsName() async throws {
        let harness = try ServiceHarness()
        await harness.service.bootstrap()
        let custom = try XCTUnwrap(harness.service.presets.first { $0.kind == .custom })
        try await harness.service.start(harness.request(name: "CS assignment", presetID: custom.id, duration: 25 * 60))
        XCTAssertEqual(harness.service.presets.first { $0.id == custom.id }?.name, "CS assignment")
        XCTAssertEqual(harness.service.presets.first { $0.id == custom.id }?.duration, 25 * 60)
    }

    func testAuthorizationLossEndsTheSession() async throws {
        let harness = try ServiceHarness()
        await harness.service.bootstrap()
        try await harness.service.start(harness.request())
        harness.authorizer.state = .denied
        await harness.service.foreground()
        XCTAssertNil(harness.service.activeSession)
        XCTAssertEqual(harness.service.history.first?.phase, .cancelled)
        XCTAssertEqual(harness.service.warning, "Screen Time access changed, so this focus session ended.")
    }

    private func assertStart(_ harness: ServiceHarness, _ request: StartRequest, _ expected: FocusError) async {
        do {
            try await harness.service.start(request)
            XCTFail("Expected \(expected)")
        } catch let error as FocusError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}

@MainActor
private final class ServiceHarness {
    let directory: URL
    let clock: ManualClock
    let authorizer = FakeAuthorizer()
    let restrictions = FakeRestrictions()
    let scheduler = FakeScheduler()
    let notifier = FakeNotifier()
    let store: FocusStore
    let service: FocusSessionService

    init(usesAppGroup: Bool = true, directory: URL? = nil, clock: ManualClock? = nil) throws {
        let directory = directory ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        self.directory = directory
        let clock = clock ?? ManualClock(Date(timeIntervalSince1970: 1_700_000_000))
        self.clock = clock
        store = try FocusStore(directory: directory, usesAppGroup: usesAppGroup)
        service = FocusSessionService(
            store: store,
            authorizer: authorizer,
            restrictions: restrictions,
            scheduler: scheduler,
            notifier: notifier,
            clock: { clock.date }
        )
    }

    func request(name: String = "Deep Work", presetID: UUID? = nil, duration: TimeInterval = 45 * 60) -> StartRequest {
        StartRequest(
            name: name,
            presetID: presetID ?? FocusPreset.defaults.first { $0.kind == .deepWork }?.id,
            duration: duration,
            selection: PersistedSelection(testDistractionCount: 3)
        )
    }
}

private final class ManualClock: @unchecked Sendable {
    var date: Date
    init(_ date: Date) { self.date = date }
}

@MainActor
private final class FakeAuthorizer: ScreenTimeAuthorizing {
    var state: ScreenTimeAuthorizationState = .approved
    func refresh() {}
    func requestAccess() async throws {}
}

@MainActor
private final class FakeRestrictions: RestrictionApplying {
    var applied: [PersistedSelection] = []
    var clearCount = 0
    var applyError: Error?
    func apply(_ selection: PersistedSelection) throws {
        if let applyError { throw applyError }
        applied.append(selection)
    }
    func clear() throws {
        clearCount += 1
    }
}

@MainActor
private final class FakeScheduler: FocusScheduling {
    var started: [(sessionID: UUID, start: Date, duration: TimeInterval)] = []
    var stopped: [UUID] = []
    var startError: Error?
    func start(sessionID: UUID, at start: Date, duration: TimeInterval) throws {
        if let startError { throw startError }
        started.append((sessionID, start, duration))
    }
    func stop(sessionID: UUID) { stopped.append(sessionID) }
    func stopAll() {}
}

@MainActor
private final class FakeNotifier: SessionNotifying {
    var scheduled: [Date] = []
    var cancelled = 0
    func scheduleCompletion(at date: Date, sessionName: String, plannedDuration: TimeInterval) async {
        scheduled.append(date)
    }
    func cancelCompletion() async { cancelled += 1 }
}
