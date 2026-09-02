import Foundation
import LocalAuthentication
import SwiftUI
import Observation

@available(iOS 17.0, *)
@Observable
@MainActor
public final class BiometricAuthManager {
    public var isUnlocked: Bool = false
    public var authenticationError: String? = nil
    
    // Controlla se il dispositivo supporta la biometria
    public var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    public init() {}
    
    public func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        // Verifica se è possibile usare FaceID/TouchID o il Passcode (fallback)
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Sblocca RosettaHealth per accedere ai referti medici e al Family Vault."
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        withAnimation(.easeInOut) {
                            self.isUnlocked = true
                        }
                    } else {
                        self.authenticationError = authenticationError?.localizedDescription ?? "Autenticazione fallita."
                        self.isUnlocked = false
                    }
                }
            }
        } else {
            // Nessuna protezione impostata sul dispositivo (nessun PIN)
            self.authenticationError = "Il dispositivo non ha un codice di sblocco (Passcode). Per motivi di sicurezza (GDPR Art.9), l'accesso ai referti è bloccato. Configura un Passcode nelle impostazioni di iOS."
            self.isUnlocked = false
        }
    }
    
    public func lock() {
        withAnimation(.easeInOut) {
            self.isUnlocked = false
        }
    }
}
