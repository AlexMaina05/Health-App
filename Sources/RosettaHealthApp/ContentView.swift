import SwiftUI
import SwiftData
import TipKit
import Charts
import HealthKit
import RosettaHealthCore
import UniformTypeIdentifiers

public struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appThemeName") private var appThemeName: String = AppTheme.blue.rawValue
    
    @State private var isShowingFileImporter = false
    @State private var exportURL: URL?
    @State private var isShowingShareSheet = false
    @State private var isShowingSettings = false

    public init() {}
    
    private var themeColor: Color {
        AppTheme(rawValue: appThemeName)?.color ?? .blue
    }

    public var body: some View {
        NavigationStack {
            List {
                                  // MARK: - Anonymous Mode Warning
                  if viewModel.isAnonymousMode {
                      Section {
                          HStack {
                              Image(systemName: "exclamationmark.triangle.fill")
                                  .foregroundStyle(.yellow)
                                  .font(.title2)
                              VStack(alignment: .leading, spacing: 4) {
                                  Text("Modalità Anonima Attiva")
                                      .font(.headline)
                                      .foregroundStyle(.yellow)
                                  Text("Avendo omesso il Codice Fiscale, il firewall è disattivato. Tutti i referti importati verranno salvati in Salute. Usa con cautela.")
                                      .font(.caption)
                                      .foregroundStyle(.secondary)
                              }
                          }
                          .padding(.vertical, 4)
                      }
                  }
                  
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
                                    .foregroundStyle(viewModel.isHealthKitAuthorized ? .white : .red)
                                    .symbolEffect(.bounce, options: .nonRepeating, value: viewModel.syncedSamplesCount)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.isHealthKitAuthorized ? "HealthKit Attivo" : "Autorizzazione")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Integrazione nativa FSE")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            Spacer()
                        }
                        
                        if !viewModel.isHealthKitAuthorized {
                            Button(action: {
                                Task { await viewModel.requestHealthKitAccess(modelContainer: modelContext.container) }
                            }) {
                                Text("Abilita Integrazione")
                                    .font(.headline)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .scaleEffect(viewModel.isHealthKitAuthorized ? 1.0 : 1.05)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0).repeatForever(autoreverses: true), value: viewModel.isHealthKitAuthorized)
                            }
                        } else {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Parametri Sincronizzati")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Text("\(viewModel.syncedSamplesCount)")
                                        .font(.system(.title, design: .rounded).weight(.bold))
                                        .foregroundStyle(.white)
                                        .contentTransition(.numericText()) // Animazione numerica fluida
                                }
                                Spacer()
                                Button(action: {
                                    // Sensorial feedback is handled natively via SwiftUI
                                    isShowingFileImporter = true 
                                }) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(.blue)
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
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .listRowInsets(EdgeInsets()) // Rimuove i margini di default della List per la card
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.blue.opacity(0.2), radius: 15, x: 0, y: 8)
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
                                .foregroundStyle(.primary)
                            
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
                                    .foregroundStyle(themeColor)
                                    .font(.headline)
                                Text("Scansione Ottica (OCR)")
                                    .font(.headline)
                                    .foregroundStyle(themeColor)
                            }
                            Text("Il PDF originale non conteneva dati strutturati. I parametri sottostanti sono stati estratti visivamente tramite Intelligenza Artificiale.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button(action: {
                                Task { await viewModel.approveAndSaveOCR() }
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.shield")
                                    Text("Approva e Salva in Salute")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(themeColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // MARK: - Risultati Strutturati
                if !viewModel.extractedObservations.isEmpty {
                    Section {
                        ForEach(viewModel.extractedObservations, id: \.id) { obs in
                            ObservationRowView(observation: obs)
                                .scrollTransition(.animated.threshold(.visible(0.9))) { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0.5)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.95)
                                        .rotation3DEffect(.degrees(phase.value * 10), axis: (x: 1, y: 0, z: 0))
                                }
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
                                .foregroundStyle(.blue)
                                .font(.headline)
                            Text("I seguenti esami non possiedono grafici nativi in Salute. Sono stati comunque salvati in maniera invisibile nel referto globale (HKCDADocumentSample):")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(viewModel.skippedCodes, id: \.self) { code in
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.blue.opacity(0.7))
                                        Text(code)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
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
                await viewModel.syncPendingDocuments(modelContainer: modelContext.container)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await viewModel.syncPendingDocuments(modelContainer: modelContext.container)
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
                            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: safeURL.path)
                            
                            if secured { selectedURL.stopAccessingSecurityScopedResource() }
                            
                            Task {
                                defer { try? FileManager.default.removeItem(at: safeURL) }
                                await viewModel.processPDF(url: safeURL, modelContainer: modelContext.container)
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
            .onDrop(of: [.pdf], isTargeted: nil) { providers in
                guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }) else {
                    return false
                }
                
                provider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { url, error in
                    guard let fileURL = url else { return }
                    
                    let tempDir = FileManager.default.temporaryDirectory
                    let safeURL = tempDir.appendingPathComponent(UUID().uuidString + ".pdf")
                    do {
                        try FileManager.default.copyItem(at: fileURL, to: safeURL)
                        Task { @MainActor in
                            await viewModel.processPDF(url: safeURL, modelContainer: modelContext.container)
                            try? FileManager.default.removeItem(at: safeURL)
                        }
                    } catch {
                        Task { @MainActor in
                            viewModel.activeError = .pdfCorrupted
                        }
                    }
                }
                return true
            }
        }
    }
}

