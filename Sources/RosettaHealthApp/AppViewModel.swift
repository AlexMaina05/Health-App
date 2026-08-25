import Foundation
import SwiftUI
import Observation
import HealthKit
import RosettaHealthCore
import ActivityKit
import OSLog
import UserNotifications
import SwiftData
import UIKit

@MainActor
public final class AppViewModel {
    public var isProcessing = false
    public var activeError: RosettaError?
    public var currentBundle: FHIRBundle?
    public var extractedObservations: [FHIRObservation] = []
    public var syncedSamplesCount: Int = 0
    public var skippedCodes: [String] = []
    public var isOCRExtracted = false
    public var isHealthKitAuthorized = false
    
    public var isSuccess: Bool = false
    public var feedbackTrigger: Int = 0
    public var parsingActivity: Any? = nil
    
    public var isAnonymousMode: Bool {
        ownerFiscalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var ownerFiscalCode: String { KeychainManager.shared.read(key: "ownerFiscalCode") ?? "" }
    @AppStorage("isCDSActive") public var isCDSActive: Bool = true
    @AppStorage("isOCREnabled") public var isOCREnabled: Bool = true
    @AppStorage("isProUnlocked") public var isProUnlocked: Bool = false
    
    private let transcoder = RosettaTranscoder()
    private let healthBridge = HealthKitBridge()
    private let logger = Logger(subsystem: "dev.alexmaina.rosettahealth", category: "AppViewModel")
    
    public let appGroupIdentifier = "group.dev.alexmaina.rosettahealth"
    
    public init() {}
    
    public func requestHealthKitAccess(modelContext: ModelContext? = nil) async {
        do {
            try await healthBridge.requestAuthorization()
            self.isHealthKitAuthorized = true
            
            // Richiesta permessi notifiche per il Clinical Decision Support (CDS)
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            await syncPendingDocuments(modelContext: modelContext)
        } catch let error as RosettaError {
            self.activeError = error
        } catch {
            self.activeError = .healthKitUnavailable
        }
    }
    
    public func syncPendingDocuments(modelContext: ModelContext? = nil) async {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: groupURL, includingPropertiesForKeys: nil)
            let pendingXMLs = files.filter { $0.lastPathComponent.hasPrefix("PendingCDA_") && $0.pathExtension == "xml" }
            let pendingPDFs = files.filter { $0.lastPathComponent.hasPrefix("PendingPDF_") && $0.pathExtension == "pdf" }
            
            if pendingXMLs.isEmpty && pendingPDFs.isEmpty { return }
            
            isProcessing = true
            
            var totalSynced = 0
            var newSkipped: [String] = []
            var newObservations: [FHIRObservation] = []
            var wasOCRUsed = false
            
            // 1. Processa XML Nativi
            for file in pendingXMLs {
                defer { try? FileManager.default.removeItem(at: file) }
                if let xmlData = try? Data(contentsOf: file) {
                    do {
                        if #available(iOS 16.1, *) { self.updateLiveActivity(status: "Transcodifica in FHIR...", progress: 0) }
                        let bundle = try transcoder.transcode(cdaData: xmlData)
                        let patientInfo = extractPatientInfo(bundle: bundle)
                        
                        self.currentBundle = bundle // Conserva l'ultimo bundle per eventuale export
                        newObservations.append(contentsOf: bundle.entry.compactMap { if case .observation(let o) = $0.resource { return o } else { return nil } })
                        
                        // Apple Salute (Solo se Proprietario)
                        if patientInfo.isOwner {
                            _ = try await healthBridge.ingestCDADocument(xmlData: xmlData)
                            let result = try await healthBridge.ingestQuantities(fhirBundle: bundle)
                            totalSynced += result.savedCount
                            newSkipped.append(contentsOf: result.skippedObservations.map { $0.code.text ?? $0.code.coding.first?.display ?? $0.code.coding.first?.code ?? "Parametro Sconosciuto" })
                        }
                        
                        // Vault Locale (SwiftData)
                        if !patientInfo.isOwner && !isProUnlocked {
                            throw RosettaError.familyVaultRequiresPro
                        }
                        if let context = modelContext {
                            let encoder = JSONEncoder()
                            if let jsonData = try? encoder.encode(bundle) {
                                let title = bundle.type == "document" ? "Fascicolo Sanitario" : "Referto"
                                let vaultDoc = VaultDocument(
                                    patientName: patientInfo.name,
                                    fiscalCode: patientInfo.cf,
                                    documentTitle: title,
                                    documentDate: Date(),
                                    fhirBundleJSON: jsonData,
                                    pdfData: try? Data(contentsOf: file)
                                )
                                context.insert(vaultDoc)
                                  if #available(iOS 26.0, *) {
                                      SpotlightManager.shared.indexDocument(
                                          id: vaultDoc.id.uuidString,
                                          title: vaultDoc.documentTitle,
                                          patientName: vaultDoc.patientName,
                                          date: vaultDoc.dateAdded
                                      )
                                  }
                                try? context.save()
                            }
                        }
                        
                        // defer fa già il lavoro
                    } catch let err as RosettaError {
                        self.activeError = err
                    } catch {
                        self.activeError = .malformedXML(underlying: error.localizedDescription)
                    }
                } else {
                    self.activeError = .corruptedPendingFile(fileName: file.lastPathComponent)
                    try? FileManager.default.removeItem(at: file)
                }
            }
            
