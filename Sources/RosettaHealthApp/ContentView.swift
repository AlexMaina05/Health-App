import SwiftUI
import SwiftData
import Charts
import HealthKit
import RosettaHealthCore

public struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    
    @State private var isShowingFileImporter = false
    @State private var exportURL: URL?
    @State private var isShowingShareSheet = false
    @State private var isShowingSettings = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // MARK: - Premium Dashboard Hero
                Section {
                    VStack(spacing: 20) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.isHealthKitAuthorized ? Color.white.opacity(0.2) : Color.red.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                Image(systemName: viewModel.isHealthKitAuthorized ? "heart.text.square.fill" : "lock.shield.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(viewModel.isHealthKitAuthorized ? .white : .red)
                                    .symbolEffect(.bounce, options: .nonRepeating, value: viewModel.syncedSamplesCount)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.isHealthKitAuthorized ? "HealthKit Attivo" : "Autorizzazione")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Integrazione nativa FSE")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                        }
                        
                        if !viewModel.isHealthKitAuthorized {
                            Button(action: {
                                Task { await viewModel.requestHealthKitAccess(modelContext: modelContext) }
                            }) {
                                Text("Abilita Integrazione")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        } else {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Parametri Sincronizzati")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("\(viewModel.syncedSamplesCount)")
                                        .font(.system(.title, design: .rounded).weight(.bold))
                                        .foregroundColor(.white)
                                        .contentTransition(.numericText()) // Animazione numerica fluida
                                }
                                Spacer()
                                Button(action: {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    isShowingFileImporter = true 
                                }) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.blue)
                                        .padding(16)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.1), radius: 6, y: 4)
                                }
                                .disabled(viewModel.isProcessing)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                    .background {
                        LinearGradient(
                            colors: [Color.blue, Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .listRowInsets(EdgeInsets()) // Rimuove i margini di default della List per la card
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.purple.opacity(0.2), radius: 15, x: 0, y: 8)
                .padding(.bottom, 8)
                
                // MARK: - Premium Processing Indicator
                if viewModel.isProcessing {
                    Section {
                        VStack(spacing: 20) {
                            Image(systemName: "scanner")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue.gradient)
                                .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                            
                            Text("Analisi e decrittazione in corso...")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        .padding(.vertical, 30)
                        .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.clear)
                }
                
                // MARK: - Premium Empty State
                if viewModel.extractedObservations.isEmpty && !viewModel.isProcessing && viewModel.isHealthKitAuthorized {
                    Section {
                        ContentUnavailableView {
                            Label("Nessun Referto", systemImage: "tray")
                                .symbolEffect(.pulse)
                        } description: {
                            Text("Usa l'Estensione di Condivisione di iOS per estrarre referti da PDF archiviati in iCloud Drive o Ricevuti via Mail.")
                        } actions: {
                            Button(action: {
                                isShowingShareSheet = true
                            }) {
                                Text("Apri Condivisione (Tutorial)")
                                    .fontWeight(.bold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .clipShape(Capsule())
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                
                // MARK: - Avviso OCR (Graceful Degradation)
                if viewModel.isOCRExtracted {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "text.viewfinder")
                                    .foregroundColor(.purple)
                                    .font(.headline)
                                Text("Scansione Ottica (OCR)")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                            }
                            Text("Il PDF originale non conteneva dati strutturati. I parametri sottostanti sono stati estratti visivamente tramite Intelligenza Artificiale.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // MARK: - Risultati Strutturati
                if !viewModel.extractedObservations.isEmpty {
                    Section {
                        ForEach(viewModel.extractedObservations, id: \.id) { obs in
                            ObservationRowView(observation: obs)
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("Dettaglio Analisi (\(viewModel.extractedObservations.count))")
                            .font(.headline)
                            .textCase(nil)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
                    // Export JSON
                    Section {
                        Button(action: {
                            if let url = viewModel.exportFHIRJSON() {
                                exportURL = url
                                isShowingShareSheet = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Esporta referto FHIR R4 (JSON)")
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .tint(.blue)
                    }
                }
                
                // MARK: - Avvisi (Parametri non Quantificabili)
                if !viewModel.skippedCodes.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Archiviati solo come Documento", systemImage: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.headline)
                            Text("I seguenti esami non possiedono grafici nativi in Salute. Sono stati comunque salvati in maniera invisibile nel referto globale (HKCDADocumentSample):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(viewModel.skippedCodes, id: \.self) { code in
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption2)
                                            .foregroundColor(.blue.opacity(0.7))
                                        Text(code)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("RosettaHealth")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "person.text.rectangle")
                    }
                }
            }
            .task {
                await viewModel.syncPendingDocuments(modelContext: modelContext)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await viewModel.syncPendingDocuments(modelContext: modelContext)
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let selectedURL = urls.first {
                        let secured = selectedURL.startAccessingSecurityScopedResource()
                        
                        // Copia sincrona per prevenire race condition sui file descriptor
                        let tempDir = FileManager.default.temporaryDirectory
                        let safeURL = tempDir.appendingPathComponent(UUID().uuidString + ".pdf")
                        
                        do {
                            try FileManager.default.copyItem(at: selectedURL, to: safeURL)
                            // Audit GDPR: Forziamo la crittografia esplicita anche sul file temporaneo
                            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: safeURL.path)
                            
                            if secured { selectedURL.stopAccessingSecurityScopedResource() }
                            
                            Task {
                                defer { try? FileManager.default.removeItem(at: safeURL) }
                                await viewModel.processPDF(url: safeURL, modelContext: modelContext)
                            }
                        } catch {
                            if secured { selectedURL.stopAccessingSecurityScopedResource() }
                            viewModel.activeError = .pdfCorrupted
                        }
                    }
                case .failure(_):
                    viewModel.activeError = .pdfCorrupted
                }
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .alert(isPresented: Binding<Bool>(
                get: { viewModel.activeError != nil },
                set: { if !$0 { viewModel.activeError = nil } }
            ), error: viewModel.activeError) { _ in
                Button("OK", role: .cancel) { }
            } message: { error in
                VStack(alignment: .leading) {
                    Text(error.failureReason ?? "")
                    if let suggestion = error.recoverySuggestion {
                        Text("\n\(suggestion)")
                    }
                }
            }
        }
    }
}

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Privacy & Multi-Profile
    @AppStorage("ownerFirstName") private var firstName: String = ""
    @AppStorage("ownerLastName") private var lastName: String = ""
    @AppStorage("ownerDateOfBirth") private var dateOfBirthInterval: Double = Date().timeIntervalSince1970
    @AppStorage("ownerFiscalCode") private var ownerFiscalCode: String = ""
    
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
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fine") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                birthDate = Date(timeIntervalSince1970: dateOfBirthInterval)
            }
        }
    }
}

