import UIKit
import Social
import UniformTypeIdentifiers
import RosettaHealthCore

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedPDF()
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
                        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.dev.alexmaina.rosettahealth") else {
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
                            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                        }
                    } catch let error as RosettaError {
                        await MainActor.run {
                            self.extensionContext?.cancelRequest(withError: error)
                        }
                    } catch {
                        await MainActor.run {
                            let genericError = NSError(domain: "RosettaHealth", code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                            self.extensionContext?.cancelRequest(withError: genericError)
                        }
                    }
                }
            }
        }
    }
}
