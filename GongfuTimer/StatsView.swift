import Charts
import SwiftUI

enum StatsRange: String, CaseIterable, Identifiable {
    case week = "Week", month = "Month", year = "Year", all = "All"

    var id: String { rawValue }

    var start: Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        switch self {
        case .week: return cal.date(byAdding: .day, value: -6, to: today)
        case .month: return cal.date(byAdding: .day, value: -29, to: today)
        case .year: return cal.date(byAdding: .month, value: -11, to: cal.dateInterval(of: .month, for: today)!.start)
        case .all: return nil
        }
    }

    /// Bucket size for the activity chart.
    var unit: Calendar.Component {
        switch self {
        case .week, .month: .day
        case .year, .all: .month
        }
    }
}

struct StatsView: View {
    @EnvironmentObject private var history: HistoryStore
    @State private var range: StatsRange = .month

    private var sessions: [BrewSession] {
        guard let start = range.start else { return history.sessions }
        return history.sessions.filter { $0.start >= start }
    }

    /// Only the tea types that appear, so the legend stays short.
    private var categories: [TeaCategory] {
        let present = Set(sessions.map(\.category))
        return TeaCategory.allCases.filter(present.contains)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Range", selection: $range) {
                        ForEach(StatsRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if sessions.isEmpty {
                        ContentUnavailableView("No Data", systemImage: "chart.bar",
                                               description: Text("Brew some tea and your stats will appear here."))
                            .padding(.top, 40)
                    } else {
                        summary
                        card("Activity", subtitle: "Sessions per \(range.unit == .day ? "day" : "month")") { activityChart }
                        card("Time of Day", subtitle: "When you brew") { hourChart }
                        card("Favourite Teas", subtitle: "By number of sessions") { topTeasChart }
                        card("Tea Types", subtitle: nil) { categoryChart }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stats")
        }
    }

    // MARK: Summary

    private var summary: some View {
        let infusions = sessions.reduce(0) { $0 + $1.infusions }
        let seconds = sessions.reduce(0) { $0 + $1.totalSeconds }
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            tile("Sessions", "\(sessions.count)", icon: "cup.and.saucer.fill")
            tile("Infusions", "\(infusions)", icon: "drop.fill")
            tile("Steep Time", formatDuration(seconds), icon: "timer")
            tile("Streak", "\(streak) \(streak == 1 ? "day" : "days")", icon: "flame.fill")
            tile("Favourite", favouriteTea ?? "–", icon: "heart.fill")
            tile("Per Week", String(format: "%.1f", sessionsPerWeek), icon: "calendar")
        }
    }

    private func tile(_ title: String, _ value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Charts

    private var activityChart: some View {
        Chart(sessions) { s in
            BarMark(x: .value("Date", s.start, unit: range.unit),
                    y: .value("Sessions", 1))
                .foregroundStyle(by: .value("Type", s.category.title))
        }
        .chartForegroundStyleScale(domain: categories.map(\.title), range: categories.map(\.color))
        .chartLegend(.hidden)
        .frame(height: 180)
    }

    private var hourChart: some View {
        let cal = Calendar.current
        let reference = cal.startOfDay(for: .now)
        return Chart(sessions) { s in
            let hour = cal.component(.hour, from: s.start)
            BarMark(x: .value("Hour", cal.date(byAdding: .hour, value: hour, to: reference)!, unit: .hour),
                    y: .value("Sessions", 1))
                .foregroundStyle(by: .value("Type", s.category.title))
        }
        .chartForegroundStyleScale(domain: categories.map(\.title), range: categories.map(\.color))
        .chartXScale(domain: reference...cal.date(byAdding: .day, value: 1, to: reference)!)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartLegend(.hidden)
        .frame(height: 160)
    }

    private var topTeasChart: some View {
        let counts = Dictionary(grouping: sessions, by: \.teaName)
            .map { (name: $0.key, category: $0.value[0].category, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(6)
        return Chart(Array(counts), id: \.name) { item in
            BarMark(x: .value("Sessions", item.count), y: .value("Tea", item.name))
                .foregroundStyle(item.category.color)
                .annotation(position: .trailing) {
                    Text("\(item.count)").font(.caption).foregroundStyle(.secondary)
                }
        }
        .chartXAxis(.hidden)
        .frame(height: CGFloat(counts.count) * 36)
    }

    private var categoryChart: some View {
        let counts = categories.map { c in (category: c, count: sessions.filter { $0.category == c }.count) }
        return HStack(spacing: 20) {
            Chart(counts, id: \.category) { item in
                SectorMark(angle: .value("Sessions", item.count), innerRadius: .ratio(0.6), angularInset: 1.5)
                    .foregroundStyle(item.category.color)
            }
            .frame(width: 130, height: 130)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(counts, id: \.category) { item in
                    HStack(spacing: 6) {
                        Circle().fill(item.category.color).frame(width: 8, height: 8)
                        Text(item.category.title).font(.caption)
                        Spacer(minLength: 4)
                        Text("\(Int((Double(item.count) / Double(sessions.count) * 100).rounded()))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private func card<Content: View>(_ title: String, subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Numbers

    private var favouriteTea: String? {
        Dictionary(grouping: sessions, by: \.teaName).max { $0.value.count < $1.value.count }?.key
    }

    private var sessionsPerWeek: Double {
        guard let first = sessions.map(\.start).min() else { return 0 }
        let from = range.start ?? first
        let weeks = max(1, Date.now.timeIntervalSince(from) / (7 * 86400))
        return Double(sessions.count) / weeks
    }

    /// Consecutive days with tea, ending today (or yesterday, if today has none yet).
    private var streak: Int {
        let cal = Calendar.current
        let days = Set(history.sessions.map { cal.startOfDay(for: $0.start) })
        var day = cal.startOfDay(for: .now)
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while days.contains(day) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
}
