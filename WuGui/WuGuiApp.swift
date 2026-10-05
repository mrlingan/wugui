import SwiftUI

@main
struct WuGuiApp: App {
    @StateObject private var store = InventoryStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Palette.green)
                .preferredColorScheme(.light)
                .alert("记录未能加载", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                    Button("知道了", role: .cancel) {}
                } message: { Text(store.errorMessage ?? "") }
        }
    }
}
