import SwiftUI
import UIKit

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if !model.isReady {
                launchPlaceholder
            } else if let launchFailure = model.launchFailure {
                launchFailureView(launchFailure)
            } else if !model.preferences.hasFinishedOnboarding {
                OnboardingView()
            } else {
                HomeView()
            }
        }
        .task {
            await model.bootstrap()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await model.foreground() }
        }
    }

    private var launchPlaceholder: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .overlay {
                Text("Focus")
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
            }
    }

    private func launchFailureView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Focus")
                .font(.largeTitle.weight(.semibold))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try Again") {
                Task { await model.retryLaunch() }
            }
            .buttonStyle(FocusPrimaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
