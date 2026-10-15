import SwiftUI

/// Shows `content` for Pro users and the upgrade screen for everyone else.
struct ProGate<Content: View>: View {
    @EnvironmentObject private var pro: ProStore
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        if pro.isPro {
            content
        } else {
            NavigationStack {
                PaywallView()
                    .navigationTitle(title)
            }
        }
    }
}

struct PaywallView: View {
    @EnvironmentObject private var pro: ProStore

    private let accent = TeaCategory.green.color

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(accent)
                    Text("Gongfu Timer Pro")
                        .font(.system(.title, design: .serif, weight: .semibold))
                    Text("Your timer stays free forever. Pro adds a tea journal on top.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 18) {
                    feature("list.bullet.rectangle", "History",
                            "Every session logged with tea, time, infusions and steep time.")
                    feature("chart.bar.xaxis", "Stats",
                            "See what you drink, when you drink it, your favourites and streaks.")
                    feature("shippingbox", "Inventory",
                            "Track how many grams you have; each session is taken off automatically.")
                }
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                Text("Sessions you brew are already being saved, so your history and stats will be there as soon as you unlock.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            // Pinned so the buy button is visible without scrolling on small phones.
            VStack(spacing: 10) {
                Button {
                    Task { await pro.purchase() }
                } label: {
                    Group {
                        if pro.isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text("Unlock Pro for \(pro.product?.displayPrice ?? "€4.99")")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(accent)
                .disabled(pro.isPurchasing)

                Text("One-time purchase. No subscription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Restore Purchase") {
                    Task { await pro.restore() }
                }
                .font(.footnote)
                .tint(accent)
                .disabled(pro.isPurchasing)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .alert("Purchase", isPresented: Binding {
            pro.errorMessage != nil
        } set: {
            if !$0 { pro.errorMessage = nil }
        }) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pro.errorMessage ?? "")
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