            // 2. Processa PDF Raster (OCR Fallback) in modo incrementale
            for file in pendingPDFs {
                do {
                    let extractionResult = try await PDFEmbeddedAttachmentExtractor.extract(from: file)
                    if case .rasterOCR(let metrics) = extractionResult, isOCREnabled {
                        wasOCRUsed = true
                        let mappedObs = metrics.map { metric in
                            return FHIRObservation(
                                id: UUID().uuidString,
                                status: "final",
                                code: FHIRCodeableConcept(
                                    coding: [FHIRCoding(system: "http://loinc.org", code: metric.loincCode, display: metric.name)],
                                    text: metric.name
                                ),
                                effectiveDateTime: ISO8601DateFormatter().string(from: metric.date),
                                valueQuantity: FHIRQuantity(value: metric.value, unit: metric.unit, system: "http://unitsofmeasure.org", code: metric.unit)
                            )
                        }
                        newObservations.append(contentsOf: mappedObs)
                        // OCR Ingestion disattivata per GDPR
                    }
                } catch {
                    logger.error("Errore fallback OCR su file condiviso: \(error.localizedDescription)")
                }
                try? FileManager.default.removeItem(at: file)
            }
            
            // Aggiornamento finale cumulativo della UI
            if totalSynced > 0 { self.syncedSamplesCount += totalSynced }
            if !newSkipped.isEmpty { self.skippedCodes.append(contentsOf: Array(Set(newSkipped))) }
            if !newObservations.isEmpty { self.extractedObservations.append(contentsOf: newObservations) }
            if wasOCRUsed { self.isOCRExtracted = true }
            
