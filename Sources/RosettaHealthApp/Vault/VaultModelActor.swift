import Foundation
import SwiftData
import CoreSpotlight
import OSLog

@available(iOS 17.0, *)
@ModelActor
public actor VaultModelActor {
    
    private let logger = Logger(subsystem: "dev.alexmaina.rosettahealth", category: "VaultModelActor")
    
    public func saveDocument(patientName: String, fiscalCode: String, documentTitle: String, fhirBundleJSON: Data, pdfData: Data?) throws {
        let vaultDoc = VaultDocument(
            patientName: patientName,
            fiscalCode: fiscalCode,
            documentTitle: documentTitle,
            documentDate: Date(),
            fhirBundleJSON: fhirBundleJSON,
            pdfData: pdfData
        )
        
        modelContext.insert(vaultDoc)
        
        // Spotlight Indexing
        SpotlightManager.shared.indexDocument(
            id: vaultDoc.id.uuidString,
            title: vaultDoc.documentTitle,
            patientName: vaultDoc.patientName,
            date: vaultDoc.dateAdded
        )
        
        try modelContext.save()
        logger.info("Documento salvato in SwiftData tramite ModelActor.")
    }
}