import SwiftUI

struct InventoryView: View {
    @EnvironmentObject private var store: TeaStore
    @State private var restocking: Tea?
    @State private var adding: Tea?

    private var tracked: [Tea] {
        store.teas.filter(\.isTracked).sorted {
            ($0.category.sortIndex, $0.name) < ($1.category.sortIndex, $1.name)
        }
    }

    private var untracked: [Tea] { store.teas.filter { !$0.isTracked } }

    var body: some View {
        NavigationStack {
            List {
                if tracked.isEmpty {
                    Section {
                        ContentUnavailableView("Nothing in Stock", systemImage: "shippingbox",
                                               description: Text("Add a tea below or tap + to log how much you have."))
                    }
                } else {
                    Section { summary }
                    ForEach(TeaCategory.allCases) { category in
                        let teas = tracked.filter { $0.category == category }
                        if !teas.isEmpty {
                            Section(category.title) {
                                ForEach(teas) { row($0) }
                            }
                        }
                    }
                }
                if !untracked.isEmpty {
                    Section {
                        ForEach(untracked) { tea in
                            Button {
                                var copy = tea
                                copy.stockGrams = 0
                                restocking = copy
                            } label: {
                                HStack {
                                    Circle().fill(tea.category.color).frame(width: 8, height: 8)
                                    Text(tea.name).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                }
                            }
                        }
                    } header: {
                        Text("Not Tracked")
                    } footer: {
                        Text("Tap a tea to start tracking how much you have.")
                    }
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        adding = Tea(name: "", category: .oolong, temperatureC: 95, gramsPer100ml: 6,
                                     rinseSeconds: 5, firstSteep: 15, increment: 5, infusions: 8, stockGrams: 100)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Tea")
                }
            }
            .sheet(item: $restocking) { tea in
                StockEditorView(tea: tea) { store.upsert($0) }
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $adding) { tea in
                TeaEditorView(tea: tea) { store.upsert($0) }
            }
        }
    }

    private var summary: some View {
        let total = tracked.reduce(0) { $0 + ($1.stockGrams ?? 0) }
        let low = tracked.filter(\.isLowStock).count
        return HStack {
            stat("Total", formatGrams(total))
            Divider()
            stat("Teas", "\(tracked.count)")
            Divider()
            stat("Running Low", "\(low)", tint: low > 0 ? .orange : .primary)
        }
        .padding(.vertical, 4)
    }

    private func stat(_ title: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(tint)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ tea: Tea) -> some View {
        let stock = tea.stockGrams ?? 0
        let sessions = tea.sessionsLeft ?? 0
        return Button {
            restocking = tea
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(tea.category.color)
                    .frame(width: 6, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tea.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                    Text(sessions == 0 ? "Out of stock" : "About \(sessions) \(sessions == 1 ? "session" : "sessions") left")
                        .font(.caption)
                        .foregroundStyle(tea.isLowStock ? .orange : .secondary)
                }
                Spacer()
                Text(formatGrams(stock))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tea.isLowStock ? .orange : .primary)
            }
        }
        .swipeActions {
            Button {
                var copy = tea
                copy.stockGrams = nil
                store.upsert(copy)
            } label: {
                Label("Stop Tracking", systemImage: "eye.slash")
            }
            .tint(.gray)
        }
    }
}

/// Adjust how much of a tea is on hand.
struct StockEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var tea: Tea
    var onSave: (Tea) -> Void

    private var stock: Binding<Double> {
        Binding { tea.stockGrams ?? 0 } set: { tea.stockGrams = max(0, $0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("On hand")
                        Spacer()
                        TextField("Grams", value: stock, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        Text("g").foregroundStyle(.secondary)
                    }
                    .font(.title3.weight(.semibold))
                    HStack {
                        ForEach([-5.0, 25, 50, 100], id: \.self) { amount in
                            Button(amount < 0 ? "−\(Int(-amount))g" : "+\(Int(amount))g") {
                                stock.wrappedValue += amount
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .font(.footnote.weight(.medium))
                } footer: {
                    Text("Use the buttons when you buy more or to correct the amount.")
                }
                Section {
                    Stepper("\(formatGrams(tea.gramsPerSession)) per session", value: $tea.gramsPerSession, in: 1...20, step: 0.5)
                } footer: {
                    Text("Taken off the stock each time you start a new session with this tea.")
                }
            }
            .navigationTitle(tea.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(tea)
                        dismiss()
                    }
                }
            }
        }
    }
}

extension TeaCategory {
    var sortIndex: Int { TeaCategory.allCases.firstIndex(of: self) ?? 0 }
}
