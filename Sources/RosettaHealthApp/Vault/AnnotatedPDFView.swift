import SwiftUI
#if canImport(PDFKit) && os(iOS)
import PDFKit

public struct AnnotatedPDFView: UIViewRepresentable {
    public let pdfURL: URL
    
    // Per un'app reale queste bounding boxes verrebbero estratte e salvate dal VisionOCRExtractor
    // Al momento implementiamo un Proof of Concept che ricerca la stringa e l'evidenzia
    public let searchStrings: [String]
    
    public init(url: URL, searchStrings: [String] = []) {
        self.pdfURL = url
        self.searchStrings = searchStrings
    }
    
    public func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(url: pdfURL) {
            pdfView.document = document
            
            // Applica le evidenziazioni vettoriali
            annotateDocument(document)
        }
        
        return pdfView
    }
    
    public func updateUIView(_ uiView: PDFView, context: Context) {
        // Nessun aggiornamento necessario
    }
    
    private func annotateDocument(_ document: PDFDocument) {
        for searchString in searchStrings {
            let selections = document.findString(searchString, withOptions: .caseInsensitive)
            
            for selection in selections {
                guard let page = selection.pages.first else { continue }
                
                let bounds = selection.bounds(for: page)
                
                // Creiamo l'annotazione di tipo Highlight
                let highlight = PDFAnnotation(
                    bounds: bounds,
                    forType: .highlight,
                    withProperties: nil
                )
                
                highlight.color = UIColor.yellow.withAlphaComponent(0.5)
                page.addAnnotation(highlight)
            }
        }
    }
}
#endif
