import Foundation

struct StartRequest: Equatable {
    var name: String
    var presetID: UUID?
    var duration: TimeInterval
    var selection: PersistedSelection
}

@MainActor
final class FocusSessionService {
    private let store: FocusStore
    private let authorizer: any ScreenTimeAuthorizing
    private let restrictions: any RestrictionApplying
    private let scheduler: any FocusScheduling
    private let notifier: any SessionNotifying
    private let clock: () -> Date

    private(set) var phase: SessionPhase = .idle
    private(set) var activeSession: FocusSession?
    private(set) var history: [FocusSession] = []
    private(set) var presets: [FocusPreset] = FocusPreset.defaults
    private(set) var preferences = FocusPreferences.initial
    private(set) var pendingSummary: FocusSession?
    private(set) var warning: String?
    var usesAppGroup: Bool { store.usesAppGroup }

    init(
        store: FocusStore,
        authorizer: any ScreenTimeAuthorizing,
        restrictions: any RestrictionApplying,
        scheduler: any FocusScheduling,
        notifier: any SessionNotifying,
        clock: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.authorizer = authorizer
        self.restrictions = restrictions
        self.scheduler = scheduler
        self.notifier = notifier
        self.clock = clock
    }

    func bootstrap() async {
        warning = nil
        do {
            preferences = try store.loadPreferences()
        } catch {
            preferences = .initial
            note(error)
        }
        do {
            presets = try store.loadPresets()
        } catch {
            presets = FocusPreset.defaults
            note(error)
        }
        do {
            history = try store.loadHistory()
        } catch {
            history = []
            note(error)
        }
        pendingSummary = try? store.loadPendingSummary()

        let stored: FocusSession?
        do {
            stored = try store.loadActive()
        } catch {
            stored = nil
            note(error)
            clearLeftovers()
            phase = .idle
            activeSession = nil
            return
        }

        await perform(SessionRecovery.action(for: stored, now: clock()), stored: stored)
    }

    func foreground() async {
        authorizer.refresh()
        if phase == .active {
            await handleAuthorizationChange()
        }
        guard activeSession != nil || (try? store.loadActive()) != nil else {
            clearLeftovers()
            return
        }
        await perform(SessionRecovery.action(for: try? store.loadActive(), now: clock()), stored: try? store.loadActive())
    }

    func beginConfiguring() throws {
        guard phase == .idle else {
            if phase == .active {
                throw FocusError.sessionAlreadyActive
            }
            return
        }
        phase = try SessionStateMachine.transition(from: phase, to: .configuring)
    }

    func cancelConfiguring() {
        guard phase == .configuring else { return }
        phase = (try? SessionStateMachine.transition(from: phase, to: .idle)) ?? .idle
    }

    func start(_ request: StartRequest) async throws {
        if phase == .active || phase == .starting || phase == .ending {
            throw FocusError.sessionAlreadyActive
        }
        let name = SessionNaming.sanitized(request.name)
        guard request.selection.hasSelection else { throw FocusError.nothingSelected }
        guard request.duration + 0.5 >= FocusDuration.minimum else { throw FocusError.durationTooShort }
        guard request.duration <= FocusDuration.maximum + 0.5 else { throw FocusError.durationTooLong }

        authorizer.refresh()
        switch authorizer.state {
        case .approved:
            break
        case .denied:
            throw FocusError.notAuthorized
        case .notDetermined, .unavailable:
            throw FocusError.authorizationUnavailable
        }
        guard store.usesAppGroup else { throw FocusError.appGroupUnavailable }

        if phase == .idle {
            phase = try SessionStateMachine.transition(from: .idle, to: .configuring)
        }
        if phase != .configuring {
            throw FocusError.illegalTransition
        }
        phase = try SessionStateMachine.transition(from: .configuring, to: .starting)

        let now = clock()
        var session = FocusSession.starting(
            name: name,
            presetID: request.presetID,
            start: now,
            duration: request.duration,
            selection: request.selection
        )

        do {
            scheduler.stopAll()
            try store.saveActive(session)
            try restrictions.apply(request.selection)
            try scheduler.start(sessionID: session.id, at: now, duration: request.duration)
            session.phase = try SessionStateMachine.transition(from: .starting, to: .active)
            try store.saveActive(session)
            try store.resetInterruptions(for: session.id)
            activeSession = session
            phase = .active
            warning = nil
        } catch {
            rollbackStart()
            throw error
        }

        rememberPreset(id: request.presetID, name: name, duration: request.duration, selection: request.selection)
        if preferences.notifyOnCompletion {
            await notifier.scheduleCompletion(at: session.endDate, sessionName: name, plannedDuration: request.duration)
        }
    }

