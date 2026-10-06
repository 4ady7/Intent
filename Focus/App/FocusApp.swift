import SwiftUI

@main
struct FocusApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(.primary)
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await model.foreground() }
                }
        }
    }
}
