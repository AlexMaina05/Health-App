import Foundation
import HealthKit
import UserNotifications

/// Modulo per l'analisi dei trend clinici e la medicina preventiva
public actor ClinicalDecisionSupport {
    
    public init() {}
    
    /// Modello che descrive un allarme clinico generato
    public struct TrendAlert {
        public let metricName: String
        public let message: String
        public let severity: Severity
        
        public enum Severity {
            case info
            case warning
            case critical
        }
    }
    
    /// Analizza un set storico di campioni e restituisce un alert se viene rilevato un trend pericoloso
    public func analyze(samples: [HKQuantitySample], type: HKQuantityTypeIdentifier) -> TrendAlert? {
        guard samples.count >= 3 else { return nil }
        
        // I campioni da HK sono tipicamente ordinati dal più recente al più vecchio se presi tramite HKSampleQuery (sort: descending)
        // Assicuriamoci dell'ordine cronologico (indice 0 = più vecchio, indice 2 = più recente)
        let chronologicalSamples = samples.sorted(by: { $0.startDate < $1.startDate })
        let recent = Array(chronologicalSamples.suffix(3))
        
        let unit = recent[0].quantity.is(compatibleWith: HKUnit(from: "mg/dL")) ? HKUnit(from: "mg/dL") : HKUnit.count()
        let v1 = recent[0].quantity.doubleValue(for: unit)
        let v2 = recent[1].quantity.doubleValue(for: unit)
        let v3 = recent[2].quantity.doubleValue(for: unit)
        
        // Sostituisco con una conversione sicura senza hardcode delle unità per l'analisi numerica relativa
        // Prendiamo il valore numerico "puro" a prescindere dall'unità (assumendo che i 3 campioni abbiano la stessa unità)
        // Poiché non possiamo estrarre un double senza conoscere l'unità esatta, useremo un'euristica:
        // Se è Colesterolo, usiamo mg/dL.
        
        switch type {
        case .dietaryCholesterol: // Colesterolo
            let unit = HKUnit(from: "mg/dL")
            let s1 = recent[0].quantity.doubleValue(for: unit)
            let s2 = recent[1].quantity.doubleValue(for: unit)
            let s3 = recent[2].quantity.doubleValue(for: unit)
            
            // Trend in aumento (peggioramento del colesterolo)
            if s3 > s2 && s2 > s1 {
                let increase = s1 != 0 ? ((s3 - s1) / s1) * 100 : 0
                if increase > 10.0 {
                    return TrendAlert(
                        metricName: "Colesterolo",
                        message: String(format: "Attenzione: Colesterolo in aumento costante del %.1f%% negli ultimi 3 referti. Considera di consultare un medico.", increase),
                        severity: .warning
                    )
                }
            }
            
        case .bloodGlucose: // Glicemia
            let unit = HKUnit(from: "mg/dL")
            let s1 = recent[0].quantity.doubleValue(for: unit)
            let s2 = recent[1].quantity.doubleValue(for: unit)
            let s3 = recent[2].quantity.doubleValue(for: unit)
            
            if s3 > s2 && s2 > s1 {
                let increase = s1 != 0 ? ((s3 - s1) / s1) * 100 : 0
                if increase > 5.0 && s3 > 100.0 {
                    return TrendAlert(
                        metricName: "Glicemia",
                        message: "Glicemia a digiuno in peggioramento progressivo (ultimo valore oltre 100 mg/dL). Consigliato monitoraggio.",
                        severity: .warning
                    )
                }
            }
            
        case .bloodPressureSystolic: // Pressione Sistolica (Massima)
            let unit = HKUnit.millimeterOfMercury()
            let s1 = recent[0].quantity.doubleValue(for: unit)
            let s2 = recent[1].quantity.doubleValue(for: unit)
            let s3 = recent[2].quantity.doubleValue(for: unit)
            
            if s3 > s2 && s2 > s1 {
                if s3 > 130 {
                    return TrendAlert(
                        metricName: "Pressione Sistolica",
                        message: "La tua pressione massima è in aumento costante ed ha superato i 130 mmHg. Consigliato misurarla quotidianamente.",
                        severity: .critical
                    )
                }
            }
            
        default:
            break
        }
        
        return nil
    }
    
    /// Invia una notifica locale all'utente per allertarlo del trend
    public func dispatchNotification(for alert: TrendAlert) {
        let content = UNMutableNotificationContent()
        content.title = "RosettaHealth CDS (\(alert.metricName))"
        content.body = alert.message
        content.sound = .default
        
        // Se è critico, usiamo un suono più invadente (disponibile nativamente in iOS per le critical alerts se autorizzati)
        // Per ora usiamo il default.
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // trigger nullo = immediata
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                // Log rimosso per privacy e pulizia")
            }
        }
    }
}