            self.isSuccess = true
            self.feedbackTrigger += 1
            if #available(iOS 16.1, *) { self.endLiveActivity(status: "Completato con successo!") }
            isProcessing = false
            
        } catch {
            self.isSuccess = false
            self.feedbackTrigger += 1
            if #available(iOS 16.1, *) { self.endLiveActivity(status: "Errore durante l'analisi.") }
            logger.error("Errore grave durante la lettura del container: \(error.localizedDescription)")
            isProcessing = false
        }
    }
    
    public func processPDF(url: URL, modelContainer: Any? = nil) async {
        isProcessing = true
        activeError = nil
        skippedCodes.removeAll()
        isOCRExtracted = false
        self.extractedObservations.removeAll()
        self.currentBundle = nil
        
        do {
            let extractionResult = try await PDFEmbeddedAttachmentExtractor.extract(from: url)
            
            switch extractionResult {
            case .cdaXML(let xmlData):
                if #available(iOS 16.1, *) { self.updateLiveActivity(status: "Transcodifica in FHIR...", progress: 0) }
                        let bundle = try transcoder.transcode(cdaData: xmlData)
                let patientInfo = extractPatientInfo(bundle: bundle)
                
                self.currentBundle = bundle
                self.extractedObservations = bundle.entry.compactMap { if case .observation(let obs) = $0.resource { return obs } else { return nil } }
                
                // 1. Apple Salute (Solo se è il proprietario)
                if patientInfo.isOwner {
                    _ = try await healthBridge.ingestCDADocument(xmlData: xmlData)
                    let result = try await healthBridge.ingestQuantities(fhirBundle: bundle)
                    self.syncedSamplesCount += result.savedCount
                    self.skippedCodes = Array(Set(result.skippedObservations.map { $0.code.text ?? $0.code.coding.first?.display ?? $0.code.coding.first?.code ?? "Parametro Sconosciuto" }))
                } else {
                    guard isProUnlocked else {
                        throw RosettaError.familyVaultRequiresPro
                    }
                    logger.notice("Referto di \(patientInfo.name) deviato verso il Family Vault (Bypass HealthKit).")
                }
                
                // 2. Salvataggio nel Vault Locale (SwiftData)
                if let context = modelContext as? SwiftData.ModelContext {
                    let encoder = JSONEncoder()
                    if let jsonData = try? encoder.encode(bundle) {
                        let title = bundle.type == "document" ? "Fascicolo Sanitario" : "Referto"
                        let vaultDoc = VaultDocument(
                            patientName: patientInfo.name,
                            fiscalCode: patientInfo.cf,
                            documentTitle: title,
                            documentDate: Date(),
                            fhirBundleJSON: jsonData,
                            pdfData: try? Data(contentsOf: url)
                        )
                        context.insert(vaultDoc)
                                  if #available(iOS 26.0, *) {
                                      SpotlightManager.shared.indexDocument(
                                          id: vaultDoc.id.uuidString,
                                          title: vaultDoc.documentTitle,
                                          patientName: vaultDoc.patientName,
                                          date: vaultDoc.dateAdded
                                      )
                                  }
                        try? context.save()
                    }
                }
                
            case .rasterOCR(let metrics):
                guard isOCREnabled else {
                    throw RosettaError.malformedXML(underlying: "Allegato XML non trovato e l'Estrazione Ottica (OCR) è disattivata nelle impostazioni.")
                }
                
                self.isOCRExtracted = true
                self.extractedObservations = metrics.map { metric in
                    return FHIRObservation(
                        id: UUID().uuidString,
                        status: "final",
                        code: FHIRCodeableConcept(
                            coding: [FHIRCoding(system: "http://loinc.org", code: metric.loincCode, display: metric.name)],
                            text: metric.name
                        ),
                        effectiveDateTime: ISO8601DateFormatter().string(from: metric.date),
                        valueQuantity: FHIRQuantity(value: metric.value, unit: metric.unit, system: "http://unitsofmeasure.org", code: metric.unit)
                    )
                }
                // Ingestione disattivata per approvazione manuale (Human-in-the-loop)
            }
        } catch let err as RosettaError {
            self.activeError = err
        } catch {
            self.activeError = .malformedXML(underlying: error.localizedDescription)
        }
        
        // Aggiorna i dati per il Widget (Lock Screen / Home Screen)
        updateWidgetData()
        
        // Esegue il modulo di Medicina Preventiva (CDS) in background
        if isCDSActive && !self.extractedObservations.isEmpty {
            await runClinicalDecisionSupport(for: self.extractedObservations)
        }
        
        self.isSuccess = (self.activeError == nil)
        self.feedbackTrigger += 1
        isProcessing = false
    }
    
    private func runClinicalDecisionSupport(for observations: [FHIRObservation]) async {
        let cds = ClinicalDecisionSupport()
        var checkedTypes: Set<HKQuantityTypeIdentifier> = []
        
        for obs in observations {
            guard let loinc = obs.code.coding.first?.code,
                  let target = healthBridge.loincToHKMap[loinc] else { continue }
            
            let hkType = target.type
            if checkedTypes.contains(hkType) { continue }
            checkedTypes.insert(hkType)
            
            do {
                let history = try await healthBridge.fetchHistoricalSamples(for: hkType, limit: 3)
                if let alert = await cds.analyze(samples: history, type: hkType) {
                    await cds.dispatchNotification(for: alert)
                }
            } catch {
                logger.error("Errore CDS per \\(hkType.rawValue): \\(error.localizedDescription)")
            }
        }
    }
    
    /// Salva un riepilogo delle metriche correnti nell'App Group per essere lette dal Widget
    private func updateWidgetData() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.dev.alexmaina.rosettahealth") else { return }
        
        // Prendiamo la prima osservazione estratta come highlight (es. Colesterolo o Glicemia)
        if let highlight = extractedObservations.first {
            let metricName = highlight.code.text ?? highlight.code.coding.first?.display ?? "Parametro"
            var metricValue = "N/D"
            if let qty = highlight.valueQuantity {
                metricValue = "\(qty.value) \(qty.unit)"
            } else if let str = highlight.valueString {
                metricValue = str
            }
            
            sharedDefaults.set(metricName, forKey: "widget_metricName")
            sharedDefaults.set(metricValue, forKey: "widget_metricValue")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "widget_lastUpdate")
        }
    }
        
    public func approveAndSaveOCR() async {
        guard isOCRExtracted, !extractedObservations.isEmpty else { return }
        do {
            let metrics = extractedObservations.compactMap { obs -> ExtractedMetric? in
                guard let name = obs.code.text ?? obs.code.coding.first?.display,
                      let loinc = obs.code.coding.first?.code,
                      let qty = obs.valueQuantity else { return nil }
                return ExtractedMetric(name: name, value: qty.value, unit: qty.unit, loincCode: loinc)
            }
            let count = try await healthBridge.ingestRawMetrics(metrics: metrics)
            await MainActor.run {
                self.syncedSamplesCount += count
                self.isOCRExtracted = false // Rimuove l'avviso una volta salvati
            }
        } catch {
            await MainActor.run {
                self.activeError = .pdfCorrupted // Generic error representation
            }
        }
    }

    public func exportFHIRJSON() -> URL? {
        guard let bundle = currentBundle else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(bundle) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("FHIR_Report_\(UUID().uuidString.prefix(8)).json")
        do {
            try data.write(to: tempURL, options: .completeFileProtectionUntilFirstUserAuthentication)
        } catch {
            return nil
        }
        return tempURL
    }
    
    /// Analizza il bundle e determina se appartiene al proprietario del telefono.
    /// Restituisce (isOwner, patientName, fiscalCode).
    private func extractPatientInfo(bundle: FHIRBundle) -> (isOwner: Bool, name: String, cf: String) {
        var pName = "Sconosciuto"
        var pCF = "Sconosciuto"
        
        if let patientEntry = bundle.entry.first(where: { if case .patient(_) = $0.resource { return true }; return false }),
           case .patient(let patient) = patientEntry.resource {
            
            pName = [patient.name?.first?.given?.first, patient.name?.first?.family].compactMap { $0 }.joined(separator: " ")
            if pName.isEmpty { pName = "Paziente Anonimo" }
            
            if let extractedCF = patient.identifier?.first(where: { $0.system == "http://hl7.it/sid/codiceFiscale" })?.value {
                pCF = extractedCF.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            }
        }
        
        let cleanOwnerCF = ownerFiscalCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let isOwner: Bool
        if cleanOwnerCF.isEmpty {
            // Modalità Anonima: Fallback su Name Matching (Fuzzy logic)
            let ownerFirst = UserDefaults.standard.string(forKey: "ownerFirstName")?.lowercased().trimmingCharacters(in: .whitespaces) ?? ""
            let ownerLast = UserDefaults.standard.string(forKey: "ownerLastName")?.lowercased().trimmingCharacters(in: .whitespaces) ?? ""
            let pNameLower = pName.lowercased()
            
            let isNameMatch = !ownerFirst.isEmpty && !ownerLast.isEmpty && pNameLower.contains(ownerFirst) && pNameLower.contains(ownerLast)
            isOwner = (pCF == "Sconosciuto" && isNameMatch)
        } else {
            isOwner = (pCF == cleanOwnerCF)
        }
        
        return (isOwner, pName, pCF)
    }
    @available(iOS 16.1, *)
    private func startLiveActivity(fileName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = ParsingAttributes(batchName: "Analisi Referto: \(fileName)")
        let state = ParsingAttributes.ContentState(processedFiles: 0, totalFiles: 1, statusText: "Decrittazione in corso...")
        
        do {
            let activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            self.parsingActivity = activity
        } catch {
            logger.error("Impossibile avviare Live Activity: \(error)")
        }
    }
    
    @available(iOS 16.1, *)
    private func updateLiveActivity(status: String, progress: Int) {
        guard let activity = self.parsingActivity as? Activity<ParsingAttributes> else { return }
        let state = ParsingAttributes.ContentState(processedFiles: progress, totalFiles: 1, statusText: status)
        
        Task {
            await activity.update(using: state)
        }
    }
    
    @available(iOS 16.1, *)
    private func endLiveActivity(status: String) {
        guard let activity = self.parsingActivity as? Activity<ParsingAttributes> else { return }
        let state = ParsingAttributes.ContentState(processedFiles: 1, totalFiles: 1, statusText: status)
        
        Task {
            await activity.end(using: state, dismissalPolicy: .default)
            self.parsingActivity = nil
        }
    }

}
