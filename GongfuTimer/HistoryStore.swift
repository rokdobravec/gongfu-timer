import Foundation

/// One sitting with one tea: everything steeped from the first infusion
/// until the tea is changed, a new session is started, or a long break.
struct BrewSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var teaID: Tea.ID
    // Snapshots, so history survives renaming or deleting the tea.
    var teaName: String
    var category: TeaCategory
    var start: Date
    var lastSteep: Date
    var infusions: Int
    var totalSeconds: Int
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var sessions: [BrewSession] = [] { didSet { save() } }
    private var currentID: BrewSession.ID? {
        didSet { UserDefaults.standard.set(currentID?.uuidString, forKey: Self.currentKey) }
    }

    /// Steeps further apart than this start a new session.
    private let sessionGap: TimeInterval = 2 * 3600
    private static let currentKey = "currentSession.v1"

    private let fileURL: URL = {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "history.json")
    }()

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([BrewSession].self, from: data) {
            sessions = saved
        }
        if let raw = UserDefaults.standard.string(forKey: Self.currentKey) {
            currentID = UUID(uuidString: raw)
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedHistory"), sessions.isEmpty {
            seed()
        }
        #endif
    }

    /// Returns true when this steep started a new session.
    @discardableResult
    func recordSteep(tea: Tea, seconds: Int, at date: Date = .now) -> Bool {
        if let i = sessions.firstIndex(where: { $0.id == currentID }),
           sessions[i].teaID == tea.id,
           date.timeIntervalSince(sessions[i].lastSteep) < sessionGap {
            sessions[i].infusions += 1
            sessions[i].totalSeconds += seconds
            sessions[i].lastSteep = date
            return false
        } else {
            let session = BrewSession(teaID: tea.id, teaName: tea.name, category: tea.category,
                                      start: date, lastSteep: date, infusions: 1, totalSeconds: seconds)
            sessions.append(session)
            currentID = session.id
            return true
        }
    }

    /// The next recorded steep starts a fresh session.
    func endSession() {
        currentID = nil
    }

    func delete(_ session: BrewSession) {
        sessions.removeAll { $0.id == session.id }
        if currentID == session.id { currentID = nil }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    #if DEBUG
    /// Fake history for trying out the stats screen (launch with -seedHistory).
    private func seed() {
        let cal = Calendar.current
        let hours = [7, 8, 9, 10, 10, 11, 14, 15, 15, 16, 17, 20, 21]
        var result: [BrewSession] = []
        for dayOffset in 0..<60 where Int.random(in: 0..<10) < 7 {
            for _ in 0..<Int.random(in: 1...2) {
                let tea = Tea.presets.randomElement()!
                let day = cal.date(byAdding: .day, value: -dayOffset, to: .now)!
                let start = cal.date(bySettingHour: hours.randomElement()!, minute: Int.random(in: 0..<60), second: 0, of: day)!
                let n = Int.random(in: 3...tea.infusions)
                let total = (1...n).reduce(0) { $0 + tea.steepSeconds(for: $1) }
                result.append(BrewSession(teaID: tea.id, teaName: tea.name, category: tea.category, start: start,
                                          lastSteep: start.addingTimeInterval(Double(n) * 120), infusions: n, totalSeconds: total))
            }
        }
        sessions = result.sorted { $0.start < $1.start }
    }
    #endif
}
