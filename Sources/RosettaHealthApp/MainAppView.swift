import SwiftUI
import SwiftData

@available(iOS 17.0, *)
public struct MainAppView: View {
    public init() {}
    
    public var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square.fill")
                }
            
            FamilyVaultView()
                .tabItem {
                    Label("Family Vault", systemImage: "folder.badge.person.crop")
                }
        }
        // Inietta il contenitore SwiftData globale per il Vault
        .modelContainer(for: [VaultDocument.self])
    }
}
