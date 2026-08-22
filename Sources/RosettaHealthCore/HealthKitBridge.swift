import Foundation
import HealthKit

public final class HealthKitBridge {
    private let healthStore = HKHealthStore()
    
    // MARK: - Mappa Estesa LOINC -> HKQuantityTypeIdentifier & Unità Target
    public struct MetricTarget {
        let type: HKQuantityTypeIdentifier
        let defaultUnit: HKUnit
        let conversion: ((Double, String) -> Double)? 
        
        init(type: HKQuantityTypeIdentifier, defaultUnit: HKUnit, conversion: ((Double, String) -> Double)? = nil) {
            self.type = type
            self.defaultUnit = defaultUnit
            self.conversion = conversion
        }
    }
    
    public private(set) var loincToHKMap: [String: MetricTarget] = [
        "15074-8": MetricTarget(type: .bloodGlucose, defaultUnit: HKUnit(from: "mg/dL")), 
        "2345-7":  MetricTarget(type: .bloodGlucose, defaultUnit: HKUnit(from: "mg/dL")), 
        "2339-0":  MetricTarget(type: .bloodGlucose, defaultUnit: HKUnit(from: "mg/dL")), 
        "4548-4":  MetricTarget(type: .bloodGlucose, defaultUnit: HKUnit.percent()),      
        "17856-6": MetricTarget(type: .bloodGlucose, defaultUnit: HKUnit.percent()),      
        "25428-4": MetricTarget(type: .bloodGlucose, defaultUnit: HKUnit.percent()),      
        "2093-3":  MetricTarget(type: .dietaryCholesterol, defaultUnit: HKUnit(from: "mg/dL")), 
        "2085-9":  MetricTarget(type: .dietaryCholesterol, defaultUnit: HKUnit(from: "mg/dL")), 
        "13457-7": MetricTarget(type: .dietaryCholesterol, defaultUnit: HKUnit(from: "mg/dL")), 
        "2571-8":  MetricTarget(type: .dietaryCholesterol, defaultUnit: HKUnit(from: "mg/dL")), 
        "8867-4":  MetricTarget(type: .heartRate, defaultUnit: HKUnit.count().unitDivided(by: .minute())), 
        "8480-6":  MetricTarget(type: .bloodPressureSystolic, defaultUnit: HKUnit.millimeterOfMercury()),  
        "8462-4":  MetricTarget(type: .bloodPressureDiastolic, defaultUnit: HKUnit.millimeterOfMercury()), 
        "2708-6":  MetricTarget(type: .oxygenSaturation, defaultUnit: HKUnit.percent()),                    
        "59408-5": MetricTarget(type: .oxygenSaturation, defaultUnit: HKUnit.percent()),                    
        "9279-1":  MetricTarget(type: .respiratoryRate, defaultUnit: HKUnit.count().unitDivided(by: .minute())), 
        "8310-5":  MetricTarget(type: .bodyTemperature, defaultUnit: HKUnit.degreeCelsius()),               
        "56478-1": MetricTarget(type: .bloodAlcoholContent, defaultUnit: HKUnit.percent()), 
        "2951-2":  MetricTarget(type: .dietarySodium, defaultUnit: HKUnit.gramUnit(with: .milli)), 
        "2823-3":  MetricTarget(type: .dietaryPotassium, defaultUnit: HKUnit.gramUnit(with: .milli)), 
        "17861-6": MetricTarget(type: .dietaryCalcium, defaultUnit: HKUnit.gramUnit(with: .milli)), 
        "2498-4":  MetricTarget(type: .dietaryIron, defaultUnit: HKUnit.gramUnit(with: .milli)) 
    ]
    
