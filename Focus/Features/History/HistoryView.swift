import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let stats = model.stats()
        List {
            Section {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 20) {
                    GridRow {
                        StatBlock(title: "Today", value: FocusDurationFormat.compact(stats.todayFocusTime), spokenValue: FocusDurationFormat.phrase(stats.todayFocusTime))
                        StatBlock(title: "This Week", value: FocusDurationFormat.compact(stats.weekFocusTime), spokenValue: FocusDurationFormat.phrase(stats.weekFocusTime))
                    }
                    GridRow {
                        StatBlock(title: "Sessions", value: "\(stats.completedCount + stats.cancelledCount)", spokenValue: "\(stats.completedCount + stats.cancelledCount) finished")
                        StatBlock(
                            title: "Longest",
                            value: stats.longestCompleted.map(FocusDurationFormat.compact) ?? "—",
                            spokenValue: stats.longestCompleted.map(FocusDurationFormat.phrase) ?? "None yet"
                        )
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Details") {
                detailRow("Total focus", FocusDurationFormat.phrase(stats.totalFocusTime))
                detailRow("Completed", "\(stats.completedCount)")
                detailRow("Ended early", "\(stats.cancelledCount)")
                detailRow("Average", stats.averageCompletedLength.map(FocusDurationFormat.phrase) ?? "—")
                detailRow("Completion", stats.completionRate.map { percent($0) } ?? "—")
            }

            if grouped.isEmpty {
                Section {
                    Text("No sessions yet. Completed and ended sessions will appear here.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(grouped, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.sessions) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(session.startDate.formatted(date: .omitted, time: .shortened)) — \(session.name) — \(FocusDurationFormat.compact(session.actualDuration ?? session.plannedDuration))")
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(session.phase == .cancelled ? "Ended early" : "Completed")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
    }

    private var grouped: [(title: String, sessions: [FocusSession])] {
        let calendar = Calendar.current
        let finished = model.history
            .filter { $0.phase == .completed || $0.phase == .cancelled }
            .sorted { $0.startDate > $1.startDate }
        let titles = finished.map { dayTitle(for: $0.startDate, calendar: calendar) }
        var groups: [(title: String, sessions: [FocusSession])] = []
        for (session, title) in zip(finished, titles) {
            if let index = groups.lastIndex(where: { $0.title == title }), index == groups.count - 1 {
                groups[index].sessions.append(session)
            } else {
                groups.append((title, [session]))
            }
        }
        return groups
    }

    private func dayTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func percent(_ rate: Double) -> String {
        "\(Int((rate * 100).rounded()))%"
    }
}
