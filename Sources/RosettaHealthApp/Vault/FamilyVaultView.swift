import SwiftUI
import SwiftData
import RosettaHealthCore

@available(iOS 26.0, *)
public struct FamilyVaultView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VaultDocument.dateAdded, order: .reverse) private var documents: [VaultDocument]
    
    @State private var searchText: String = ""
    @State private var documentToDelete: VaultDocument? = nil
    @State private var documentToShare: VaultDocument? = nil
    @State private var isShowingShareSheet: Bool = false
    
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
        NavigationStack {
            List {
                if documents.isEmpty {
                    ContentUnavailableView(
                        "Vault Vuoto",
                        systemImage: "folder.badge.person.crop",
                        description: Text("I referti scansionati dei tuoi familiari verranno archiviati qui, in modo sicuro e locale.")
                    )
                } else {
                    ForEach(groupedDocuments.keys.sorted(), id: \.self) { cf in
                        Section(header: Text("Paziente: \(cf)")) {
                            let patientDocs = groupedDocuments[cf] ?? []
                            
                            // Mostra il nome del paziente dedotto dall'ultimo documento
                            if let name = patientDocs.first?.patientName {
                                HStack(spacing: 12) {
                                    // Dynamic Avatar
                                    ZStack {
                                        Circle()
                                            .fill(avatarGradient(for: cf))
                                            .frame(width: 36, height: 36)
                                        
                                        Text(String(name.prefix(1)).uppercased())
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, y: 2)
                                    
                                    Text(name)
                                        .font(.headline)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            ForEach(patientDocs) { doc in
                                NavigationLink(destination: VaultDocumentDetailView(document: doc)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(doc.documentTitle)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        
                                        Text(doc.documentDate, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .scrollTransition(.animated.threshold(.visible(0.9))) { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0.5)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.95)
                                        .rotation3DEffect(.degrees(phase.value * -15), axis: (x: 1, y: 0, z: 0))
                                }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    modelContext.delete(patientDocs[index])
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Family Vault")
        }
    }
    
    private func avatarGradient(for string: String) -> LinearGradient {
        let hash = abs(string.hashValue)
        let colors: [[Color]] = [
            [.blue, .purple],
            [.orange, .red],
            [.green, .teal],
            [.pink, .purple],
            [.yellow, .orange]
        ]
        let palette = colors[hash % colors.count]
        return LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

@available(iOS 26.0, *)
struct VaultDocumentDetailView: View {
    let document: VaultDocument
    
    var fhirBundle: FHIRBundle? {
        let decoder = JSONDecoder()
        return try? decoder.decode(FHIRBundle.self, from: document.fhirBundleJSON)
    }
    
    var body: some View {
        List {
            Section("Dettagli Referto") {
                LabeledContent("Paziente", value: document.patientName)
                LabeledContent("Codice Fiscale", value: document.fiscalCode)
                LabeledContent("Data Referto", value: document.documentDate.formatted(date: .long, time: .omitted))
                LabeledContent("Archiviato il", value: document.dateAdded.formatted(date: .abbreviated, time: .shortened))
            }
            
            if let bundle = fhirBundle {
                Section("Misurazioni Cliniche") {
                    let observations = bundle.entry.compactMap { if case .observation(let o) = $0.resource { return o } else { return nil } }
                    
                    if observations.isEmpty {
                        Text("Nessuna osservazione quantitativa trovata.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(observations, id: \.id) { obs in
                            VStack(alignment: .leading) {
                                Text(obs.code.text ?? obs.code.coding.first?.display ?? "Misurazione")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                if let qty = obs.valueQuantity {
                                    Text("\(qty.value, specifier: "%.2f") \(qty.unit)")
                                        .font(.title3)
                                        .foregroundStyle(.purple)
                                } else if let str = obs.valueString {
                                    Text(str)
                                        .font(.title3)
                                        .foregroundStyle(.purple)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                #if os(iOS)
                if let pdfData = document.pdfData {
                    Section("Documento Originale") {
                        let searchTerms = bundle.entry.compactMap { if case .observation(let o) = $0.resource { return String((o.valueQuantity?.value ?? 0.0)) } else { return nil } }
                        
                        NavigationLink("Visualizza PDF Evidenziato") {
                            // Scriviamo il data in un URL temporaneo per PDFKit
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(document.id.uuidString).pdf")
                            let _ = try? pdfData.write(to: tempURL)
                            
                            AnnotatedPDFView(url: tempURL, searchStrings: searchTerms)
                                .navigationTitle("Referto Originale")
                                .navigationBarTitleDisplayMode(.inline)
                                .onDisappear {
                                    try? FileManager.default.removeItem(at: tempURL)
                                }
                        }
                    }
                }
                #endif
            } else {
                Text("Errore nella decodifica del Bundle FHIR.")
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle(document.documentTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}





