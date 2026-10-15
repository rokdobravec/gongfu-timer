import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore

    private var days: [(day: Date, sessions: [BrewSession])] {
        let grouped = Dictionary(grouping: history.sessions) { Calendar.current.startOfDay(for: $0.start) }
        return grouped
            .map { ($0.key, $0.value.sorted { $0.start > $1.start }) }
            .sorted { $0.0 > $1.0 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if history.sessions.isEmpty {
                    ContentUnavailableView("No Sessions Yet", systemImage: "cup.and.saucer",
                                           description: Text("Finish a steep on the Brew tab and it will show up here."))
                } else {
                    List {
                        ForEach(days, id: \.day) { day in
                            Section(dayTitle(day.day)) {
                                ForEach(day.sessions) { session in
                                    row(session)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func row(_ session: BrewSession) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(session.category.color)
                .frame(width: 6, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.teaName).font(.body.weight(.medium))
                Text("\(session.infusions) \(session.infusions == 1 ? "infusion" : "infusions") · \(formatDuration(session.totalSeconds)) steeped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(session.start, format: .dateTime.hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .swipeActions {
            Button(role: .destructive) {
                history.delete(session)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

func formatDuration(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    if h > 0 { return "\(h)h \(m)m" }
    if m > 0 { return s == 0 ? "\(m)m" : "\(m)m \(s)s" }
    return "\(s)s"
}
