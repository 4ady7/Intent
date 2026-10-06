import SwiftUI

struct ActiveFocusView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 64
    @State private var confirmEnd = false
    @State private var endError: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = model.remaining(at: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.activeSession?.name ?? "Focus")
                            .font(.title2.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        Text(FocusDurationFormat.clock(remaining))
                            .font(.system(size: timerSize, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .contentTransition(reduceMotion ? .identity : .numericText())
                            .accessibilityLabel("Time remaining")
                            .accessibilityValue(FocusDurationFormat.spokenClock(remaining))
                        Text("remaining")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    if let session = model.activeSession {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Blocked")
                                .font(.title3.weight(.semibold))
                            Text(SelectionDescription.headline(session.selection))
                                .font(.body)
                                .foregroundStyle(.secondary)
                            if !SelectionDescription.breakdown(session.selection).isEmpty {
                                Text(SelectionDescription.breakdown(session.selection))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        SelectionList(selection: session.selection)
                    }

                    Text("Stay with it.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("End Focus") { confirmEnd = true }
                .buttonStyle(FocusSecondaryButtonStyle())
                .disabled(model.isWorking)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.background)
                .accessibilityHint("Asks you to confirm before restrictions are removed")
        }
        .confirmationDialog("End Focus?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End Session", role: .destructive) {
                Task { await end() }
            }
            Button("Keep Focusing", role: .cancel) {}
        } message: {
            Text("Your session has \(FocusDurationFormat.phrase(model.remaining(at: Date()))) remaining.")
        }
        .alert("Couldn't end the session", isPresented: Binding(
            get: { endError != nil },
            set: { if !$0 { endError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(endError ?? "")
        }
        .task(id: model.activeSession?.id) {
            while !Task.isCancelled {
                await model.reconcile()
                if model.activeSession == nil {
                    dismiss()
                    break
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func end() async {
        do {
            try await model.endSession()
            dismiss()
        } catch {
            endError = model.message(for: error)
        }
    }
}
