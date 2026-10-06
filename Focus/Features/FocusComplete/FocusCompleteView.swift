import SwiftUI

struct FocusCompleteView: View {
    let session: FocusSession
    var done: () -> Void
    var startAnother: () -> Void

    private var protected: TimeInterval {
        session.actualDuration ?? session.plannedDuration
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.phase == .cancelled ? "Focus ended" : "Focus complete")
                            .font(.largeTitle.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        Text(session.name)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        summaryRow("Time", FocusDurationFormat.phrase(protected))
                        summaryRow("Blocked", SelectionDescription.headline(session.selection))
                        summaryRow("Interruptions", interruptionText)
                        if session.phase == .cancelled {
                            Text("Ended early")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(closingLine)
                        .font(.title3)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 12) {
                        Button("Start Another", action: startAnother)
                            .buttonStyle(FocusPrimaryButtonStyle())

                        Button("Done", action: done)
                            .buttonStyle(FocusSecondaryButtonStyle())
                    }
                }
                .padding(24)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sensoryFeedback(.success, trigger: session.id)
    }

    private var interruptionText: String {
        switch session.interruptionCount {
        case 0: return "0"
        case 1: return "1"
        default: return "\(session.interruptionCount)"
        }
    }

    private var closingLine: String {
        let time = FocusDurationFormat.phrase(protected)
        if session.phase == .cancelled {
            return "You focused for \(time), then ended the session."
        }
        return "You protected your attention for \(time)."
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
        .accessibilityElement(children: .combine)
    }
}
