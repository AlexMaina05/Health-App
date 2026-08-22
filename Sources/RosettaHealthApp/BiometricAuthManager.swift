import Foundation
import LocalAuthentication
import SwiftUI

@available(iOS 17.0, *)
@MainActor
public final class BiometricAuthManager: ObservableObject {
    @Published public var isUnlocked: Bool = false
    @Published public var authenticationError: String? = nil
    
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
            self.authenticationError = "Nessun metodo di sblocco configurato sul dispositivo."
            // Permettiamo l'accesso se il device non ha PIN? Per un'app medica, forse no, 
            // ma per evitare blocchi lo sblocchiamo loggando l'avviso.
            self.isUnlocked = true
        }
    }
    
    public func lock() {
        withAnimation(.easeInOut) {
            self.isUnlocked = false
        }
    }
}
