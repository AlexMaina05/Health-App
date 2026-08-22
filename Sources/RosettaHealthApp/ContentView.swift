import SwiftUI
import HealthKit
import RosettaHealthCore

public struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase
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
                                Task { await viewModel.requestHealthKitAccess() }
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
                        HStack(spacing: 16) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .symbolEffect(.pulse, isActive: true)
                            Text("Estrazione referto in corso...")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
                
                // MARK: - Premium Empty State
                if viewModel.extractedObservations.isEmpty && !viewModel.isProcessing && viewModel.isHealthKitAuthorized {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "folder.badge.magnifyingglass")
                                .font(.system(size: 50, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
                                )
                                .padding(.bottom, 8)
                            
                            Text("Nessun referto attivo")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("RosettaHealth è in attesa.\nCondividi un PDF dal tuo Fascicolo Regionale tramite il tasto '+' o dal menu di condivisione di iOS.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
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
                await viewModel.syncPendingDocuments()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await viewModel.syncPendingDocuments()
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
                                await viewModel.processPDF(url: safeURL)
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
    @AppStorage("ownerFiscalCode") private var ownerFiscalCode: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Fascicolo Familiare (Prevenzione Inquinamento)"), footer: Text("Inserisci il tuo Codice Fiscale. RosettaHealth bloccherà automaticamente il salvataggio in Apple Salute di qualsiasi referto appartenente a terzi (es. figli o genitori).")) {
                    TextField("Codice Fiscale Proprietario", text: $ownerFiscalCode)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Impostazioni Profilo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fine") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ObservationRowView: View {
    let observation: FHIRObservation
    
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
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
