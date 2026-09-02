import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import UIKit

@available(iOS 17.0, *)
public final class SpotlightManager {
    public static let shared = SpotlightManager()
    private let domainIdentifier = "com.rosettahealth.vault"
    
    private init() {}
    
    /// Indicizza un referto nel motore di ricerca Spotlight dell'iPhone
    public func indexDocument(id: String, title: String, patientName: String, date: Date) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .pdf)
        attributeSet.title = title
        attributeSet.contentDescription = "Referto Medico di \(patientName) del \(date.formatted(date: .abbreviated, time: .omitted))"
        attributeSet.keywords = ["RosettaHealth", "Referto", "Salute", "Analisi", patientName, "FSE"]
        
        // Aggiunge un'icona se disponibile (qui usiamo un'immagine di sistema generica se configurabile, 
        // altrimenti Spotlight userà l'icona dell'app)
        
        let item = CSSearchableItem(
            uniqueIdentifier: id,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                // Log rimosso per privacy e pulizia")
            } else {
                // Log rimosso per privacy e pulizia indicizzato con successo in Spotlight.")
            }
        }
    }
    
    /// Rimuove un referto da Spotlight (es. se viene eliminato dal Vault)
    public func deindexDocument(id: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id]) { error in
            if let error = error {
                // Log rimosso per privacy e pulizia")
            }
        }
    }
}
