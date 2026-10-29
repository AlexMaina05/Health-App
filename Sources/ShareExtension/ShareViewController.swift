import UIKit
import SwiftUI
import Observation
import UniformTypeIdentifiers
import RosettaEdgeCore

// MARK: - SwiftUI Custom UI for Share Extension
@available(iOS 17.0, *)
@Observable
class ShareExtensionState {
    var progress: Double = 0.0
    var statusText: String = "Acquisizione Referto..."
    var isSuccess: Bool = false
    var isError: Bool = false
}

@available(iOS 17.0, *)
struct ShareExtensionView: View {
    var state: ShareExtensionState
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(state.isError ? Color.red.opacity(0.2) : (state.isSuccess ? Color.green.opacity(0.2) : Color.purple.opacity(0.2)))
                    .frame(width: 80, height: 80)
                
                Image(systemName: state.isError ? "xmark.octagon.fill" : (state.isSuccess ? "checkmark.seal.fill" : "doc.viewfinder.fill"))
                    .font(.system(size: 40))
                    .foregroundStyle(state.isError ? .red : (state.isSuccess ? .green : .purple))
                    .symbolEffect(.bounce, value: state.isSuccess)
                    .symbolEffect(.pulse, isActive: !state.isSuccess && !state.isError)
            }
            
            Text(state.statusText)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            
            if !state.isSuccess && !state.isError {
                ProgressView(value: state.progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.purple)
                    .frame(width: 200)
            }
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

@available(iOS 17.0, *)
final class ShareViewController: UIViewController {
    
    private let viewState = ShareExtensionState()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwiftUIInterface()
        
        // Simula un po' di latenza per mostrare l'animazione premium
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.handleSharedPDF()
        }
    }
    
    private func setupSwiftUIInterface() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4) // Sfondo scuro semi-trasparente
        
        let hostingController = UIHostingController(rootView: ShareExtensionView(state: viewState))
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hostingController.view.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // rimosso progressView non esistente
    }
    
    private func handleSharedPDF() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            self.extensionContext?.completeRequest(returningItems: nil)
            return
        }
        
        let pdfType = UTType.pdf.identifier
        if itemProvider.hasItemConformingToTypeIdentifier(pdfType) {
            itemProvider.loadFileRepresentation(forTypeIdentifier: pdfType) { [weak self] url, error in
                guard let self = self, let fileURL = url else {
                    self?.extensionContext?.completeRequest(returningItems: nil)
                    return
                }
                
                // Copia sincrona: salva il file prima che il blocco di completamento termini
                // iOS distrugge fileURL non appena si esce da questa closure!
                let safeURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
                do {
                    try FileManager.default.copyItem(at: fileURL, to: safeURL)
                    // GDPR Compliance: Forzatura crittografia hardware AES-256
                    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: safeURL.path)
                } catch {
                    self?.extensionContext?.completeRequest(returningItems: nil)
                    return
                }
                
                Task {
                    defer { try? FileManager.default.removeItem(at: safeURL) }
                    
                    do {
                        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.dev.alexmaina.rosettaedge") else {
                            throw RosettaError.appGroupContainerUnavailable
                        }
                        
                        do {
                            // Tentativo di estrazione XML pura
                            let xmlData = try PDFEmbeddedAttachmentExtractor.extractXML(from: safeURL)
                            let fileName = "PendingCDA_\(UUID().uuidString).xml"
                            let destURL = groupURL.appendingPathComponent(fileName)
                            try xmlData.write(to: destURL, options: .completeFileProtectionUntilFirstUserAuthentication)
                        } catch RosettaError.noEmbeddedXMLFound {
                            // Fallback: è un PDF raster, lo copiamo per l'OCR nell'app principale
                            let fileName = "PendingPDF_\(UUID().uuidString).pdf"
                            let destURL = groupURL.appendingPathComponent(fileName)
                            try FileManager.default.copyItem(at: safeURL, to: destURL)
                            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: destURL.path)
                        }
                        
                        await MainActor.run {
                            self.viewState.progress = 1.0
                            self.viewState.statusText = "Salvato nel Vault"
                            self.viewState.isSuccess = true
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                            }
                        }
                    } catch let error as RosettaError {
                        await MainActor.run {
                            self.viewState.statusText = "Errore: \(error.localizedDescription)"
                            self.viewState.isError = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.extensionContext?.cancelRequest(withError: error)
                            }
                        }
                    } catch {
                        await MainActor.run {
                            self.viewState.statusText = "Errore Sconosciuto"
                            self.viewState.isError = true
                            let genericError = NSError(domain: "RosettaEdge", code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.extensionContext?.cancelRequest(withError: genericError)
                            }
                        }
                    }
                }
            }
        }
    }
}
