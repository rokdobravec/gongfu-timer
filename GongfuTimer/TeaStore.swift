import Foundation

/// Keeps the tea library and the selected tea, persisted to UserDefaults.
@MainActor
final class TeaStore: ObservableObject {
    @Published var teas: [Tea] { didSet { save() } }
    @Published var selectedID: Tea.ID? {
        didSet { defaults.set(selectedID?.uuidString, forKey: Keys.selected) }
    }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let teas = "teas.v1"
        static let selected = "selectedTea.v1"
    }

    init() {
        if let data = defaults.data(forKey: Keys.teas),
           let saved = try? JSONDecoder().decode([Tea].self, from: data), !saved.isEmpty {
            teas = saved
        } else {
            teas = Tea.presets
        }
        if let raw = defaults.string(forKey: Keys.selected), let id = UUID(uuidString: raw),
           teas.contains(where: { $0.id == id }) {
            selectedID = id
        } else {
            selectedID = teas.first?.id
        }
    }

    var selectedTea: Tea? {
        teas.first { $0.id == selectedID } ?? teas.first
    }

    func upsert(_ tea: Tea) {
        if let i = teas.firstIndex(where: { $0.id == tea.id }) {
            teas[i] = tea
        } else {
            teas.append(tea)
        }
    }

    func delete(_ tea: Tea) {
        teas.removeAll { $0.id == tea.id }
        if selectedID == tea.id { selectedID = teas.first?.id }
    }

    /// Takes one session's worth of leaf off a tracked tea's stock.
    func consumeSession(of id: Tea.ID) {
        guard let i = teas.firstIndex(where: { $0.id == id }), let stock = teas[i].stockGrams else { return }
        teas[i].stockGrams = max(0, stock - teas[i].gramsPerSession)
    }

    func restorePresets() {
        let existing = Set(teas.map(\.name))
        teas.append(contentsOf: Tea.presets.filter { !existing.contains($0.name) })
    }

    private func save() {
        if let data = try? JSONEncoder().encode(teas) {
            defaults.set(data, forKey: Keys.teas)
        }
    }
}
