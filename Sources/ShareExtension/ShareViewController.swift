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
                
                Task {
                    do {
                        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.dev.alexmaina.rosettahealth") else {
                            throw RosettaError.appGroupContainerUnavailable
                        }
                        
                        do {
                            // Tentativo di estrazione XML pura
                            let xmlData = try PDFEmbeddedAttachmentExtractor.extractXML(from: fileURL)
                            let fileName = "PendingCDA_\(UUID().uuidString).xml"
                            let destURL = groupURL.appendingPathComponent(fileName)
                            try xmlData.write(to: destURL)
                        } catch RosettaError.noEmbeddedXMLFound {
                            // Fallback: è un PDF raster, lo copiamo per l'OCR nell'app principale
                            let fileName = "PendingPDF_\(UUID().uuidString).pdf"
                            let destURL = groupURL.appendingPathComponent(fileName)
                            try FileManager.default.copyItem(at: fileURL, to: destURL)
                        }
                        
                        DispatchQueue.main.async {
                            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                        }
                    } catch let error as RosettaError {
                        DispatchQueue.main.async {
                            self.extensionContext?.cancelRequest(withError: error)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            let genericError = NSError(domain: "RosettaHealth", code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                            self.extensionContext?.cancelRequest(withError: genericError)
                        }
                    }
                }
            }
        }
    }
}
