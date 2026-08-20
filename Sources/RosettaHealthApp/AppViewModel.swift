import Foundation
import SwiftUI
import HealthKit
import RosettaHealthCore

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var isProcessing = false
    @Published public var activeError: RosettaError?
    @Published public var currentBundle: FHIRBundle?
    @Published public var extractedObservations: [FHIRObservation] = []
    @Published public var syncedSamplesCount: Int = 0
    @Published public var skippedCodes: [String] = []
    @Published public var isOCRExtracted = false
    @Published public var isHealthKitAuthorized = false
    
    private let transcoder = RosettaTranscoder()
    private let healthBridge = HealthKitBridge()
    
    public let appGroupIdentifier = "group.dev.alexmaina.rosettahealth"
    
    public init() {}
    
    public func requestHealthKitAccess() async {
        do {
            try await healthBridge.requestAuthorization()
            self.isHealthKitAuthorized = true
            await syncPendingDocuments()
        } catch let error as RosettaError {
            self.activeError = error
        } catch {
            self.activeError = .healthKitUnavailable
        }
    }
    
    public func syncPendingDocuments() async {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: groupURL, includingPropertiesForKeys: nil)
            
            // Separiamo i file CDA XML puri e i PDF da elaborare
            let pendingXMLs = files.filter { $0.lastPathComponent.hasPrefix("PendingCDA_") && $0.pathExtension == "xml" }
            let pendingPDFs = files.filter { $0.lastPathComponent.hasPrefix("PendingPDF_") && $0.pathExtension == "pdf" }
            
            var totalSynced = 0
            var newSkipped: [String] = []
            
            for file in pendingXMLs {
                if let xmlData = try? Data(contentsOf: file) {
                    do {
                        _ = try await healthBridge.ingestCDADocument(xmlData: xmlData)
                        let bundle = try transcoder.transcode(cdaData: xmlData)
                        let result = try await healthBridge.ingestQuantities(fhirBundle: bundle)
                        totalSynced += result.savedCount
                        newSkipped.append(contentsOf: result.skippedObservations.map { $0.code.text ?? $0.code.coding.first?.display ?? $0.code.coding.first?.code ?? "Parametro Sconosciuto" })
                        try FileManager.default.removeItem(at: file)
                    } catch let err as RosettaError {
                        self.activeError = err
                    } catch {
                        self.activeError = .ingestionFailed(underlying: error.localizedDescription)
                    }
                } else {
                    self.activeError = .corruptedPendingFile(fileName: file.lastPathComponent)
                    try? FileManager.default.removeItem(at: file)
                }
            }
            
            for file in pendingPDFs {
                // Sfruttiamo il metodo esistente che sa già smistare le ExtractionResult
                await processPDF(url: file)
                try? FileManager.default.removeItem(at: file)
            }
            
            if totalSynced > 0 {
                self.syncedSamplesCount += totalSynced
            }
            if !newSkipped.isEmpty {
                self.skippedCodes = Array(Set(newSkipped))
            }
        } catch {
            print("Errore durante la sincronizzazione: \(error)")
        }
    }
    
    public func processPDF(url: URL) async {
        isProcessing = true
        activeError = nil
        skippedCodes.removeAll()
        isOCRExtracted = false
        self.extractedObservations.removeAll()
        
        do {
            let extractionResult = try await PDFEmbeddedAttachmentExtractor.extract(from: url)
            
            switch extractionResult {
            case .cdaXML(let xmlData):
                // Flusso CDA Normale (Archivio Ufficiale)
                _ = try await healthBridge.ingestCDADocument(xmlData: xmlData)
                
                let bundle = try transcoder.transcode(cdaData: xmlData)
                self.currentBundle = bundle
                
                self.extractedObservations = bundle.entry.compactMap { entry in
                    if case .observation(let obs) = entry.resource { return obs }
                    return nil
                }
                
                let result = try await healthBridge.ingestQuantities(fhirBundle: bundle)
                self.syncedSamplesCount += result.savedCount
                self.skippedCodes = Array(Set(result.skippedObservations.map { $0.code.text ?? $0.code.coding.first?.display ?? $0.code.coding.first?.code ?? "Parametro Sconosciuto" }))
                
            case .rasterOCR(let metrics):
                // Flusso Fallback (Graceful Degradation)
                self.isOCRExtracted = true
                
                // Mappiamo le ExtractedMetric in FHIRObservation per popolare la UI
                self.extractedObservations = metrics.map { metric in
                    return FHIRObservation(
                        id: UUID().uuidString,
                        status: "final",
                        code: FHIRCodeableConcept(
                            coding: [FHIRCoding(system: "http://loinc.org", code: metric.loincCode, display: metric.name)],
                            text: metric.name
                        ),
                        effectiveDateTime: ISO8601DateFormatter().string(from: metric.date),
                        valueQuantity: FHIRQuantity(value: metric.value, unit: metric.unit, system: "http://unitsofmeasure.org", code: metric.unit),
                        valueString: nil,
                        referenceRange: nil
                    )
                }
                
                let count = try await healthBridge.ingestRawMetrics(metrics: metrics)
                self.syncedSamplesCount += count
            }
            
        } catch let err as RosettaError {
            self.activeError = err
        } catch {
            self.activeError = .malformedXML(underlying: error.localizedDescription)
        }
        
        isProcessing = false
    }
    
    public func exportFHIRJSON() -> URL? {
        guard let bundle = currentBundle else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(bundle) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("FHIR_Report_\(UUID().uuidString.prefix(8)).json")
        try? data.write(to: tempURL)
        return tempURL
    }
}
