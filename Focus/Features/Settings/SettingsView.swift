import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(authorizationTitle)
                        .font(.body.weight(.semibold))
                    Text(authorizationDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 44, alignment: .leading)
                if model.authorizationState != .approved {
                    Button(model.isWorking ? "Requesting access…" : "Allow Screen Time Access") {
                        Task { await model.requestAuthorization() }
                    }
                    .disabled(model.isWorking)
                    .frame(minHeight: 44)
                }
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .frame(minHeight: 44)
            } header: {
                Text("Screen Time")
            } footer: {
                Text("If access was denied, you can allow Focus in Settings under Screen Time, in Apps With Screen Time Access.")
            }

            Section {
                Toggle("Notify when a session ends", isOn: Binding(
                    get: { model.preferences.notifyOnCompletion },
                    set: { model.setNotificationsEnabled($0) }
                ))
                .frame(minHeight: 44)
            } footer: {
                Text("Focus asks for notification permission the first time a session starts with this on. The notification is scheduled on this iPhone.")
            }

            Section("Privacy") {
                Text("Focus is local. It does not have an account, analytics, or a server. App selections are Apple's private tokens and stay in this app's storage. Focus does not read your browsing history or the list of apps you didn't choose.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("How blocking works") {
                limitation("Restrictions are applied with Apple's Screen Time frameworks on a real iPhone. The Simulator cannot block apps.")
                limitation("Sessions are at least 15 minutes because Device Activity will not schedule a shorter automatic end.")
                limitation("The blocked-app screen can close that app. Apple does not let it open Focus.")
                limitation("If the system delays the end callback, opening Focus after the end time still removes restrictions.")
                limitation("Changing the system clock changes the session, because Apple's schedule uses the device clock.")
                limitation("App Store distribution needs Apple's separate Family Controls approval for this app and its extensions.")
                if !model.usesAppGroup {
                    limitation("The App Group is unavailable in this build, so the shield countdown and extension cannot share session details. Sign the app with the App Group and Family Controls entitlements.")
                }
            }

            Section("About") {
                LabeledContent("Version", value: versionText)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }

    private var authorizationTitle: String {
        switch model.authorizationState {
        case .approved: return "Screen Time access is on"
        case .denied: return "Screen Time access is off"
        case .notDetermined: return "Screen Time access has not been requested"
        case .unavailable: return "Screen Time access is unavailable"
        }
    }

    private var authorizationDetail: String {
        switch model.authorizationState {
        case .approved:
            return "Focus can temporarily restrict the apps you choose."
        case .denied:
            return "Focus can't block apps until Screen Time access is enabled."
        case .notDetermined:
            return "Focus needs permission to temporarily restrict the apps you choose during your focus sessions."
        case .unavailable:
            return "No Screen Time access is currently available."
        }
    }

    private func limitation(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
