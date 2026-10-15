import SwiftUI

@main
struct GongfuTimerApp: App {
    @StateObject private var store = TeaStore()
    @StateObject private var history = HistoryStore()
    @StateObject private var pro = ProStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Brew", systemImage: "timer") }
                ProGate(title: "History") { HistoryView() }
                    .tabItem { Label("History", systemImage: "list.bullet.rectangle") }
                ProGate(title: "Stats") { StatsView() }
                    .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
                ProGate(title: "Inventory") { InventoryView() }
                    .tabItem { Label("Inventory", systemImage: "shippingbox") }
            }
            .environmentObject(store)
            .environmentObject(history)
            .environmentObject(pro)
            .onAppear { SteepTimer.requestNotificationPermission() }
        }
    }
}
