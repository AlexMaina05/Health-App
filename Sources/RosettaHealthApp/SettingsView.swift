import SwiftUI
import TipKit

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Privacy & Multi-Profile
    @AppStorage("ownerFirstName") private var firstName: String = ""
    @AppStorage("ownerLastName") private var lastName: String = ""
    @AppStorage("ownerDateOfBirth") private var dateOfBirthInterval: Double = 946684800 // 1 Gennaio 2000 default statico
    @State private var ownerFiscalCode: String = ""
    
    @State private var birthDate: Date = Date()
    
    // Sicurezza
    @AppStorage("isBiometricLockEnabled") private var isBiometricLockEnabled: Bool = true
    
    // User Experience / Feature Toggles
    @AppStorage("isCDSActive") private var isCDSActive: Bool = true
    @AppStorage("isOCREnabled") private var isOCREnabled: Bool = true
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dati Anagrafici (Proprietario)")) {
                    TextField("Nome", text: $firstName)
                        .textContentType(.givenName)
                    
                    TextField("Cognome", text: $lastName)
                        .textContentType(.familyName)
                    
                    DatePicker("Data di Nascita", selection: $birthDate, displayedComponents: .date)
                        .onChange(of: birthDate) { _, newDate in
                            dateOfBirthInterval = newDate.timeIntervalSince1970
                        }
                    
                    TextField("Codice Fiscale", text: $ownerFiscalCode)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                } footer: {
                    Text("RosettaHealth userà questi dati per garantire che i referti dei tuoi familiari non inquinino i tuoi grafici su Apple Salute.")
                }
                
                Section(header: Text("Sicurezza (Privacy Screen)")) {
                    Toggle(isOn: $isBiometricLockEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sblocco con FaceID / TouchID")
                                .font(.headline)
                            Text("Oscura i dati medici nello switcher delle app e richiedi l'autenticazione biometrica al ritorno.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.green)
                }
                
                Section {
                    Toggle(isOn: $isCDSActive) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifiche Medicina Preventiva")
                                .font(.headline)
                            Text("Ricevi un avviso se i tuoi parametri (es. Colesterolo) mostrano un trend in peggioramento nel tempo.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.purple)
                    
                    Toggle(isOn: $isOCREnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estrazione Ottica (OCR)")
                                .font(.headline)
                            Text("Usa l'intelligenza artificiale per recuperare dati da vecchi PDF privi di XML medico (Graceful Degradation).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.blue)
                    
                } header: {
                    Text("Esperienza Utente e Moduli")
                }
                
                Section(header: Text("Crediti & Sviluppo")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "swift")
                                .foregroundColor(.orange)
                            Text("RosettaHealth v3.0")
                                .font(.headline)
                        }
                        Text("Sviluppata interamente e orgogliosamente in Italia.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Link(destination: URL(string: "https://alexmaina.dev") ?? URL(fileURLWithPath: "")) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Alessandro Mainardi (Sito Web)")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/AlexMaina05") ?? URL(fileURLWithPath: "")) {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                            Text("GitHub (@AlexMaina05)")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fine") {
                        KeychainManager.shared.save(key: "ownerFiscalCode", value: ownerFiscalCode)
                        dismiss()
                    }
                }
            }
            .onAppear {
                try? Tips.configure([.displayFrequency(.immediate), .datastoreLocation(.applicationDefault)])
                birthDate = Date(timeIntervalSince1970: dateOfBirthInterval)
                ownerFiscalCode = KeychainManager.shared.read(key: "ownerFiscalCode") ?? ""
            }
        }
    }
}