import SwiftUI
import SwiftData
import CoreSpotlight

@available(iOS 17.0, *)
public struct MainAppView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("isBiometricLockEnabled") private var isBiometricLockEnabled: Bool = true
    
    @StateObject private var authManager = BiometricAuthManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Int = 0
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                TabView(selection: $selectedTab) {
                    ContentView()
                        .tabItem {
                            Label("Dashboard", systemImage: "heart.text.square.fill")
                        }
                    
                    FamilyVaultView()
                        .tabItem {
                            Label("Family Vault", systemImage: "folder.badge.person.crop")
                        }
                }
                .modelContainer(for: [VaultDocument.self])
                // Privacy Screen (Sfuoca l'app sotto il lucchetto)
                
                .disabled(isBiometricLockEnabled && !authManager.isUnlocked)
                .overlay { if isBiometricLockEnabled && !authManager.isUnlocked { Color.black.ignoresSafeArea() } }
            } else {
                OnboardingView()
            }
            
            // Lock Screen Overlay
            if hasCompletedOnboarding && isBiometricLockEnabled && !authManager.isUnlocked {
                VStack(spacing: 24) {
                    Image(systemName: "faceid")
                        .font(.system(size: 70))
                        .foregroundColor(.purple)
                        .symbolEffect(.pulse)
                    
                    Text("RosettaHealth è bloccata")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Button(action: {
                        authManager.authenticate()
                    }) {
                        Text("Sblocca per continuare")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 250)
                            .background(Color.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    if let error = authManager.authenticationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // Schedula l'esecuzione in background quando l'app va in sleep
                BackgroundTaskManager.shared.scheduleNextProcessing()
            }
            
            if isBiometricLockEnabled && hasCompletedOnboarding {
                if newPhase == .inactive || newPhase == .background {
                    // Blocca l'app appena va in background per attivare il Privacy Screen nello switcher
                    authManager.lock()
                } else if newPhase == .active {
                    // Richiede FaceID al ritorno in foreground
                    if !authManager.isUnlocked {
                        authManager.authenticate()
                    }
                }
            }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
            if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                // L'utente ha toccato un referto da Spotlight
                // Navighiamo al Vault
                selectedTab = 1
                
                // Opzionale: passare l'ID a FamilyVaultView per espandere o evidenziare il referto
                // Log rimosso per privacy e pulizia
            }
        }
        .onAppear {
            if isBiometricLockEnabled && hasCompletedOnboarding {
                authManager.authenticate()
            }
        }
    }
}
