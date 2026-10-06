import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSetup = false
    @State private var showActive = false
    @State private var showAuthorization = false
    @State private var setupError: String?
    @State private var summary: FocusSession?
    @State private var resumePresetID: UUID?
    @State private var didRouteToActive = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Protect your attention.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityAddTraits(.isHeader)

                    if let banner = model.banner {
                        BannerView(message: banner) { model.dismissBanner() }
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    if model.activeSession != nil {
                        activeCard
                    } else {
                        Button {
                            guard let preset = model.presets.first(where: { $0.kind == .custom }) ?? model.presets.first else { return }
                            openSetup(preset: preset)
                        } label: {
                            Text("Start Focus")
                        }
                        .buttonStyle(FocusPrimaryButtonStyle())
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .accessibilityHint("Choose distractions and a duration")
                    }
                }

                Section("Your usual sessions") {
                    ForEach(model.presets) { preset in
                        Button {
                            openSetup(preset: preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(presetDetail(preset))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(preset.name), \(FocusDurationFormat.phrase(preset.duration)), \(SelectionDescription.headline(preset.selection))")
                        .accessibilityHint("Sets up this session")
                    }
                }

                Section("Today's focus") {
                    let stats = model.stats()
                    HStack(alignment: .firstTextBaseline) {
                        StatBlock(
                            title: "Time",
                            value: FocusDurationFormat.compact(stats.todayFocusTime),
                            spokenValue: FocusDurationFormat.phrase(stats.todayFocusTime)
                        )
                        StatBlock(
                            title: "Sessions",
                            value: "\(stats.todaySessionCount)",
                            spokenValue: "\(stats.todaySessionCount)"
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Image(systemName: "clock")
                    }
                    .accessibilityLabel("History")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(isPresented: $showSetup) {
                if let draft = model.draft {
                    FocusSetupView(draft: draft)
                }
            }
            .navigationDestination(isPresented: $showActive) {
                ActiveFocusView()
            }
            .sheet(isPresented: $showAuthorization) {
                NavigationStack {
                    OnboardingView(allowsDeferral: false)
                        .navigationTitle("Screen Time")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showAuthorization = false }
                            }
                        }
                }
            }
            .sheet(item: $summary, onDismiss: presentQueuedSetup) { session in
                FocusCompleteView(session: session, done: {
                    summary = nil
                    model.acknowledgeSummary()
                }, startAnother: {
                    resumePresetID = session.presetID
                    summary = nil
                    model.acknowledgeSummary()
                })
            }
            .onAppear {
                if summary == nil {
                    summary = model.pendingSummary
                }
            }
            .onChange(of: model.pendingSummary) { _, session in
                if let session {
                    summary = session
                }
            }
            .onChange(of: model.isAuthorized) { _, authorized in
                if authorized {
                    showAuthorization = false
                }
            }
            .alert("Couldn't start", isPresented: Binding(
                get: { setupError != nil },
                set: { if !$0 { setupError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(setupError ?? "")
            }
            .onAppear {
                if !didRouteToActive, model.activeSession != nil {
                    didRouteToActive = true
                    showActive = true
                }
            }
            .onChange(of: model.activeSession?.id) { _, id in
                if id != nil {
                    showActive = true
                }
            }
            .sensoryFeedback(.success, trigger: model.activeSession?.id)
        }
    }

    private var activeCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = model.remaining(at: context.date)
            Button {
                showActive = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.activeSession?.name ?? "Focus")
                        .font(.headline)
                    Text(FocusDurationFormat.clock(remaining))
                        .font(.system(.largeTitle, design: .rounded, weight: .light))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("\(SelectionDescription.headline(model.activeSession?.selection ?? PersistedSelection())) · Tap to open")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Active focus session")
            .accessibilityValue("\(model.activeSession?.name ?? "Focus"), \(FocusDurationFormat.spokenClock(remaining)) remaining")
        }
    }

    private func presetDetail(_ preset: FocusPreset) -> String {
        "\(FocusDurationFormat.compact(preset.duration)) · \(SelectionDescription.headline(preset.selection))"
    }

    private func presentQueuedSetup() {
        guard let id = resumePresetID else { return }
        resumePresetID = nil
        guard let preset = model.presets.first(where: { $0.id == id }) else { return }
        openSetup(preset: preset)
    }

    private func openSetup(preset: FocusPreset) {
        if model.activeSession != nil {
            showActive = true
            return
        }
        if !model.isAuthorized {
            showAuthorization = true
            return
        }
        do {
            try model.prepareDraft(from: preset)
            showSetup = true
        } catch {
            setupError = model.message(for: error)
        }
    }
}
