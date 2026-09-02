import Foundation
import SwiftData

/// Modello Dati Locale (SwiftData) per l'archiviazione dei referti familiari.
/// I dati sono memorizzati esclusivamente in locale sul dispositivo (Zero-Cloud)
/// e crittografati nativamente dal Secure Enclave tramite passcode iOS.
@available(iOS 17.0, *)
@Model
public final class VaultDocument {
    public var id: UUID = UUID()
    public var dateAdded: Date = Date()
    
    // Anagrafica Paziente
    public var patientName: String = ""
    public var fiscalCode: String = ""
    
    // Contenuto Clinico
    public var documentTitle: String = ""
    public var documentDate: Date = Date()
    
    // Il Bundle FHIR transcodificato (salvato come JSON Data grezzo per flessibilità)
    @Attribute(.externalStorage) public var fhirBundleJSON: Data = Data()
    
    // Il PDF Originale per le annotazioni vettoriali
    @Attribute(.externalStorage) public var pdfData: Data?
    
    public init(id: UUID = UUID(), dateAdded: Date = Date(), patientName: String, fiscalCode: String, documentTitle: String, documentDate: Date, fhirBundleJSON: Data, pdfData: Data? = nil) {
        self.id = id
        self.dateAdded = dateAdded
        self.patientName = patientName
        self.fiscalCode = fiscalCode
        self.documentTitle = documentTitle
        self.documentDate = documentDate
        self.fhirBundleJSON = fhirBundleJSON
        self.pdfData = pdfData
    }
}
