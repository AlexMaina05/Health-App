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
    @AppStorage("isProUnlocked") private var isProUnlocked: Bool = false
    @AppStorage("appThemeName") private var appThemeName: String = AppTheme.blue.rawValue
    @State private var showProAlert = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                proSection
                personalDataSection
                securitySection
                privacySection
                experienceSection
                creditsSection
            }
            .alert("RosettaEdge PRO Richiesto", isPresented: $showProAlert) {
                Button("Sblocca Ora", role: .none) {
                    // Future IAP logic or scroll to pro toggle
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("La personalizzazione del tema è una funzionalità esclusiva della versione PRO. Sbloccala per scegliere il colore che si adatta di più al tuo stile.")
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fine") {
                        _ = KeychainManager.shared.save(key: "ownerFiscalCode", value: ownerFiscalCode)
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

    private var appearanceSection: some View {
        Section(header: Text("Aspetto (Esclusiva PRO)")) {
            Picker("Colore Tema", selection: Binding(
                get: { appThemeName },
                set: { newValue in
                    if isProUnlocked {
                        appThemeName = newValue
                    } else {
                        showProAlert = true
                    }
                }
            )) {
                ForEach(AppTheme.allCases) { theme in
                    HStack {
                        Circle().fill(theme.color).frame(width: 14, height: 14)
                        Text(theme.rawValue)
                    }
                    .tag(theme.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme(rawValue: appThemeName)?.color ?? .blue)
        }
    }

    private var proSection: some View {
        Section(header: Text("RosettaEdge PRO"), footer: Text("Sblocca il Family Vault per gestire referti illimitati per tutta la tua famiglia.")) {
            Toggle(isOn: $isProUnlocked) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("Sblocca PRO (Family Vault)")
                        .fontWeight(.semibold)
                }
            }
            .tint(.yellow)
        }
    }

    private var personalDataSection: some View {
        Section {
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
        } header: {
            Text("Dati Anagrafici (Proprietario)")
        } footer: {
            Text("RosettaEdge userà questi dati per garantire che i referti dei tuoi familiari non inquinino i tuoi grafici su Apple Salute.")
        }
    }

    private var securitySection: some View {
        Section(header: Text("Sicurezza (Privacy Screen)")) {
            Toggle(isOn: $isBiometricLockEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sblocco con FaceID / TouchID")
                        .font(.headline)
                    Text("Oscura i dati medici nello switcher delle app e richiedi l'autenticazione biometrica al ritorno.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.green)
        }
    }

    private var privacySection: some View {
        Section(header: Text("Privacy e Sovranità dei Dati (GDPR Art. 9)"), footer: Text("RosettaEdge rispetta la politica Zero-Cloud. L'elaborazione e la memorizzazione avvengono al 100% in locale su questo dispositivo in conformità all'Articolo 9 del GDPR. Nessun dato clinico o biometrico viene trasmesso su cloud o server esterni.")) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Archiviazione 100% On-Device")
                        .font(.headline)
                    Text("Database SwiftData locale isolato")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Zero-Cloud")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
            .padding(.vertical, 2)
        }
    }

    private var experienceSection: some View {
        Section {
            Toggle(isOn: $isCDSActive) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifiche Medicina Preventiva")
                        .font(.headline)
                    Text("Ricevi un avviso se i tuoi parametri (es. Colesterolo) mostrano un trend in peggioramento nel tempo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.blue)
            
            Toggle(isOn: $isOCREnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estrazione Ottica (OCR)")
                        .font(.headline)
                    Text("Usa l'intelligenza artificiale per recuperare dati da vecchi PDF privi di XML medico (Graceful Degradation).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.blue)
            
        } header: {
            Text("Esperienza Utente e Moduli")
        }
    }

    private var creditsSection: some View {
        Section(header: Text("Crediti & Sviluppo")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "swift")
                        .foregroundStyle(.orange)
                    Text("RosettaEdge v3.0")
                        .font(.headline)
                }
                Text("Sviluppata interamente e orgogliosamente in Italia.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            
            Link(destination: URL(string: "https://alexmaina.dev") ?? URL(fileURLWithPath: "")) {
                HStack {
                    Image(systemName: "globe")
                    Text("Alessandro Mainardi (Sito Web)")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://github.com/AlexMaina05") ?? URL(fileURLWithPath: "")) {
                HStack {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                    Text("GitHub (@AlexMaina05)")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}