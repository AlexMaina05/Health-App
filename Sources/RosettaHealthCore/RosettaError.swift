import Foundation

public enum RosettaError: LocalizedError, CustomNSError {
    // PDF Errors
    case pdfCorrupted
    case noEmbeddedXMLFound
    case encryptedPDFNotSupported
    
    // CDA Parsing Errors
    case malformedXML(underlying: String)
    case missingClinicalDocumentHeader
    case emptyObservations
    
    // HealthKit Errors
    case healthKitUnavailable
    case authorizationDenied
    case healthKitDatabaseLocked
    case missingSampleType(identifier: String)
    case ingestionFailed(underlying: String)
    case cfMismatch(expected: String, found: String)
    case familyVaultRequiresPro
    
    // IPC / App Group Errors
    case appGroupContainerUnavailable
    case corruptedPendingFile(fileName: String)
    case diskWriteFailed(underlying: String)
    
    public var errorDescription: String? {
        switch self {
        case .pdfCorrupted: return "Documento PDF non valido."
        case .noEmbeddedXMLFound: return "Referto elettronico non rilevato."
        case .encryptedPDFNotSupported: return "PDF protetto da password."
        case .malformedXML: return "Dati clinici corrotti o malformati."
        case .missingClinicalDocumentHeader: return "Intestazione del referto mancante."
        case .emptyObservations: return "Nessuna misurazione rilevata."
        case .healthKitUnavailable: return "HealthKit non disponibile."
        case .authorizationDenied: return "Accesso ad Apple Salute negato."
        case .healthKitDatabaseLocked: return "Dispositivo bloccato."
        case .missingSampleType: return "Parametro non mappabile su Salute."
        case .ingestionFailed: return "Fallimento salvataggio su Salute."
        case .cfMismatch: return "Referto appartenente a terzi."
        case .familyVaultRequiresPro: return "RosettaHealth PRO Richiesto."
        case .appGroupContainerUnavailable: return "Spazio di archiviazione condiviso non accessibile."
        case .corruptedPendingFile: return "File di sincronizzazione corrotto."
        case .diskWriteFailed: return "Errore di scrittura su disco."
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .pdfCorrupted: return "Il file fornito non risulta essere un documento PDF/A-3 valido."
        case .noEmbeddedXMLFound: return "Il PDF non contiene alcun payload XML CDA allegato compatibile con le specifiche FSE 2.0."
        case .encryptedPDFNotSupported: return "L'elaborazione di documenti PDF cifrati non è supportata."
        case .malformedXML(let underlying): return "Il parser ha riscontrato un errore fatale leggendo l'XML: \(underlying)."
        case .missingClinicalDocumentHeader: return "L'elemento radice <ClinicalDocument> non è stato trovato."
        case .emptyObservations: return "Il referto è composto esclusivamente da testo narrativo senza dati clinici strutturati."
        case .healthKitUnavailable: return "Il dispositivo corrente non supporta l'integrazione con Apple Salute."
        case .authorizationDenied: return "L'utente non ha concesso le autorizzazioni di lettura/scrittura per i dati clinici."
        case .healthKitDatabaseLocked: return "Il database di Apple Salute è crittografato a livello hardware finché l'iPhone non viene sbloccato."
        case .missingSampleType(let identifier): return "Il parametro clinico (\(identifier)) non possiede un corrispettivo in HKQuantityType."
        case .ingestionFailed(let underlying): return "HealthKit ha rifiutato il salvataggio dei campioni: \(underlying)."
        case .cfMismatch(let expected, _): return "Il Codice Fiscale estratto (***) non corrisponde a quello del proprietario configurato (\(expected))."
        case .familyVaultRequiresPro: return "L'archiviazione di referti appartenenti a familiari o terzi (Family Vault) è una funzionalità esclusiva di RosettaHealth PRO."
        case .appGroupContainerUnavailable: return "La sandbox non è riuscita a risolvere il path del Security Application Group identifier."
        case .corruptedPendingFile(let fileName): return "Il file in coda \(fileName) non contiene un Bundle FHIR valido."
        case .diskWriteFailed(let underlying): return "Impossibile serializzare il referto sul container: \(underlying)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .pdfCorrupted, .noEmbeddedXMLFound, .encryptedPDFNotSupported:
            return "Assicurati di importare un referto FSE 2.0 originale, scaricato direttamente dal portale fascicolo regionale, non stampato o scansionato."
        case .malformedXML, .missingClinicalDocumentHeader, .emptyObservations:
            return "Il documento sarà archiviato in formato testuale ma i valori numerici non potranno essere sincronizzati con Apple Salute."
        case .healthKitUnavailable:
            return "Assicurati di eseguire l'app su un iPhone con l'App Salute installata (non compatibile con iPad senza iPadOS 17)."
        case .authorizationDenied:
            return "Apri l'app Salute > Condivisione > App > RosettaHealth e abilita tutti i permessi."
        case .healthKitDatabaseLocked:
            return "L'importazione è stata sospesa. Verrà ripresa automaticamente quando sbloccherai il telefono col FaceID."
        case .missingSampleType, .ingestionFailed:
            return "Controlla lo stato dei sensori e dei permessi."
        case .cfMismatch:
            return "Per evitare inquinamento di Apple Salute, il salvataggio automatico è stato bloccato."
        case .familyVaultRequiresPro:
            return "Abbonati a RosettaHealth PRO per sbloccare la gestione multi-paziente."
        case .appGroupContainerUnavailable, .corruptedPendingFile, .diskWriteFailed:
            return "Verifica che gli App Groups Entitlements siano configurati correttamente nel progetto Xcode."
        }
    }
}
