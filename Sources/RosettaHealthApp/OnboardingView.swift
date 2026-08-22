import SwiftUI

@available(iOS 17.0, *)
public struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("ownerFirstName") private var firstName: String = ""
    @AppStorage("ownerLastName") private var lastName: String = ""
    @AppStorage("ownerDateOfBirth") private var dateOfBirthInterval: Double = Date().timeIntervalSince1970
    @AppStorage("ownerFiscalCode") private var fiscalCode: String = ""
    
    @State private var birthDate: Date = Date()
    
    public init() {}
    
    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        fiscalCode.trimmingCharacters(in: .whitespaces).count == 16
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header (Hero Section)
                VStack(spacing: 16) {
                    Image(systemName: "waveform.path.ecg")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.purple)
                        .padding(.top, 40)
                    
                    Text("Benvenuto in\nRosettaHealth")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.heavy)
                        .multilineTextAlignment(.center)
                    
                    Text("Configura il tuo profilo principale per abilitare la sicurezza medica multi-utente (Family Vault) e l'isolamento dei dati su Apple Salute.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 32)
                
                // Form
                Form {
                    Section(header: Text("Dati Anagrafici")) {
                        TextField("Nome", text: $firstName)
                            .textContentType(.givenName)
                        
                        TextField("Cognome", text: $lastName)
                            .textContentType(.familyName)
                        
                        DatePicker("Data di Nascita", selection: $birthDate, displayedComponents: .date)
                    }
                    
                    Section(header: Text("Identificativo Sanitario"), footer: Text("Il Codice Fiscale è fondamentale per garantire che i referti dei tuoi familiari non inquinino i tuoi grafici sanitari personali.")) {
                        TextField("Codice Fiscale (16 caratteri)", text: $fiscalCode)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .onChange(of: fiscalCode) { _, newValue in
                                if newValue.count > 16 {
                                    fiscalCode = String(newValue.prefix(16))
                                }
                            }
                    }
                }
                .scrollContentBackground(.hidden)
                
                // Pulsante Conferma
                VStack {
                    Button(action: {
                        dateOfBirthInterval = birthDate.timeIntervalSince1970
                        withAnimation(.spring()) {
                            hasCompletedOnboarding = true
                        }
                    }) {
                        Text("Inizia a usare RosettaHealth")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.purple : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        }
        .onAppear {
            birthDate = Date(timeIntervalSince1970: dateOfBirthInterval)
        }
    }
}
