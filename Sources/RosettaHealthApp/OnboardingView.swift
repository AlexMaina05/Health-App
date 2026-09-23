import SwiftUI

@available(iOS 17.0, *)
public struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("ownerFirstName") private var firstName: String = ""
    @AppStorage("ownerLastName") private var lastName: String = ""
    @AppStorage("ownerDateOfBirth") private var dateOfBirthInterval: Double = 946684800
    @State private var fiscalCode: String = ""
    @State private var noFiscalCode: Bool = false
    
    @State private var birthDate: Date = Date()
    @State private var hasAcceptedGDPR: Bool = false
    
    @State private var currentPage: Int = 0
    private let totalPages = 4
    
    public init() {}
    
    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        (fiscalCode.trimmingCharacters(in: .whitespaces).count == 16 || noFiscalCode) &&
        hasAcceptedGDPR
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                // Pagina 0: Intro
                tutorialPage(icon: "waveform.path.ecg", color: .blue, title: "I tuoi referti,\nfinalmente vivi.", description: "Trasforma i noiosi PDF del Fascicolo Sanitario Elettronico in fantastici grafici interattivi su Apple Salute.")
                    .tag(0)
                
                // Pagina 1: Privacy
                tutorialPage(icon: "lock.shield.fill", color: .green, title: "Zero-Cloud\nPrivacy Assoluta", description: "Nessun server. I tuoi dati medici sensibili vengono elaborati esclusivamente sul processore del tuo iPhone nel pieno rispetto del GDPR.")
                    .tag(1)
                
                // Pagina 2: Tutorial
                tutorialPage(icon: "square.and.arrow.up", color: .blue, title: "Come Funziona?", description: "1. Scarica un referto PDF dal tuo FSE\n2. Clicca su Condividi\n3. Seleziona RosettaHealth")
                    .tag(2)
                
                // Pagina 3: Registrazione
                registrationPage()
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            
            // Bottom Controls
            HStack {
                if currentPage > 0 {
                    Button(action: {
                        withAnimation { currentPage -= 1 }
                    }) {
                        Text("Indietro")
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                    }
                } else {
                    Spacer().frame(width: 80) // Placeholder
                }
                
                Spacer()
                
                if currentPage < totalPages - 1 {
                    Button(action: {
                        withAnimation { currentPage += 1 }
                    }) {
                        Text("Avanti")
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                } else {
                    Button(action: {
                        dateOfBirthInterval = birthDate.timeIntervalSince1970
                        withAnimation(.spring()) {
                            _ = KeychainManager.shared.save(key: "ownerFiscalCode", value: fiscalCode)
                            hasCompletedOnboarding = true
                        }
                    }) {
                        Text("Inizia")
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(isFormValid ? Color.blue : Color.gray)
                            .clipShape(Capsule())
                    }
                    .disabled(!isFormValid)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            birthDate = Date(timeIntervalSince1970: dateOfBirthInterval)
        }
    }
    
    @ViewBuilder
    private func tutorialPage(icon: String, color: Color, title: String, description: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(color)
                .padding(.bottom, 16)
            
            Text(title)
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.heavy)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineSpacing(6)
            Spacer()
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private func registrationPage() -> some View {
        VStack(spacing: 0) {
            Text("Chi sei?")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.heavy)
                .padding(.top, 40)
                .padding(.bottom, 8)
            
            Text("Configura il tuo profilo per abilitare l'isolamento dei dati su Apple Salute e il Family Vault.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            
            Form {
                Section(header: Text("Dati Anagrafici")) {
                    TextField("Nome", text: $firstName)
                        .textContentType(.givenName)
                    
                    TextField("Cognome", text: $lastName)
                        .textContentType(.familyName)
                    
                    DatePicker("Data di Nascita", selection: $birthDate, displayedComponents: .date)
                }
                
                                Section(header: Text("Identificativo Sanitario"), footer: Text("Il Codice Fiscale è fondamentale per impedire che i referti dei tuoi familiari (inseriti nel Family Vault) inquinino i tuoi grafici sanitari personali.")) {
                    if !noFiscalCode {
                        TextField("Codice Fiscale (16 caratteri)", text: $fiscalCode)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .onChange(of: fiscalCode) { _, newValue in
                                if newValue.count > 16 {
                                    fiscalCode = String(newValue.prefix(16))
                                }
                            }
                    }
                    
                    Toggle(isOn: $noFiscalCode.animation()) {
                        Text("Non possiedo un Codice Fiscale italiano")
                            .font(.footnote)
                    }
                    .onChange(of: noFiscalCode) { _, newValue in
                        if newValue {
                            fiscalCode = ""
                        }
                    }
                }
                
                Section(header: Text("Privacy e GDPR (Art. 9)")) {
                    Toggle(isOn: $hasAcceptedGDPR) {
                        Text("Accetto l'Informativa e assumo la piena responsabilità legale per la gestione dei referti di eventuali miei familiari archiviati nel Family Vault (Household Exemption).")
                            .font(.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
}
