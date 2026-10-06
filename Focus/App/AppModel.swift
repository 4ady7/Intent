import Foundation
import Observation

struct FocusDraft: Equatable {
    var presetID: UUID
    var name: String
    var duration: TimeInterval
    var selection: PersistedSelection

    init(preset: FocusPreset) {
        presetID = preset.id
        name = preset.name
        duration = preset.duration
        selection = preset.selection
    }
}

@MainActor
@Observable
final class AppModel {
    private let service: FocusSessionService
    private let authorization: any ScreenTimeAuthorizing

    private(set) var isReady = false
    private(set) var launchFailure: String?
    var banner: String?
    var isWorking = false
    var draft: FocusDraft?

    init(service: FocusSessionService, authorization: any ScreenTimeAuthorizing) {
        self.service = service
        self.authorization = authorization
    }

    convenience init() {
        let store = Self.makeStore()
        let authorization = ScreenTimeAuthorizationService()
        let service = FocusSessionService(
            store: store,
            authorizer: authorization,
            restrictions: SystemRestrictionClient(),
            scheduler: DeviceActivityScheduler(),
            notifier: SessionNotificationScheduler()
        )
        self.init(service: service, authorization: authorization)
    }

    var phase: SessionPhase { service.phase }
    var activeSession: FocusSession? { service.activeSession }
    var presets: [FocusPreset] { service.presets }
    var history: [FocusSession] { service.history }
    var pendingSummary: FocusSession? { service.pendingSummary }
    var authorizationState: ScreenTimeAuthorizationState { authorization.state }
    var preferences: FocusPreferences { service.preferences }
    var usesAppGroup: Bool { service.usesAppGroup }
    var isAuthorized: Bool { authorization.state == .approved }

    func stats(at now: Date = Date()) -> FocusStats {
        service.stats(at: now)
    }

    func remaining(at date: Date) -> TimeInterval {
        activeSession?.remaining(at: date) ?? 0
    }

    func bootstrap() async {
        guard !isReady else { return }
        await service.bootstrap()
        authorization.refresh()
        if service.phase == .active, authorization.state != .approved {
            await service.foreground()
        }
        banner = service.warning
        launchFailure = nil
        isReady = true
    }

    func retryLaunch() async {
        isReady = false
        launchFailure = nil
        await bootstrap()
    }

    func foreground() async {
        guard isReady else { return }
        await service.foreground()
        authorization.refresh()
        if let warning = service.warning {
            banner = warning
        }
    }

    func reconcile() async {
        guard isReady else { return }
        let before = authorization.state
        authorization.refresh()
        if service.phase == .active, before != authorization.state {
            await service.foreground()
        } else {
            await service.reconcile()
        }
        if let warning = service.warning {
            banner = warning
        }
    }

    func requestAuthorization() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await authorization.requestAccess()
            banner = nil
        } catch {
            banner = message(for: error)
        }
    }

    func finishOnboarding() {
        service.finishOnboarding()
    }

    func prepareDraft(from preset: FocusPreset) throws {
        if activeSession != nil {
            throw FocusError.sessionAlreadyActive
        }
        try service.beginConfiguring()
        draft = FocusDraft(preset: preset)
    }

    func cancelDraft() {
        service.cancelConfiguring()
        draft = nil
    }

    func start(_ draft: FocusDraft) async throws {
        isWorking = true
        defer { isWorking = false }
        do {
            try await service.start(StartRequest(
                name: draft.name,
                presetID: draft.presetID,
                duration: draft.duration,
                selection: draft.selection
            ))
            self.draft = nil
            banner = service.warning
        } catch {
            banner = message(for: error)
            throw error
        }
    }

    func endSession() async throws {
        isWorking = true
        defer { isWorking = false }
        do {
            try await service.endManually()
            banner = service.warning
        } catch {
            banner = message(for: error)
            throw error
        }
    }

    func acknowledgeSummary() {
        service.acknowledgeSummary()
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        service.setNotifyOnCompletion(enabled)
    }

    func dismissBanner() {
        banner = nil
    }

    func message(for error: Error) -> String {
        if let focus = error as? FocusError {
            return focus.localizedDescription
        }
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.isEmpty {
            return "Something went wrong. Try again."
        }
        FocusLog.session.error("Unhandled error: \(description, privacy: .public)")
        return "Something went wrong. Try again."
    }

    private static func makeStore() -> FocusStore {
        if let store = try? FocusStore.liveAllowingLocalFallback() {
            return store
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Focus", isDirectory: true)
        if let store = try? FocusStore(directory: url, usesAppGroup: false) {
            return store
        }
        preconditionFailure("Focus could not create a local store.")
    }
}