struct ObservationRowView: View {
    let observation: FHIRObservation
    
    @State private var history: [(date: Date, value: Double)] = []
    
    // Logica di valutazione Range
    private var isOutOfRange: Bool {
        guard let qty = observation.valueQuantity?.value,
              let ranges = observation.referenceRange, let range = ranges.first else {
            return false
        }
        if let low = range.low?.value, qty < low { return true }
        if let high = range.high?.value, qty > high { return true }
        return false
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                // Icona laterale
                ZStack {
                    Circle()
                        .fill(isOutOfRange ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: isOutOfRange ? "exclamationmark.triangle.fill" : "waveform.path.ecg")
                        .foregroundColor(isOutOfRange ? .red : .blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(observation.code.text ?? observation.code.coding.first?.display ?? "Parametro Sconosciuto")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let ranges = observation.referenceRange, let range = ranges.first {
                        if let low = range.low?.value, let high = range.high?.value {
                            Text("Range: \(String(format: "%.1f", low)) - \(String(format: "%.1f", high))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if let qty = observation.valueQuantity {
                        Text(String(format: "%.2f", qty.value))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundColor(isOutOfRange ? .red : .primary)
                        Text(qty.unit)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    } else if let str = observation.valueString {
                        Text(str)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            // Mini-Grafico (Sparkline)
            if history.count > 1 {
                Chart {
                    ForEach(history, id: \.date) { point in
                        LineMark(
                            x: .value("Data", point.date),
                            y: .value("Valore", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(isOutOfRange ? Color.red.gradient : Color.blue.gradient)
                        
                        PointMark(
                            x: .value("Data", point.date),
                            y: .value("Valore", point.value)
                        )
                        .foregroundStyle(isOutOfRange ? Color.red : Color.blue)
                    }
                }
                .frame(height: 50)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .task {
            await loadHistory()
        }
    }
    
    private func loadHistory() async {
        guard let loinc = observation.code.coding.first?.code else { return }
        let bridge = HealthKitBridge()
        guard let target = bridge.loincToHKMap[loinc] else { return }
        
        if let samples = try? await bridge.fetchHistoricalSamples(for: target.type, limit: 5) {
            let points = samples.map { (date: $0.startDate, value: $0.quantity.doubleValue(for: target.defaultUnit)) }
            self.history = points.sorted { $0.date < $1.date }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
