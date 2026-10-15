import SwiftUI

struct TeaLibraryView: View {
    @EnvironmentObject private var store: TeaStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Tea?

    var body: some View {
        NavigationStack {
            List {
                ForEach(TeaCategory.allCases) { category in
                    let teas = store.teas.filter { $0.category == category }
                    if !teas.isEmpty {
                        Section(category.title) {
                            ForEach(teas) { tea in
                                row(tea)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tea Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Restore Default Teas", systemImage: "arrow.uturn.backward") {
                            store.restorePresets()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editing = Tea(name: "", category: .oolong, temperatureC: 95, gramsPer100ml: 6,
                                      rinseSeconds: 5, firstSteep: 15, increment: 5, infusions: 8)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Tea")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editing) { tea in
                TeaEditorView(tea: tea) { store.upsert($0) }
            }
        }
    }

    private func row(_ tea: Tea) -> some View {
        Button {
            store.selectedID = tea.id
            dismiss()
        } label: {
            HStack {
                Circle()
                    .fill(tea.category.color)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tea.name).font(.body.weight(.medium))
                    Text("\(tea.temperatureC)°C · \(tea.firstSteep)s +\(tea.increment)s · \(tea.infusions) infusions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if tea.id == store.selectedTea?.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(tea.category.color)
                }
            }
            .foregroundStyle(.primary)
        }
        .swipeActions {
            Button(role: .destructive) {
                store.delete(tea)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                editing = tea
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editing = tea }
            Button("Delete", systemImage: "trash", role: .destructive) { store.delete(tea) }
        }
    }
}

struct TeaEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var pro: ProStore
    @State var tea: Tea
    var onSave: (Tea) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $tea.name)
                    Picker("Type", selection: $tea.category) {
                        ForEach(TeaCategory.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section("Brewing") {
                    Stepper("Water \(tea.temperatureC)°C", value: $tea.temperatureC, in: 60...100, step: 5)
                    Stepper("Leaf \(formatGrams(tea.gramsPerSession)) per session", value: $tea.gramsPerSession, in: 1...20, step: 0.5)
                    Stepper(tea.hasRinse ? "Rinse \(tea.rinseSeconds)s" : "No rinse", value: $tea.rinseSeconds, in: 0...30)
                }
                Section {
                    Stepper("First steep \(tea.firstSteep)s", value: $tea.firstSteep, in: 1...300)
                    Stepper("Add \(tea.increment)s each time", value: $tea.increment, in: 0...120)
                    Stepper("\(tea.infusions) infusions", value: $tea.infusions, in: 1...30)
                } header: {
                    Text("Infusions")
                } footer: {
                    Text(schedule)
                }
                if pro.isPro {
                    Section {
                        Toggle("Track in inventory", isOn: Binding {
                            tea.isTracked
                        } set: {
                            tea.stockGrams = $0 ? (tea.stockGrams ?? 0) : nil
                        })
                        if tea.isTracked {
                            HStack {
                                Text("On hand")
                                Spacer()
                                TextField("Grams", value: Binding { tea.stockGrams ?? 0 } set: { tea.stockGrams = max(0, $0) },
                                          format: .number.precision(.fractionLength(0...1)))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 100)
                                Text("g").foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Inventory")
                    }
                }
                Section("Notes") {
                    TextField("Tasting notes, tips…", text: $tea.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(tea.name.isEmpty ? "New Tea" : tea.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        tea.name = tea.name.trimmingCharacters(in: .whitespaces)
                        onSave(tea)
                        dismiss()
                    }
                    .disabled(tea.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var schedule: String {
        var parts: [String] = []
        if tea.hasRinse { parts.append("rinse \(tea.rinseSeconds)s") }
        parts += (1...tea.infusions).map { "\(tea.steepSeconds(for: $0))s" }
        return "Schedule: " + parts.joined(separator: " → ")
    }
}
