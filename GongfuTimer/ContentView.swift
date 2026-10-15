import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TeaStore
    @StateObject private var timer = SteepTimer()

    /// 0 is the rinse (when the tea has one), 1... are the infusions.
    @State private var infusion = 1
    /// Per-infusion tweak in seconds, reset when moving to another infusion.
    @State private var adjustment = 0
    @State private var showingLibrary = false
    /// onAppear fires again on every tab switch; only prepare the first time.
    @State private var didPrepare = false
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var pro: ProStore

    var body: some View {
        NavigationStack {
            if let tea = store.selectedTea {
                session(for: tea)
                    .onAppear {
                        guard !didPrepare else { return }
                        didPrepare = true
                        resetSession(for: tea)
                    }
                    .onChange(of: tea.id) {
                        history.endSession()
                        resetSession(for: tea)
                    }
                    .onChange(of: tea.schedule) { resetSession(for: tea) }
                    .onChange(of: timer.state) { _, state in
                        // Rinses aren't drunk, so they don't count.
                        if state == .finished && infusion > 0 {
                            if history.recordSteep(tea: tea, seconds: Int(timer.duration)) {
                                if pro.isPro { store.consumeSession(of: tea.id) }
                            }
                        }
                    }
            } else {
                ContentUnavailableView {
                    Label("No teas", systemImage: "cup.and.saucer")
                } actions: {
                    Button("Open Tea Library") { showingLibrary = true }
                }
            }
        }
        .sheet(isPresented: $showingLibrary) {
            TeaLibraryView()
        }
    }

    // MARK: Session

    private func session(for tea: Tea) -> some View {
        GeometryReader { geo in
            // iPhone SE / mini-class screens get a tighter layout.
            let compact = geo.size.height < 700
            VStack(spacing: compact ? 12 : 20) {
                header(for: tea, compact: compact)
                infusionStrip(for: tea)
                dial(for: tea)
                adjustRow
                controls(for: tea)
            }
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [tea.category.color.opacity(0.18), Color(.systemBackground)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .tint(tea.category.color)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingLibrary = true
                } label: {
                    Image(systemName: "books.vertical")
                }
                .accessibilityLabel("Tea Library")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(for tea: Tea, compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 8) {
            Button {
                showingLibrary = true
            } label: {
                HStack(spacing: 6) {
                    Text(tea.name)
                        .font(.system(compact ? .title : .largeTitle, design: .serif, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Image(systemName: "chevron.down")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            Text(tea.category.title)
                .font(.subheadline)
                .foregroundStyle(tea.category.color)
            HStack(spacing: 12) {
                Label("\(tea.temperatureC)°C", systemImage: "thermometer.medium")
                Label("\(formatGrams(tea.gramsPerSession)) / session", systemImage: "leaf")
                if tea.hasRinse {
                    Label("Rinse", systemImage: "drop")
                }
                if pro.isPro, let stock = tea.stockGrams {
                    Label("\(formatGrams(stock)) left", systemImage: "shippingbox")
                        .foregroundStyle(tea.isLowStock ? .orange : .secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .font(.footnote)
            .foregroundStyle(.secondary)
            if !compact && !tea.notes.isEmpty {
                Text(tea.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.top, 4)
    }

    private func infusionStrip(for tea: Tea) -> some View {
        let first = tea.hasRinse ? 0 : 1
        let last = max(tea.infusions, infusion)
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(first...last, id: \.self) { n in
                        let isCurrent = n == infusion
                        let isDone = n < infusion
                        Button {
                            go(to: n, tea: tea)
                        } label: {
                            VStack(spacing: 2) {
                                Text(n == 0 ? "R" : "\(n)")
                                    .font(.headline)
                                Text(shortTime(tea.steepSeconds(for: n)))
                                    .font(.caption2)
                            }
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isCurrent ? tea.category.color : Color(.secondarySystemBackground))
                            )
                            .foregroundStyle(isCurrent ? .white : (isDone ? .secondary : .primary))
                            .opacity(isDone ? 0.6 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(timer.isRunning)
                        .id(n)
                    }
                }
                .padding(.horizontal, 2)
            }
            .onChange(of: infusion) { _, n in
                withAnimation { proxy.scrollTo(n, anchor: .center) }
            }
        }
    }

    private func dial(for tea: Tea) -> some View {
        TimelineView(.animation(paused: !timer.isRunning)) { context in
            let remaining = timer.remaining(at: context.date)
            let progress = timer.progress(at: context.date)
            GeometryReader { geo in
                // Everything scales with the ring so the labels always sit inside it.
                let size = min(geo.size.width, geo.size.height)
                let line = max(10, size * 0.06)
                ZStack {
                    Circle()
                        .stroke(tea.category.color.opacity(0.15), lineWidth: line)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(tea.category.color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: size * 0.015) {
                        Text(infusion == 0 ? "Rinse" : "Infusion \(infusion)")
                            .font(.system(size: size * 0.07, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(bigTime(remaining))
                            .font(.system(size: size * 0.27, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                        Text(statusText(remaining: remaining))
                            .font(.system(size: size * 0.06))
                            .foregroundStyle(timer.state == .finished ? tea.category.color : .secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: size * 0.6)
                }
                .frame(width: size, height: size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minHeight: 150, maxHeight: 340)
            .contentShape(Circle())
            .onTapGesture { primaryAction(tea: tea) }
        }
    }

    private var adjustRow: some View {
        HStack(spacing: 24) {
            Button { adjust(by: -5) } label: {
                Label("5s", systemImage: "minus")
            }
            Button("Reset") { adjust(by: -adjustment) }
                .font(.footnote)
                .opacity(adjustment == 0 ? 0 : 1)
            Button { adjust(by: 5) } label: {
                Label("5s", systemImage: "plus")
            }
        }
        .buttonStyle(.bordered)
        .disabled(timer.state != .idle)
    }

    private func controls(for tea: Tea) -> some View {
        VStack(spacing: 14) {
            Button {
                primaryAction(tea: tea)
            } label: {
                Label(primaryTitle, systemImage: primaryIcon)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            HStack {
                Button {
                    go(to: infusion - 1, tea: tea)
                } label: {
                    Label("Previous", systemImage: "backward.end")
                }
                .disabled(timer.isRunning || infusion <= (tea.hasRinse ? 0 : 1))
                Spacer()
                Button(role: .destructive) {
                    history.endSession()
                    resetSession(for: tea)
                } label: {
                    Label("New Session", systemImage: "arrow.counterclockwise")
                }
                .disabled(timer.isRunning)
                Spacer()
                Button {
                    go(to: infusion + 1, tea: tea)
                } label: {
                    Label("Skip", systemImage: "forward.end")
                }
                .disabled(timer.isRunning)
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .padding(.horizontal, 24)
        }
    }

    // MARK: Actions

    private var primaryTitle: String {
        switch timer.state {
        case .idle: infusion == 0 ? "Start Rinse" : "Start Steep"
        case .running: "Pause"
        case .paused: "Resume"
        case .finished: "Next Infusion"
        }
    }

    private var primaryIcon: String {
        switch timer.state {
        case .idle, .paused: "play.fill"
        case .running: "pause.fill"
        case .finished: "forward.fill"
        }
    }

    private func primaryAction(tea: Tea) {
        switch timer.state {
        case .idle, .paused:
            timer.start(teaName: tea.name, label: infusion == 0 ? "Rinse" : "Infusion \(infusion)")
        case .running:
            timer.pause()
        case .finished:
            go(to: infusion + 1, tea: tea)
        }
    }

    private func resetSession(for tea: Tea) {
        go(to: tea.hasRinse ? 0 : 1, tea: tea)
    }

    private func go(to n: Int, tea: Tea) {
        infusion = max(tea.hasRinse ? 0 : 1, n)
        adjustment = 0
        timer.prepare(seconds: steepSeconds(tea: tea))
    }

    private func adjust(by delta: Int) {
        guard let tea = store.selectedTea else { return }
        let base = tea.steepSeconds(for: infusion)
        adjustment = max(1 - base, adjustment + delta)
        timer.prepare(seconds: steepSeconds(tea: tea))
    }

    private func steepSeconds(tea: Tea) -> Int {
        max(1, tea.steepSeconds(for: infusion) + adjustment)
    }

    // MARK: Formatting

    private func statusText(remaining: TimeInterval) -> String {
        switch timer.state {
        case .idle: adjustment == 0 ? "Tap to start" : "Adjusted \(adjustment > 0 ? "+" : "")\(adjustment)s"
        case .running: "Steeping…"
        case .paused: "Paused"
        case .finished: "Pour now!"
        }
    }

    private func bigTime(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return s < 60 ? "\(s)" : String(format: "%d:%02d", s / 60, s % 60)
    }

    private func shortTime(_ s: Int) -> String {
        s < 60 ? "\(s)s" : String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview {
    ContentView().environmentObject(TeaStore()).environmentObject(HistoryStore()).environmentObject(ProStore())
}
