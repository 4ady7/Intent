import DeviceActivity
import Foundation
import ManagedSettings

class FocusDeviceActivityMonitor: DeviceActivityMonitor {
    private var isRescheduling = false

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let sessionID = FocusIdentifiers.sessionID(fromActivityName: activity.rawValue) else { return }
        do {
            let store = try FocusStore.live()
            try store.exclusively {
                let active = try store.loadActive()
                guard MonitorPolicy.startDecision(active: active, activitySessionID: sessionID, now: Date()) == .reapply,
                      let active else {
                    return
                }
                try BlockingService.apply(active.selection)
            }
        } catch {
            FocusLog.monitor.error("intervalDidStart failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let sessionID = FocusIdentifiers.sessionID(fromActivityName: activity.rawValue) else { return }
        let now = Date()
        let decision: MonitorDecision
        let active: FocusSession?
        do {
            let store = try FocusStore.live()
            let snapshot = try store.exclusively { () -> (MonitorDecision, FocusSession?) in
                let active: FocusSession?
                do {
                    active = try store.loadActive()
                } catch {
                    FocusLog.monitor.error("Could not read the session, so restrictions were left in place: \(error.localizedDescription, privacy: .public)")
                    return (.ignore, nil)
                }
                let decision = MonitorPolicy.endDecision(active: active, activitySessionID: sessionID, now: now)
                guard decision == .endSession else {
                    return (decision, active)
                }
                if let active {
                    do {
                        _ = try store.completeActive(
                            id: sessionID,
                            at: now,
                            outcome: MonitorPolicy.completionOutcome(for: active)
                        )
                    } catch {
                        FocusLog.monitor.error("Could not record completion: \(error.localizedDescription, privacy: .public)")
                    }
                }
                do {
                    try BlockingService.clear()
                } catch {
                    FocusLog.monitor.error("Could not clear restrictions: \(error.localizedDescription, privacy: .public)")
                }
                if let current = try? store.loadActive(),
                   current.phase == .active || current.phase == .starting {
                    try? BlockingService.apply(current.selection)
                }
                return (decision, active)
            }
            decision = snapshot.0
            active = snapshot.1
        } catch {
            FocusLog.monitor.error("intervalDidEnd failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        if decision == .reschedule, let active {
            reschedule(active, now: now)
        }
    }

    private func reschedule(_ session: FocusSession, now: Date) {
        guard !isRescheduling else { return }
        isRescheduling = true
        defer { isRescheduling = false }
        let remaining = session.remaining(at: now)
        guard remaining > 0 else { return }
        let duration = max(remaining, FocusDuration.minimum)
        guard let store = try? FocusStore.live() else { return }
        var cursor = (try? store.loadMonitorCursor()) ?? MonitorCursor(sessionID: session.id, earlyReschedules: 0)
        if cursor.sessionID != session.id {
            cursor = MonitorCursor(sessionID: session.id, earlyReschedules: 0)
        }
        guard cursor.earlyReschedules < MonitorPolicy.maximumEarlyReschedules else {
            FocusLog.monitor.error("Stopped rescheduling an early end callback")
            return
        }
        cursor.earlyReschedules += 1
        try? store.saveMonitorCursor(cursor)
        guard let window = try? ScheduleWindow.make(start: now, duration: duration) else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: window.intervalStart,
            intervalEnd: window.intervalEnd,
            repeats: false,
            warningTime: nil
        )
        let name = DeviceActivityName(FocusIdentifiers.activityName(for: session.id))
        let center = DeviceActivityCenter()
        center.stopMonitoring([name])
        do {
            try center.startMonitoring(name, during: schedule)
        } catch {
            FocusLog.monitor.error("Could not reschedule the session end: \(error.localizedDescription, privacy: .public)")
        }
    }
}
