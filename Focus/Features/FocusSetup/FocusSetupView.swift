import FamilyControls
import SwiftUI

struct FocusSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var duration: TimeInterval
    @State private var familySelection: FamilyActivitySelection
    @State private var showPicker = false
    @State private var showCustomDuration = false
    @State private var hours = 0
    @State private var minutes = 25
    @State private var errorMessage: String?
    private let presetID: UUID

    init(draft: FocusDraft) {
        presetID = draft.presetID
        _name = State(initialValue: draft.name)
        _duration = State(initialValue: draft.duration)
        _familySelection = State(initialValue: draft.selection.familySelection())
        let total = Int(draft.duration)
        _hours = State(initialValue: total / 3600)
        _minutes = State(initialValue: (total % 3600) / 60)
        _showCustomDuration = State(initialValue: !FocusDuration.presets.contains(draft.duration))
    }

    private var selection: PersistedSelection {
        PersistedSelection(familySelection: familySelection)
    }

    private var durationIsValid: Bool {
        duration + 0.5 >= FocusDuration.minimum && duration <= FocusDuration.maximum + 0.5
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What should this session be called?")
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    TextField("Session name", text: $name)
                        .font(.title2)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > SessionNaming.maximumLength {
                                name = String(newValue.prefix(SessionNaming.maximumLength))
                            }
                        }
                    Text("Shown on the timer and in your history.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("What would you like to block?")
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Button {
                        showPicker = true
                    } label: {
                        Text(selection.hasSelection ? "Edit Apps" : "Choose Apps")
                    }
                    .buttonStyle(FocusSecondaryButtonStyle())
                    .accessibilityHint("Opens Apple's app picker")

                    Text(SelectionDescription.headline(selection))
                        .font(.headline)
                    if !SelectionDescription.breakdown(selection).isEmpty {
                        Text(SelectionDescription.breakdown(selection))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Uses Apple's picker. Focus cannot see the rest of your apps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if selection.hasSelection {
                        SelectionList(selection: selection)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("How long?")
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                        ForEach(FocusDuration.presets, id: \.self) { preset in
                            durationChip(title: FocusDurationFormat.compact(preset), selected: duration == preset && !showCustomDuration) {
                                duration = preset
                                showCustomDuration = false
                            }
                        }
                        durationChip(title: "Custom", selected: showCustomDuration) {
                            showCustomDuration = true
                            applyCustomDuration()
                        }
                    }
                    if showCustomDuration {
                        HStack {
                            Picker("Hours", selection: $hours) {
                                ForEach(0...6, id: \.self) { Text("\($0) h") }
                            }
                            .pickerStyle(.wheel)
                            Picker("Minutes", selection: $minutes) {
                                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { Text("\($0) m") }
                            }
                            .pickerStyle(.wheel)
                        }
                        .frame(height: 132)
                        .onChange(of: hours) { _, _ in applyCustomDuration() }
                        .onChange(of: minutes) { _, _ in applyCustomDuration() }
                        .accessibilityElement(children: .contain)
                    }
                    if !durationIsValid {
                        Text("Choose at least 15 minutes, and no more than 6 hours.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    BannerView(message: errorMessage) { self.errorMessage = nil }
                }
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Focus setup")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await start() }
            } label: {
                Text(model.isWorking ? "Starting…" : "Start Focus")
            }
            .buttonStyle(FocusPrimaryButtonStyle())
            .disabled(model.isWorking || !selection.hasSelection || !durationIsValid)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(.background)
        }
        .familyActivityPicker(
            headerText: "Choose what to block during this session.",
            footerText: "Focus only receives private tokens for what you select.",
            isPresented: $showPicker,
            selection: $familySelection
        )
    }

    private func durationChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? Color(.systemBackground) : Color.primary)
                .background(selected ? Color.primary : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func applyCustomDuration() {
        duration = TimeInterval(hours * 3600 + minutes * 60)
    }

    private func start() async {
        var draft = FocusDraft(preset: model.presets.first { $0.id == presetID } ?? FocusPreset.defaults[0])
        draft.name = name
        draft.duration = duration
        draft.selection = selection
        do {
            try await model.start(draft)
            dismiss()
        } catch {
            errorMessage = model.message(for: error)
        }
    }
}
