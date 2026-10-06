import Foundation
import UserNotifications

@MainActor
final class SystemRestrictionClient: RestrictionApplying {
    func apply(_ selection: PersistedSelection) throws {
        try BlockingService.apply(selection)
    }

    func clear() throws {
        try BlockingService.clear()
    }
}

@MainActor
final class SessionNotificationScheduler: SessionNotifying {
    func scheduleCompletion(at date: Date, sessionName: String, plannedDuration: TimeInterval) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        var status = settings.authorizationStatus
        if status == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            status = granted ? .authorized : .denied
        }
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let content = UNMutableNotificationContent()
        content.title = "Focus complete"
        content.body = "You protected your attention for \(FocusDurationFormat.phrase(plannedDuration))."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(
            identifier: FocusIdentifiers.completionNotificationID,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            FocusLog.session.error("Could not schedule completion notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    func cancelCompletion() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [FocusIdentifiers.completionNotificationID])
        center.removeDeliveredNotifications(withIdentifiers: [FocusIdentifiers.completionNotificationID])
    }
}
