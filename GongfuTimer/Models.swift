import SwiftUI

enum TeaCategory: String, Codable, CaseIterable, Identifiable {
    case green, white, yellow, oolong, roastedOolong, black, sheng, shou, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .green: "Green"
        case .white: "White"
        case .yellow: "Yellow"
        case .oolong: "Oolong"
        case .roastedOolong: "Roasted Oolong"
        case .black: "Black (Hong Cha)"
        case .sheng: "Sheng Pu-erh"
        case .shou: "Shou Pu-erh"
        case .other: "Other"
        }
    }

    var color: Color {
        switch self {
        case .green: Color(red: 0.42, green: 0.62, blue: 0.30)
        case .white: Color(red: 0.72, green: 0.70, blue: 0.55)
        case .yellow: Color(red: 0.85, green: 0.70, blue: 0.25)
        case .oolong: Color(red: 0.55, green: 0.65, blue: 0.35)
        case .roastedOolong: Color(red: 0.62, green: 0.40, blue: 0.20)
        case .black: Color(red: 0.62, green: 0.25, blue: 0.18)
        case .sheng: Color(red: 0.68, green: 0.55, blue: 0.25)
        case .shou: Color(red: 0.40, green: 0.22, blue: 0.15)
        case .other: Color(red: 0.45, green: 0.45, blue: 0.50)
        }
    }
}

struct Tea: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var category: TeaCategory
    var temperatureC: Int
    var gramsPer100ml: Double
    var rinseSeconds: Int          // 0 = no rinse
    var firstSteep: Int            // seconds
    var increment: Int             // seconds added each infusion
    var infusions: Int
    var notes: String = ""
    /// Grams on hand; nil means this tea isn't tracked in the inventory.
    var stockGrams: Double? = nil
    /// Leaf used up by one session, taken off the stock when a session starts.
    var gramsPerSession: Double = 5

    enum CodingKeys: String, CodingKey {
        case id, name, category, temperatureC, gramsPer100ml, rinseSeconds, firstSteep, increment, infusions,
             notes, stockGrams, gramsPerSession
    }

    var hasRinse: Bool { rinseSeconds > 0 }

    var isTracked: Bool { stockGrams != nil }

    /// The fields that shape the steep schedule; stock changes don't touch it.
    var schedule: [Int] { [rinseSeconds, firstSteep, increment, infusions] }

    /// Whole sessions left in stock, or nil when not tracked.
    var sessionsLeft: Int? {
        guard let stock = stockGrams, gramsPerSession > 0 else { return nil }
        return Int(stock / gramsPerSession)
    }

    var isLowStock: Bool { (sessionsLeft ?? .max) < 3 }

    /// Steep duration for an infusion number (1-based). Infusion 0 is the rinse.
    func steepSeconds(for infusion: Int) -> Int {
        if infusion == 0 { return rinseSeconds }
        return firstSteep + increment * (infusion - 1)
    }

    static let presets: [Tea] = [
        Tea(name: "Long Jing", category: .green, temperatureC: 80, gramsPer100ml: 4, rinseSeconds: 0, firstSteep: 15, increment: 5, infusions: 4,
            notes: "Lower temperature keeps it sweet and avoids bitterness."),
        Tea(name: "Bai Mu Dan", category: .white, temperatureC: 90, gramsPer100ml: 5, rinseSeconds: 0, firstSteep: 20, increment: 10, infusions: 10),
        Tea(name: "Tie Guan Yin", category: .oolong, temperatureC: 95, gramsPer100ml: 7, rinseSeconds: 5, firstSteep: 20, increment: 5, infusions: 10,
            notes: "Let the rolled leaves open up during the rinse."),
        Tea(name: "Dan Cong", category: .oolong, temperatureC: 95, gramsPer100ml: 6, rinseSeconds: 3, firstSteep: 5, increment: 3, infusions: 12,
            notes: "Very fragrant and can turn bitter fast; keep steeps short."),
        Tea(name: "Da Hong Pao", category: .roastedOolong, temperatureC: 100, gramsPer100ml: 7, rinseSeconds: 5, firstSteep: 10, increment: 5, infusions: 10),
        Tea(name: "Dian Hong", category: .black, temperatureC: 95, gramsPer100ml: 5, rinseSeconds: 0, firstSteep: 10, increment: 5, infusions: 8),
        Tea(name: "Young Sheng", category: .sheng, temperatureC: 95, gramsPer100ml: 6, rinseSeconds: 5, firstSteep: 8, increment: 4, infusions: 18),
        Tea(name: "Shou Pu-erh", category: .shou, temperatureC: 100, gramsPer100ml: 6, rinseSeconds: 10, firstSteep: 10, increment: 5, infusions: 15,
            notes: "Two quick rinses help clear out the earthy pile-fermentation taste."),
    ]
}

extension Tea {
    /// Tolerates teas saved before inventory fields existed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(TeaCategory.self, forKey: .category)
        temperatureC = try c.decode(Int.self, forKey: .temperatureC)
        gramsPer100ml = try c.decode(Double.self, forKey: .gramsPer100ml)
        rinseSeconds = try c.decode(Int.self, forKey: .rinseSeconds)
        firstSteep = try c.decode(Int.self, forKey: .firstSteep)
        increment = try c.decode(Int.self, forKey: .increment)
        infusions = try c.decode(Int.self, forKey: .infusions)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        stockGrams = try c.decodeIfPresent(Double.self, forKey: .stockGrams)
        gramsPerSession = try c.decodeIfPresent(Double.self, forKey: .gramsPerSession) ?? 5
    }
}

func formatGrams(_ g: Double) -> String {
    "\(g.formatted(.number.precision(.fractionLength(0...1))))g"
}
