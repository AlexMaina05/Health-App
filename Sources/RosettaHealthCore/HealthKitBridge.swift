import Foundation
import HealthKit

public final class HealthKitBridge {
    public static let shared = HealthKitBridge()
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

        // MARK: - Glicemia & Metabolismo
        "15074-8": MetricTarget(type: .bloodGlucose, defaultUnit: HKUnit(from: "mg/dL")), 
        "2345-7":  MetricTarget(type: .bloodGlucose, defaultUnit: HKUnit(from: "mg/dL")), 
        "2339-0":  MetricTarget(type: .bloodGlucose, defaultUnit: HKUnit(from: "mg/dL")),
        
        // MARK: - Profilo Lipidico
        "2093-3":  MetricTarget(type: .dietaryCholesterol, defaultUnit: HKUnit.gramUnit(with: .milli)), 
        "2571-8":  MetricTarget(type: .dietaryFatTotal, defaultUnit: HKUnit.gramUnit(with: .milli)),
        
        // MARK: - Segni Vitali & Cardiologia
        "8867-4":  MetricTarget(type: .heartRate, defaultUnit: HKUnit.count().unitDivided(by: .minute())), 
        "8480-6":  MetricTarget(type: .bloodPressureSystolic, defaultUnit: HKUnit.millimeterOfMercury()),  
        "8462-4":  MetricTarget(type: .bloodPressureDiastolic, defaultUnit: HKUnit.millimeterOfMercury()), 
        "85354-9": MetricTarget(type: .bloodPressureSystolic, defaultUnit: HKUnit.millimeterOfMercury()),
        "55284-4": MetricTarget(type: .bloodPressureSystolic, defaultUnit: HKUnit.millimeterOfMercury()),
        "2708-6":  MetricTarget(type: .oxygenSaturation, defaultUnit: HKUnit.percent()),                    
        "59408-5": MetricTarget(type: .oxygenSaturation, defaultUnit: HKUnit.percent()),                    
        "9279-1":  MetricTarget(type: .respiratoryRate, defaultUnit: HKUnit.count().unitDivided(by: .minute())), 
        "8310-5":  MetricTarget(type: .bodyTemperature, defaultUnit: HKUnit.degreeCelsius()),               
        "80404-7": MetricTarget(type: .heartRateVariabilitySDNN, defaultUnit: HKUnit.secondUnit(with: .milli)), 
        
        // MARK: - Antropometria & Composizione Corporea
        "29463-7": MetricTarget(type: .bodyMass, defaultUnit: HKUnit.gramUnit(with: .kilo)),        // Peso
        "3141-9":  MetricTarget(type: .bodyMass, defaultUnit: HKUnit.gramUnit(with: .kilo)),        
        "8302-2":  MetricTarget(type: .height, defaultUnit: HKUnit.meter()),                        // Altezza
        "39156-5": MetricTarget(type: .bodyMassIndex, defaultUnit: HKUnit.count()),                 // BMI
        "8280-0":  MetricTarget(type: .waistCircumference, defaultUnit: HKUnit.meterUnit(with: .centi)), // Circonferenza Vita
        "41982-0": MetricTarget(type: .bodyFatPercentage, defaultUnit: HKUnit.percent()),           // Massa Grassa
        
        // MARK: - Elettroliti
        "2951-2": MetricTarget(type: .dietarySodium, defaultUnit: HKUnit.gramUnit(with: .milli)),
        "2823-3": MetricTarget(type: .dietaryPotassium, defaultUnit: HKUnit.gramUnit(with: .milli)),
        
        // MARK: - Vitamine
        "32220-6": MetricTarget(type: .dietaryVitaminC, defaultUnit: HKUnit.gramUnit(with: .milli)),
        "32309-7": MetricTarget(type: .dietaryVitaminD, defaultUnit: HKUnit.gramUnit(with: .micro)),
        
        // MARK: - Tossicologia & Altro
        "56478-1": MetricTarget(type: .bloodAlcoholContent, defaultUnit: HKUnit.percent()),
        "94122-8": MetricTarget(type: .vo2Max, defaultUnit: HKUnit(from: "ml/kg*min"))

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
        
        let docHash = String(format: "%08x", xmlData.hashValue)
        let metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: "FSE-DOC-\(docHash)",
            HKMetadataKeySyncVersion: 1,
            "DocumentTitle": title,
            "RosettaHealth_Signature": "✅ Transcodificato e validato in locale (Zero-Cloud)",
            "RosettaHealth_Engine": "v3.0 (HL7 CDA -> FHIR R4)"
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
        
        public init(savedCount: Int, skippedObservations: [FHIRObservation]) {
            self.savedCount = savedCount
            self.skippedObservations = skippedObservations
        }
    }
    
    private func isValidPhysiologically(value: Double, for type: HKQuantityTypeIdentifier) -> Bool {
        switch type {
        case .bloodGlucose: return value >= 10 && value <= 1500 // mg/dL estremi compatibili con la vita
        case .bloodPressureSystolic: return value >= 40 && value <= 350
        case .bloodPressureDiastolic: return value >= 20 && value <= 200
        case .heartRate: return value >= 10 && value <= 300
        case .oxygenSaturation: return (value >= 0.1 && value <= 1.0) || (value >= 10.0 && value <= 100.0) // 10% - 100%
        case .bodyTemperature: return value >= 20 && value <= 45 // Celsius
        case .bodyMass: return value >= 1 && value <= 600 // kg
        case .height: return value >= 0.3 && value <= 3.0 // metri
        default: return true // Pass-through per altri
        }
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
                
                // Physiological Validation Gate
                guard isValidPhysiologically(value: rawValue, for: metric.type) else {
                    skipped.append(obs)
                    continue
                }
                
                let date = isoFormatter.date(from: obs.effectiveDateTime) ?? Date()
                let hkQuantity = HKQuantity(unit: metric.defaultUnit, doubleValue: rawValue)
                let syncIdentifier = "FSE-\(fhirBundle.id)-\(coding.code)-\(obs.effectiveDateTime)"
                let sample = HKQuantitySample(
                    type: sampleType,
                    quantity: hkQuantity,
                    start: date,
                    end: date,
                    metadata: [
                        HKMetadataKeyExternalUUID: obs.id,
                        HKMetadataKeySyncIdentifier: syncIdentifier,
                        HKMetadataKeySyncVersion: 1,
                        "LOINC_CODE": coding.code,
                        "ORIGINAL_NAME": obs.code.text ?? coding.display ?? "Esame",
                        "RosettaHealth_Signature": "✅ Estratto e validato in locale da FSE",
                        "RosettaHealth_Engine": "v3.0"
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
            
            guard isValidPhysiologically(value: metric.value, for: metricTarget.type) else {
                continue
            }
            
            let hkQuantity = HKQuantity(unit: metricTarget.defaultUnit, doubleValue: metric.value)
            let syncIdentifier = "OCR-VISION-\(metric.loincCode)-\(Int(metric.date.timeIntervalSince1970))-\(metric.value)"
            
            // Provenance metadata come richiesto per Graceful Degradation
            let metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: syncIdentifier,
                HKMetadataKeySyncVersion: 1,
                HKMetadataKeyExternalUUID: UUID().uuidString,
                "EXTRACTION_METHOD": "APPLE_VISION_OCR_FALLBACK",
                "CONFIDENCE_LEVEL": "HEURISTIC_REGEX",
                "ORIGINAL_NAME": metric.name,
                "RosettaHealth_Signature": "⚠️ Estratto tramite Vision AI (Fallback)",
                "RosettaHealth_Engine": "v3.0 (Optical Character Recognition)"
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
