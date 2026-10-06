import DeviceActivity
import Foundation
import ManagedSettings

class FocusDeviceActivityMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let sessionID = FocusIdentifiers.sessionID(fromActivityName: activity.rawValue) else { return }
        do {
            let store = try FocusStore.live()
            let active = try store.loadActive()
            guard MonitorPolicy.startDecision(active: active, activitySessionID: sessionID, now: Date()) == .reapply,
                  let active else {
                return
            }
            try BlockingService.apply(active.selection)
        } catch {
            FocusLog.monitor.error("intervalDidStart failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let sessionID = FocusIdentifiers.sessionID(fromActivityName: activity.rawValue) else { return }
        let now = Date()
        let active = Self.loadActive()
        guard MonitorPolicy.endDecision(active: active, activitySessionID: sessionID, now: now) == .endSession else {
            return
        }
        if let store = try? FocusStore.live() {
            do {
                _ = try store.completeActive(id: sessionID, at: now, outcome: .completed)
            } catch {
                FocusLog.monitor.error("Could not record completion: \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
            try BlockingService.clear()
        } catch {
            FocusLog.monitor.error("Could not clear restrictions: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func loadActive() -> FocusSession? {
        guard let store = try? FocusStore.live() else { return nil }
        return try? store.loadActive()
    }
}
