import SwiftUI
import HealthKit
import RosettaHealthCore

public struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingFileImporter = false
    @State private var exportURL: URL?
    @State private var isShowingShareSheet = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // MARK: - Dashboard Hero
                Section {
                    VStack(spacing: 20) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.isHealthKitAuthorized ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                Image(systemName: viewModel.isHealthKitAuthorized ? "heart.text.square.fill" : "lock.shield.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(viewModel.isHealthKitAuthorized ? .green : .red)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.isHealthKitAuthorized ? "HealthKit Connesso" : "Autorizzazione Richiesta")
                                    .font(.headline)
                                Text("Integrazione nativa FSE attiva")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        if !viewModel.isHealthKitAuthorized {
                            Button(action: {
                                Task { await viewModel.requestHealthKitAccess() }
                            }) {
                                Text("Abilita Integrazione")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.gradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
                            }
                        } else {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Parametri Sincronizzati")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(viewModel.syncedSamplesCount)")
                                        .font(.system(.title, design: .rounded).weight(.bold))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                Button(action: { isShowingFileImporter = true }) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(16)
                                        .background(Color.blue.gradient)
                                        .clipShape(Circle())
                                        .shadow(color: .blue.opacity(0.3), radius: 6, y: 4)
                                }
                                .disabled(viewModel.isProcessing)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                
                // MARK: - Indicatore Caricamento
                if viewModel.isProcessing {
                    Section {
                        HStack(spacing: 16) {
                            ProgressView()
                            Text("Estrazione referto in corso...")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
