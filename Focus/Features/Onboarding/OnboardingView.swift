import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    var allowsDeferral = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Focus")
                        .font(.largeTitle.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Protect your attention.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Text("Choose the apps that pull you away, set a time, and start. Focus blocks those apps until the session ends.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Screen Time access")
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Focus needs permission to temporarily restrict the apps you choose during your focus sessions. Your selection stays on this device.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let banner = model.banner {
                    BannerView(message: banner) {
                        model.dismissBanner()
                    }
                }

                VStack(spacing: 12) {
                    Button {
                        Task {
                            await model.requestAuthorization()
                            if model.isAuthorized {
                                model.finishOnboarding()
                            }
                        }
                    } label: {
                        Text(model.isWorking ? "Requesting access…" : "Allow Screen Time Access")
                    }
                    .buttonStyle(FocusPrimaryButtonStyle())
                    .disabled(model.isWorking)
                    .accessibilityHint("Shows the system Screen Time prompt")

                    if allowsDeferral {
                        Button("Not Now") {
                            model.finishOnboarding()
                        }
                        .buttonStyle(FocusSecondaryButtonStyle())
                        .disabled(model.isWorking)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
    }
}