    private var cdaType: HKDocumentType? {
        if #available(iOS 10.0, *) {
            return HKObjectType.documentType(forIdentifier: .CDA)
        }
        return nil
    }
    
    public init() {}
    
    // MARK: - Richiesta Autorizzazione Ibrida
    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw RosettaError.healthKitUnavailable
        }
        
        let quantityTypes = Set(loincToHKMap.values.compactMap { HKQuantityType.quantityType(forIdentifier: $0.type) })
        var typesToWrite: Set<HKSampleType> = quantityTypes
        var typesToRead: Set<HKObjectType> = quantityTypes
        
        if let documentType = cdaType {
            typesToWrite.insert(documentType)
            typesToRead.insert(documentType)
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        } catch {
            throw RosettaError.authorizationDenied
        }
    }
    
    // MARK: - Ingestione Documento CDA (Referto Completo)
    public func ingestCDADocument(xmlData: Data, documentDate: Date = Date(), title: String = "Referto Sanitario FSE") async throws -> HKCDADocumentSample {
        guard let documentType = cdaType else {
            throw RosettaError.missingSampleType(identifier: "HKDocumentTypeIdentifier.CDA")
        }
        
        let metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: "FSE-\(UUID().uuidString)",
            HKMetadataKeySyncVersion: 1,
            "DocumentTitle": title
        ]
        
        let cdaSample = try HKCDADocumentSample(
            data: xmlData,
            start: documentDate,
            end: documentDate,
            metadata: metadata
        )
        
        do {
            try await healthStore.save(cdaSample)
        } catch {
            throw RosettaError.ingestionFailed(underlying: error.localizedDescription)
        }
        
        return cdaSample
    }
    
    // MARK: - Fetch Historical Data (Per Clinical Decision Support)
    public func fetchHistoricalSamples(for identifier: HKQuantityTypeIdentifier, limit: Int = 3) async throws -> [HKQuantitySample] {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw RosettaError.missingSampleType(identifier: identifier.rawValue)
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: limit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: RosettaError.ingestionFailed(underlying: error.localizedDescription))
                    return
                }
                
                if let quantitySamples = samples as? [HKQuantitySample] {
                    continuation.resume(returning: quantitySamples)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Ingestione Quantitativa Selettiva (Grafici Salute)
    public struct IngestionResult {
        public let savedCount: Int
        public let skippedObservations: [FHIRObservation]
    }
    
    public func ingestQuantities(fhirBundle: FHIRBundle) async throws -> IngestionResult {
        var samplesToSave: [HKQuantitySample] = []
        var skipped: [FHIRObservation] = []
        let isoFormatter = ISO8601DateFormatter()
        
        for entry in fhirBundle.entry {
            if case .observation(let obs) = entry.resource {
                guard let coding = obs.code.coding.first,
                      let metric = loincToHKMap[coding.code],
                      let sampleType = HKQuantityType.quantityType(forIdentifier: metric.type) else {
                    skipped.append(obs)
                    continue
                }
                
                var finalValue: Double? = nil
                
                if let quantity = obs.valueQuantity {
                    finalValue = metric.conversion?(quantity.value, quantity.unit) ?? quantity.value
                } else if let valueString = obs.valueString {
                    // Fallback per Pressione Arteriosa composita "120/80" o testuale
                    if metric.type == .bloodPressureSystolic || metric.type == .bloodPressureDiastolic {
                        let components = valueString.split(separator: "/")
                        if components.count == 2 {
                            if metric.type == .bloodPressureSystolic {
                                finalValue = Double(components[0].trimmingCharacters(in: .whitespacesAndNewlines))
                            } else if metric.type == .bloodPressureDiastolic {
                                finalValue = Double(components[1].trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                        }
                    }
                    if finalValue == nil {
                        finalValue = Double(valueString.trimmingCharacters(in: .letters.union(.whitespacesAndNewlines)))
                    }
                }
                
                guard let rawValue = finalValue else {
                    skipped.append(obs)
                    continue
                }
                
                let date = isoFormatter.date(from: obs.effectiveDateTime) ?? Date()
                let hkQuantity = HKQuantity(unit: metric.defaultUnit, doubleValue: rawValue)
                let sample = HKQuantitySample(
                    type: sampleType,
                    quantity: hkQuantity,
                    start: date,
                    end: date,
                    metadata: [
                        HKMetadataKeyExternalUUID: obs.id,
                        HKMetadataKeySyncIdentifier: "FSE-\(obs.id)",
                        "LOINC_CODE": coding.code,
                        "ORIGINAL_NAME": obs.code.text ?? coding.display ?? "Esame"
                    ]
                )
                samplesToSave.append(sample)
            }
        }
        
        if !samplesToSave.isEmpty {
            do {
                try await healthStore.save(samplesToSave)
            } catch {
                throw RosettaError.ingestionFailed(underlying: error.localizedDescription)
            }
        }
        
        return IngestionResult(savedCount: samplesToSave.count, skippedObservations: skipped)
    }
    
    // MARK: - Ingestione Metriche Estratte via OCR (Piano C)
    public func ingestRawMetrics(metrics: [ExtractedMetric]) async throws -> Int {
        var samplesToSave: [HKQuantitySample] = []
        
        for metric in metrics {
            guard let metricTarget = loincToHKMap[metric.loincCode],
                  let sampleType = HKQuantityType.quantityType(forIdentifier: metricTarget.type) else {
                continue
            }
            
            let hkQuantity = HKQuantity(unit: metricTarget.defaultUnit, doubleValue: metric.value)
            
            // Provenance metadata come richiesto per Graceful Degradation
            let metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: "OCR-VISION-\(UUID().uuidString)",
                HKMetadataKeyExternalUUID: UUID().uuidString,
                "EXTRACTION_METHOD": "APPLE_VISION_OCR_FALLBACK",
                "CONFIDENCE_LEVEL": "HEURISTIC_REGEX",
                "ORIGINAL_NAME": metric.name
            ]
            
            let sample = HKQuantitySample(
                type: sampleType,
                quantity: hkQuantity,
                start: metric.date,
                end: metric.date,
                metadata: metadata
            )
            samplesToSave.append(sample)
        }
        
        if !samplesToSave.isEmpty {
            do {
                try await healthStore.save(samplesToSave)
            } catch {
                throw RosettaError.ingestionFailed(underlying: error.localizedDescription)
            }
        }
        
        return samplesToSave.count
    }
}