    func endManually() async throws {
        guard phase == .active, var session = activeSession else {
            throw FocusError.noActiveSession
        }
        let now = clock()
        session.phase = try SessionStateMachine.transition(from: .active, to: .ending)
        session.requestedOutcome = .cancelled
        phase = .ending
        activeSession = session
        do {
            try store.saveActive(session)
            guard let finished = try store.completeActive(id: session.id, at: now, outcome: .cancelled) else {
                throw FocusError.persistenceFailed
            }
            scheduler.stop(sessionID: session.id)
            await notifier.cancelCompletion()
            do {
                try restrictions.clear()
            } catch {
                warning = error.localizedDescription
            }
            history = (try? store.loadHistory()) ?? history
            pendingSummary = finished
            activeSession = nil
            phase = .idle
        } catch {
            if phase == .ending {
                phase = (try? SessionStateMachine.transition(from: .ending, to: .active)) ?? .active
                activeSession?.phase = .active
            }
            throw error
        }
    }

    func acknowledgeSummary() {
        pendingSummary = nil
        try? store.acknowledgeSummary()
    }

    func setNotifyOnCompletion(_ enabled: Bool) {
        preferences.notifyOnCompletion = enabled
        try? store.savePreferences(preferences)
    }

    func finishOnboarding() {
        preferences.hasFinishedOnboarding = true
        try? store.savePreferences(preferences)
    }

    func stats(at now: Date? = nil) -> FocusStats {
        FocusStats.compute(history: history, active: activeSession, now: now ?? clock())
    }

    private func perform(_ action: RecoveryAction, stored: FocusSession?) async {
        switch action {
        case .none:
            clearLeftovers()
            activeSession = nil
            phase = .idle
        case .discardIncompleteStart:
            try? store.saveActive(nil)
            clearLeftovers()
            activeSession = nil
            phase = .idle
        case .finish(let outcome):
            await finishStoredSession(stored, outcome: outcome)
        case .expire:
            await finishStoredSession(stored, outcome: .completed)
        case .resume:
            guard let stored else { return }
            activeSession = stored
            phase = .active
            await resume(stored)
        }
    }

    func reconcile() async {
        guard let session = activeSession ?? (try? store.loadActive()) else { return }
        let action = SessionRecovery.action(for: session, now: clock())
        if case .resume = action { return }
        await perform(action, stored: session)
    }

    private func finishStoredSession(_ stored: FocusSession?, outcome: SessionOutcome) async {
        if let stored {
            pendingSummary = try? store.completeActive(id: stored.id, at: clock(), outcome: outcome)
            history = (try? store.loadHistory()) ?? history
        }
        clearLeftovers()
        await notifier.cancelCompletion()
        activeSession = nil
        phase = .idle
    }

    private func resume(_ session: FocusSession) async {
        let now = clock()
        let remaining = session.remaining(at: now)
        do {
            try restrictions.apply(session.selection)
        } catch {
            warning = "We couldn't update your restrictions. We'll try again."
            FocusLog.session.error("Resume apply failed: \(error.localizedDescription, privacy: .public)")
        }
        do {
            if remaining >= FocusDuration.minimum {
                try scheduler.start(sessionID: session.id, at: now, duration: remaining)
            } else if remaining > 0 {
                // Device Activity cannot schedule the short remainder. A 15 minute
                // safety window still clears shields if Focus stays closed.
                try scheduler.start(sessionID: session.id, at: now, duration: FocusDuration.minimum)
            }
        } catch {
            warning = "The session is running, but its automatic end could not be rescheduled."
            FocusLog.session.error("Resume schedule failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handleAuthorizationChange() async {
        authorizer.refresh()
        guard activeSession != nil else { return }
        switch authorizer.state {
        case .approved:
            if let session = activeSession {
                try? restrictions.apply(session.selection)
            }
        case .denied, .unavailable:
            if let session = activeSession {
                _ = try? store.completeActive(id: session.id, at: min(clock(), session.endDate), outcome: .cancelled)
                history = (try? store.loadHistory()) ?? history
                pendingSummary = try? store.loadPendingSummary()
            }
            clearLeftovers()
            await notifier.cancelCompletion()
            activeSession = nil
            phase = .idle
            warning = "Screen Time access changed, so this focus session ended."
        case .notDetermined:
            break
        }
    }

    private func rememberPreset(id: UUID?, name: String, duration: TimeInterval, selection: PersistedSelection) {
        guard let id, let index = presets.firstIndex(where: { $0.id == id }) else { return }
        if presets[index].kind == .custom {
            presets[index].name = name
        }
        presets[index].duration = duration
        presets[index].selection = selection
        do {
            try store.savePresets(presets)
        } catch {
            warning = "The session started, but the preset could not be saved."
        }
    }

    private func rollbackStart() {
        scheduler.stopAll()
        try? restrictions.clear()
        try? store.saveActive(nil)
        activeSession = nil
        if phase == .starting {
            phase = (try? SessionStateMachine.transition(from: .starting, to: .idle)) ?? .idle
        } else {
            phase = .idle
        }
    }

    private func clearLeftovers() {
        scheduler.stopAll()
        do {
            try restrictions.clear()
        } catch {
            FocusLog.session.error("Could not clear restrictions: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func note(_ error: Error) {
        warning = (error as? LocalizedError)?.errorDescription ?? FocusError.persistenceFailed.localizedDescription
        FocusLog.session.error("Store error: \(error.localizedDescription, privacy: .public)")
    }
}
