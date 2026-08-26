import SwiftUI
import SwiftData
import RosettaHealthCore

@available(iOS 26.0, *)
public struct FamilyVaultView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VaultDocument.dateAdded, order: .reverse) private var documents: [VaultDocument]
    
    @State private var searchText: String = ""
    @State private var selectedDocument: VaultDocument? = nil
    
    // Raggruppamento per Codice Fiscale
    private var groupedDocuments: [String: [VaultDocument]] {
        let filteredDocs = searchText.isEmpty ? documents : documents.filter { 
            $0.documentTitle.localizedCaseInsensitiveContains(searchText) || 
            $0.patientName.localizedCaseInsensitiveContains(searchText) ||
            $0.fiscalCode.localizedCaseInsensitiveContains(searchText)
        }
        return Dictionary(grouping: filteredDocs, by: { $0.fiscalCode })
    }
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedDocument) {
                if documents.isEmpty {
                    ContentUnavailableView(
                        "Vault Vuoto",
                        systemImage: "folder.badge.person.crop",
                        description: Text("I referti scansionati verranno archiviati qui.")
                    )
                } else {
                    ForEach(groupedDocuments.keys.sorted(), id: \.self) { cf in
                        Section(header: Text("Paziente: \(cf)")) {
                            let patientDocs = groupedDocuments[cf] ?? []
                            
                            if let name = patientDocs.first?.patientName {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(avatarGradient(for: cf))
                                            .frame(width: 36, height: 36)
                                        Text(String(name.prefix(1)).uppercased())
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                    Text(name).font(.headline)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            ForEach(patientDocs) { doc in
                                NavigationLink(value: doc) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(doc.documentTitle)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text(doc.documentDate, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        modelContext.delete(doc)
                                    } label: {
                                        Label("Elimina", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Family Vault")
            .searchable(text: $searchText, prompt: "Cerca referto, paziente o CF")
        } detail: {
            if let selectedDocument {
                VaultDocumentDetailView(document: selectedDocument)
            } else {
                ContentUnavailableView("Nessun referto selezionato", systemImage: "doc.text.magnifyingglass")
            }
        }
    }
    
    private func avatarGradient(for string: String) -> LinearGradient {
        let hash = abs(string.hashValue)
        let colors: [[Color]] = [
            [.blue, .purple], [.orange, .red], [.green, .teal], [.pink, .purple], [.yellow, .orange]
        ]
        let palette = colors[hash % colors.count]
        return LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

@available(iOS 26.0, *)
struct VaultDocumentDetailView: View {
    let document: VaultDocument
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var fhirBundle: FHIRBundle? {
        let decoder = JSONDecoder()
        return try? decoder.decode(FHIRBundle.self, from: document.fhirBundleJSON)
    }
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // Layout iPad (Affiancato)
                HStack(spacing: 0) {
                    ClinicalDashboardView(fiscalCode: document.fiscalCode)
                        .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    #if os(iOS)
                    if let pdfData = document.pdfData {
                        let searchTerms = extractSearchTerms()
                        PDFViewerWrapper(pdfData: pdfData, searchTerms: searchTerms)
                            .frame(maxWidth: .infinity)
                    } else {
                        ContentUnavailableView("Nessun PDF", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    #endif
                }
            } else {
                // Layout iPhone (Lista tradizionale)
                List {
                    Section("Dettagli Referto") {
                        LabeledContent("Paziente", value: document.patientName)
                        LabeledContent("Codice Fiscale", value: document.fiscalCode)
                        LabeledContent("Data", value: document.documentDate.formatted(date: .long, time: .omitted))
                    }
                    
                    if let bundle = fhirBundle {
                        let composition = bundle.entry.compactMap { if case .composition(let c) = $0.resource { return c } else { return nil } }.first
                        if let narrative = composition?.text?.div, !narrative.isEmpty {
                            Section("Referto Testuale") {
                                Text(narrative)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .padding(.vertical, 4)
                            }
                        }
                        
                        Section("Misurazioni Cliniche (Referto)") {
                            let observations = bundle.entry.compactMap { if case .observation(let o) = $0.resource { return o } else { return nil } }
                            if observations.isEmpty {
                                Text("Nessuna osservazione trovata.")
                            } else {
                                ForEach(observations, id: \.id) { obs in
                                    HStack {
                                        Text(obs.code.text ?? "Misurazione")
                                        Spacer()
                                        if let qty = obs.valueQuantity {
                                            Text("\(qty.value, specifier: "%.2f") \(qty.unit)")
                                                .foregroundStyle(.purple).fontWeight(.semibold)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Section("Dashboard Clinica Olistica") {
                            NavigationLink("Apri Grafici Swift Charts") {
                                ClinicalDashboardView(fiscalCode: document.fiscalCode)
                                    .navigationTitle("Trend Clinici")
                            }
                        }
                        
                        #if os(iOS)
                        if let pdfData = document.pdfData {
                            Section("Documento Originale") {
                                NavigationLink("Visualizza PDF Evidenziato") {
                                    PDFViewerWrapper(pdfData: pdfData, searchTerms: extractSearchTerms())
                                        .navigationTitle("Referto Originale")
                                        .navigationBarTitleDisplayMode(.inline)
                                }
                            }
                        }
                        #endif
                    }
                }
            }
        }
        .navigationTitle(document.documentTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func extractSearchTerms() -> [String] {
        guard let bundle = fhirBundle else { return [] }
        return bundle.entry.compactMap { 
            if case .observation(let o) = $0.resource { return String((o.valueQuantity?.value ?? 0.0)) } 
            else { return nil } 
        }
    }
}

@available(iOS 26.0, *)
struct PDFViewerWrapper: View {
    let pdfData: Data
    let searchTerms: [String]
    
    @State private var tempURL: URL?
    
    var body: some View {
        Group {
            if let url = tempURL {
                AnnotatedPDFView(url: url, searchStrings: searchTerms)
                    .onDisappear {
                        try? FileManager.default.removeItem(at: url)
                    }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
            do {
                try pdfData.write(to: url)
                tempURL = url
            } catch {
                print("Errore scrittura PDF: \(error)")
            }
        }
    }
}