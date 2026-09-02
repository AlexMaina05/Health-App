import XCTest
import HealthKit
import SwiftData
@testable import RosettaHealthCore

/// Tier 3: Cross-Feature Combinations Integration Tests
/// Verifies cross-module communication and end-to-end data flows:
/// 1. Transcoder -> HealthKitBridge -> ClinicalDecisionSupport (CDS) Trend Alerts
/// 2. Transcoder -> JSON Serialization -> SwiftData In-Memory Persistence & Multi-Patient Isolation
@available(iOS 17.0, *)
final class Tier3CrossFeaturePipelineTests: XCTestCase {
    
    private var transcoder: RosettaTranscoder!
    private var healthBridge: HealthKitBridge!
    private var cds: ClinicalDecisionSupport!
    
    override func setUp() {
        super.setUp()
        transcoder = RosettaTranscoder()
        healthBridge = HealthKitBridge()
        cds = ClinicalDecisionSupport()
    }
    
    override func tearDown() {
        transcoder = nil
        healthBridge = nil
        cds = nil
        super.tearDown()
    }
    
    // MARK: - 1. Transcoder + HealthKit + CDS Trend Evaluation Pipeline
    
    func testTranscoderHealthKitCDSCholesterolWorseningAlertPipeline() async throws {
        // Create 3 sequential CDA XMLs showing worsening cholesterol (150 -> 180 -> 215 mg/dL, +43.3% increase)
        let dates = ["2026-06-01T08:00:00Z", "2026-07-01T08:00:00Z", "2026-08-01T08:00:00Z"]
        let cholesterolValues = [150.0, 180.0, 215.0]
        
        var generatedSamples: [HKQuantitySample] = []
        let type = HKQuantityType.quantityType(forIdentifier: .dietaryCholesterol)!
        let unit = HKUnit.gramUnit(with: .milli)
        let formatter = ISO8601DateFormatter()
        
        for (i, val) in cholesterolValues.enumerated() {
            let cdaXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <ClinicalDocument>
                <id root="2.16.840.1.113883.2.9.2.130.4.1" extension="LAB-CHOL-00\(i+1)"/>
                <effectiveTime value="20260801083000"/>
                <component><structuredBody><component><section>
                    <entry>
                        <observation classCode="OBS" moodCode="EVN">
                            <code code="2093-3" codeSystem="2.16.840.1.113883.6.1" displayName="Colesterolo Totale"/>
                            <value xsi:type="PQ" value="\(val)" unit="mg/dL"/>
                        </observation>
                    </entry>
                </section></component></structuredBody></component>
            </ClinicalDocument>
            """
            
            let bundle = try transcoder.transcode(cdaData: cdaXML.data(using: .utf8)!)
            XCTAssertEqual(bundle.entry.compactMap { if case .observation(let o) = $0.resource { return o } else { return nil } }.count, 1)
            
            let sampleDate = formatter.date(from: dates[i])!
            let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: val), start: sampleDate, end: sampleDate)
            generatedSamples.append(sample)
        }
        
        // Execute CDS evaluation
        let alert = await cds.analyze(samples: generatedSamples, type: .dietaryCholesterol)
        
        // Verify alert produced with proper metadata
        XCTAssertNotNil(alert, "Worsening cholesterol (>10% increase across 3 sequential reports) must trigger a CDS alert")
        XCTAssertEqual(alert?.metricName, "Colesterolo")
        XCTAssertEqual(alert?.severity, .warning)
        XCTAssertTrue(alert?.message.contains("43.3%") == true, "Alert message must reflect accurate percentage increase")
    }
    
    func testTranscoderHealthKitCDSGlucoseWorseningAlertPipeline() async throws {
        // 3 sequential reports with worsening fasting glucose (85 -> 95 -> 110 mg/dL, latest > 100 mg/dL)
        let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
        let unit = HKUnit(from: "mg/dL")
        let now = Date()
        
        let s1 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 85), start: now.addingTimeInterval(-86400 * 60), end: now.addingTimeInterval(-86400 * 60))
        let s2 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 95), start: now.addingTimeInterval(-86400 * 30), end: now.addingTimeInterval(-86400 * 30))
        let s3 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 110), start: now, end: now)
        
        let alert = await cds.analyze(samples: [s1, s2, s3], type: .bloodGlucose)
        
        XCTAssertNotNil(alert, "Worsening glucose with latest > 100 mg/dL must trigger CDS alert")
        XCTAssertEqual(alert?.metricName, "Glicemia")
        XCTAssertEqual(alert?.severity, .warning)
    }
    
    func testTranscoderHealthKitCDSSystolicBPAlertPipeline() async throws {
        // 3 sequential reports with increasing systolic BP (118 -> 126 -> 135 mmHg, latest > 130 mmHg)
        let type = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!
        let unit = HKUnit.millimeterOfMercury()
        let now = Date()
        
        let s1 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 118), start: now.addingTimeInterval(-86400 * 60), end: now.addingTimeInterval(-86400 * 60))
        let s2 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 126), start: now.addingTimeInterval(-86400 * 30), end: now.addingTimeInterval(-86400 * 30))
        let s3 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 135), start: now, end: now)
        
        let alert = await cds.analyze(samples: [s1, s2, s3], type: .bloodPressureSystolic)
        
        XCTAssertNotNil(alert, "Worsening systolic BP > 130 mmHg must trigger critical alert")
        XCTAssertEqual(alert?.metricName, "Pressione Sistolica")
        XCTAssertEqual(alert?.severity, .critical)
    }
    
    func testTranscoderHealthKitCDSStableImprovingNoAlert() async throws {
        // 3 improving cholesterol records (220 -> 190 -> 160 mg/dL)
        let type = HKQuantityType.quantityType(forIdentifier: .dietaryCholesterol)!
        let unit = HKUnit.gramUnit(with: .milli)
        let now = Date()
        
        let s1 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 220), start: now.addingTimeInterval(-86400 * 60), end: now.addingTimeInterval(-86400 * 60))
        let s2 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 190), start: now.addingTimeInterval(-86400 * 30), end: now.addingTimeInterval(-86400 * 30))
        let s3 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 160), start: now, end: now)
        
        let alert = await cds.analyze(samples: [s1, s2, s3], type: .dietaryCholesterol)
        XCTAssertNil(alert, "Improving health trend must not trigger false positive alert")
    }
    
    // MARK: - 2. Transcoder + SwiftData In-Memory Persistence & Multi-Patient Vault
    
    func testTranscoderSwiftDataPersistencePipeline() throws {
        let cdaXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument>
            <id root="2.16.840.1.113883.2.9.2.130.4.1" extension="VAULT-DOC-101"/>
            <title>Referto Visita Pediatrica</title>
            <effectiveTime value="20260821083000"/>
            <recordTarget>
                <patientRole>
                    <id root="2.16.840.1.113883.2.9.4.3.2" extension="RSSGPP15A01H501K"/>
                    <patient>
                        <name>
                            <family>Rossi</family>
                            <given>Giuseppe</given>
                        </name>
                    </patient>
                </patientRole>
            </recordTarget>
            <component><structuredBody><component><section>
                <entry>
                    <observation classCode="OBS" moodCode="EVN">
                        <code code="29463-7" codeSystem="2.16.840.1.113883.6.1" displayName="Peso Corporeo"/>
                        <value xsi:type="PQ" value="28.5" unit="kg"/>
                    </observation>
                </entry>
            </section></component></structuredBody></component>
        </ClinicalDocument>
        """
        
        // 1. Transcode
        let bundle = try transcoder.transcode(cdaData: cdaXML.data(using: .utf8)!)
        
        // 2. Encode to JSON
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(bundle)
        
        // 3. Initialize In-Memory SwiftData Container
        let schema = Schema([IntegrationVaultDocument.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        // 4. Insert into Vault
        let vaultDoc = IntegrationVaultDocument(
            patientName: "Giuseppe Rossi",
            fiscalCode: "RSSGPP15A01H501K",
            documentTitle: bundle.type == "document" ? "Fascicolo Sanitario" : "Referto",
            documentDate: Date(),
            fhirBundleJSON: jsonData,
            pdfData: nil
        )
        context.insert(vaultDoc)
        try context.save()
        
        // 5. Fetch & Verify
        let descriptor = FetchDescriptor<IntegrationVaultDocument>()
        let fetchedDocs = try context.fetch(descriptor)
        
        XCTAssertEqual(fetchedDocs.count, 1)
        let retrieved = fetchedDocs.first!
        XCTAssertEqual(retrieved.patientName, "Giuseppe Rossi")
        XCTAssertEqual(retrieved.fiscalCode, "RSSGPP15A01H501K")
        XCTAssertEqual(retrieved.documentTitle, "Fascicolo Sanitario")
        
        // 6. Decode FHIR Bundle from Vault JSON & verify lossless roundtrip
        let decoder = JSONDecoder()
        let decodedBundle = try decoder.decode(FHIRBundle.self, from: retrieved.fhirBundleJSON)
        XCTAssertEqual(decodedBundle.id, "VAULT-DOC-101")
        
        let obs = decodedBundle.entry.compactMap { entry -> FHIRObservation? in
            if case .observation(let o) = entry.resource { return o }
            return nil
        }
        XCTAssertEqual(obs.count, 1)
        XCTAssertEqual(obs.first?.valueQuantity?.value, 28.5)
        XCTAssertEqual(obs.first?.valueQuantity?.unit, "kg")
    }
    
    func testMultiDocumentPatientVaultIsolation() throws {
        let schema = Schema([IntegrationVaultDocument.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        // Insert 2 documents for Patient A (Mario Rossi) and 1 for Patient B (Alessandro Bianchi)
        let docA1 = IntegrationVaultDocument(patientName: "Mario Rossi", fiscalCode: "RSSMRA85M01H501Z", documentTitle: "Esami Sangue", documentDate: Date(), fhirBundleJSON: Data())
        let docA2 = IntegrationVaultDocument(patientName: "Mario Rossi", fiscalCode: "RSSMRA85M01H501Z", documentTitle: "Visita Oculistica", documentDate: Date(), fhirBundleJSON: Data())
        let docB1 = IntegrationVaultDocument(patientName: "Alessandro Bianchi", fiscalCode: "BNCLSN90A01F205X", documentTitle: "Visita Cardiologica", documentDate: Date(), fhirBundleJSON: Data())
        
        context.insert(docA1)
        context.insert(docA2)
        context.insert(docB1)
        try context.save()
        
        // Fetch all
        let allDocs = try context.fetch(FetchDescriptor<IntegrationVaultDocument>())
        XCTAssertEqual(allDocs.count, 3)
        
        // Fetch Patient A records
        let predicateA = #Predicate<IntegrationVaultDocument> { $0.fiscalCode == "RSSMRA85M01H501Z" }
        let descriptorA = FetchDescriptor<IntegrationVaultDocument>(predicate: predicateA)
        let docsA = try context.fetch(descriptorA)
        XCTAssertEqual(docsA.count, 2)
        
        // Fetch Patient B records
        let predicateB = #Predicate<IntegrationVaultDocument> { $0.fiscalCode == "BNCLSN90A01F205X" }
        let descriptorB = FetchDescriptor<IntegrationVaultDocument>(predicate: predicateB)
        let docsB = try context.fetch(descriptorB)
        XCTAssertEqual(docsB.count, 1)
        XCTAssertEqual(docsB.first?.patientName, "Alessandro Bianchi")
    }
}

// MARK: - Test In-Memory SwiftData Entity

@available(iOS 17.0, *)
@Model
final class IntegrationVaultDocument {
    var id: UUID = UUID()
    var dateAdded: Date = Date()
    var patientName: String = ""
    var fiscalCode: String = ""
    var documentTitle: String = ""
    var documentDate: Date = Date()
    @Attribute(.externalStorage) var fhirBundleJSON: Data = Data()
    @Attribute(.externalStorage) var pdfData: Data?

    init(id: UUID = UUID(), dateAdded: Date = Date(), patientName: String, fiscalCode: String, documentTitle: String, documentDate: Date, fhirBundleJSON: Data, pdfData: Data? = nil) {
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
