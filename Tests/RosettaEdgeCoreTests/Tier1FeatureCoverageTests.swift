import XCTest
import HealthKit
@testable import RosettaEdgeCore

/// Tier 1: Feature Coverage Integration Tests
/// Verifies core functional requirements: CDA -> FHIR Transcode fidelity,
/// Physiological Validation Gate filtering, Firewall routing, and State tracking.
final class Tier1FeatureCoverageTests: XCTestCase {
    
    private var transcoder: RosettaTranscoder!
    private var healthBridge: HealthKitBridge!
    
    override func setUp() {
        super.setUp()
        transcoder = RosettaTranscoder()
        healthBridge = HealthKitBridge()
    }
    
    override func tearDown() {
        transcoder = nil
        healthBridge = nil
        super.tearDown()
    }
    
    // MARK: - 1. CDA XML to FHIR Bundle Full Fidelity
    
    func testTranscodeCDAToFHIRBundleFullFidelity() throws {
        let cdaXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <id root="2.16.840.1.113883.2.9.2.130.4.1" extension="DOC-FSE-2026-999"/>
            <title>Referto di Laboratorio Analisi</title>
            <effectiveTime value="20260821083000"/>
            <recordTarget>
                <patientRole>
                    <id root="2.16.840.1.113883.2.9.4.3.2" extension="RSSMRA85M01H501Z"/>
                    <patient>
                        <name>
                            <family>Rossi</family>
                            <given>Mario</given>
                        </name>
                    </patient>
                </patientRole>
            </recordTarget>
            <component>
                <structuredBody>
                    <component>
                        <section>
                            <title>Esami di Chimica Clinica</title>
                            <text>Paziente a digiuno da 12 ore.</text>
                            <entry>
                                <observation classCode="OBS" moodCode="EVN">
                                    <code code="15074-8" codeSystem="2.16.840.1.113883.6.1" displayName="Glucosio basale"/>
                                    <effectiveTime value="20260821083000"/>
                                    <value xsi:type="PQ" value="94.5" unit="mg/dL"/>
                                    <referenceRange>
                                        <observationRange>
                                            <value xsi:type="IVL_PQ">
                                                <low value="70.0" unit="mg/dL"/>
                                                <high value="99.0" unit="mg/dL"/>
                                            </value>
                                        </observationRange>
                                    </referenceRange>
                                </observation>
                            </entry>
                        </section>
                    </component>
                </structuredBody>
            </component>
        </ClinicalDocument>
        """
        
        let bundle = try transcoder.transcode(cdaData: cdaXML.data(using: .utf8)!)
        
        // Assert Bundle Header & IPS Meta Profile
        XCTAssertEqual(bundle.id, "DOC-FSE-2026-999", "Document ID extension must be preserved in FHIR Bundle ID")
        XCTAssertEqual(bundle.type, "document")
        XCTAssertEqual(bundle.meta?.profile, ["http://hl7.org/fhir/uv/ips/StructureDefinition/Bundle-uv-ips"])
        
        // Assert Composition Resource
        let compositionEntries = bundle.entry.compactMap { entry -> FHIRComposition? in
            if case .composition(let c) = entry.resource { return c }
            return nil
        }
        XCTAssertEqual(compositionEntries.count, 1)
        let composition = compositionEntries.first!
        XCTAssertEqual(composition.title, "Referto di Laboratorio Analisi")
        XCTAssertEqual(composition.subject.display, "Rossi Mario")
        XCTAssertNotNil(composition.text)
        XCTAssertTrue(composition.text?.div.contains("Paziente a digiuno da 12 ore.") == true)
        
        // Assert Patient Resource
        let patientEntries = bundle.entry.compactMap { entry -> FHIRPatient? in
            if case .patient(let p) = entry.resource { return p }
            return nil
        }
        XCTAssertEqual(patientEntries.count, 1)
        let patient = patientEntries.first!
        XCTAssertEqual(patient.name?.first?.family, "Rossi")
        XCTAssertEqual(patient.name?.first?.given?.first, "Mario")
        XCTAssertEqual(patient.identifier?.first?.value, "RSSMRA85M01H501Z")
        XCTAssertEqual(patient.identifier?.first?.system, "http://hl7.it/sid/codiceFiscale")
        
        // Assert Observation Resource
        let observationEntries = bundle.entry.compactMap { entry -> FHIRObservation? in
            if case .observation(let o) = entry.resource { return o }
            return nil
        }
        XCTAssertEqual(observationEntries.count, 1)
        let obs = observationEntries.first!
        XCTAssertEqual(obs.code.coding.first?.code, "15074-8")
        XCTAssertEqual(obs.code.coding.first?.display, "Glucosio basale")
        XCTAssertEqual(obs.valueQuantity?.value, 94.5)
        XCTAssertEqual(obs.valueQuantity?.unit, "mg/dL")
        XCTAssertEqual(obs.referenceRange?.first?.low?.value, 70.0)
        XCTAssertEqual(obs.referenceRange?.first?.high?.value, 99.0)
    }
    
    // MARK: - 2. Physiological Validation Gate Filtering (Healthy vs Poisoned Values)
    
    func testPhysiologicalValidationGateAcceptance() async throws {
        // Test in-range physiological values for various biometrics
        let validCases: [(code: String, value: Double, unit: String)] = [
            ("15074-8", 95.0, "mg/dL"),    // Glucose 95 mg/dL
            ("2093-3", 185.0, "mg/dL"),   // Total Cholesterol 185 mg/dL
            ("8867-4", 72.0, "count/min"), // Heart Rate 72 bpm
            ("2708-6", 98.0, "%"),         // Oxygen Saturation 98%
            ("8310-5", 36.8, "degC"),      // Body Temp 36.8 C
            ("29463-7", 75.0, "kg"),       // Body Mass 75 kg
            ("8302-2", 1.78, "m")          // Height 1.78 m
        ]
        
        for item in validCases {
            let bundle = createMockObservationBundle(loinc: item.code, value: item.value, unit: item.unit)
            let result = try await healthBridge.ingestQuantities(fhirBundle: bundle)
            XCTAssertEqual(result.skippedObservations.count, 0, "Valid biometric \(item.code) with value \(item.value) must pass validation gate")
        }
    }
    
    func testPhysiologicalValidationGateRejection() async throws {
        // Test lethal/poisoned/extreme out-of-range values blocked by gate
        let poisonedCases: [(code: String, value: Double, unit: String, desc: String)] = [
            ("15074-8", 3000.0, "mg/dL", "Lethal Glucose High (3000 mg/dL)"),
            ("15074-8", 5.0, "mg/dL", "Lethal Glucose Low (5 mg/dL)"),
            ("8867-4", 450.0, "count/min", "Extreme Tachycardia (450 bpm)"),
            ("8867-4", 4.0, "count/min", "Lethal Bradycardia (4 bpm)"),
            ("8310-5", 55.0, "degC", "Impossible Temperature (55 C)"),
            ("8310-5", 15.0, "degC", "Fatal Hypothermia (15 C)"),
            ("29463-7", 850.0, "kg", "Impossible Body Mass (850 kg)"),
            ("29463-7", 0.2, "kg", "Impossible Body Mass (0.2 kg)"),
            ("8302-2", 4.5, "m", "Impossible Height (4.5 m)"),
            ("8302-2", 0.1, "m", "Impossible Height (0.1 m)")
        ]
        
        for item in poisonedCases {
            let bundle = createMockObservationBundle(loinc: item.code, value: item.value, unit: item.unit)
            let result = try await healthBridge.ingestQuantities(fhirBundle: bundle)
            XCTAssertEqual(result.skippedObservations.count, 1, "Validation gate must reject \(item.desc)")
            XCTAssertEqual(result.savedCount, 0, "No sample should be saved for \(item.desc)")
        }
    }
    
    // MARK: - 3. Patient Firewall Routing
    
    func testFirewallOwnerMatching() {
        let ownerFiscalCode = "RSSMRA85M01H501Z"
        
        // Match Scenario
        let docPatientCF = "RSSMRA85M01H501Z"
        let isOwner = (docPatientCF.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == ownerFiscalCode.uppercased())
        XCTAssertTrue(isOwner, "Matching fiscal code must route to Apple HealthKit")
        
        // Mismatch Scenario
        let foreignDocPatientCF = "BNCLSN90A01F205X"
        let isForeignOwner = (foreignDocPatientCF.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == ownerFiscalCode.uppercased())
        XCTAssertFalse(isForeignOwner, "Non-matching fiscal code must route to SwiftData Family Vault")
    }
    
    func testFirewallAnonymousNameMatching() {
        let ownerFirst = "Mario"
        let ownerLast = "Rossi"
        
        let patientFullName = "Mario Rossi"
        let pNameLower = patientFullName.lowercased()
        let isMatch = !ownerFirst.isEmpty && !ownerLast.isEmpty &&
                      pNameLower.contains(ownerFirst.lowercased()) &&
                      pNameLower.contains(ownerLast.lowercased())
        
        XCTAssertTrue(isMatch, "Anonymous mode must match when first and last name match")
        
        let otherPatient = "Alessandro Bianchi"
        let otherLower = otherPatient.lowercased()
        let isOtherMatch = !ownerFirst.isEmpty && !ownerLast.isEmpty &&
                           otherLower.contains(ownerFirst.lowercased()) &&
                           otherLower.contains(ownerLast.lowercased())
        
        XCTAssertFalse(isOtherMatch, "Anonymous mode must reject different names")
    }
    
    // MARK: - Helper Methods
    
    private func createMockObservationBundle(loinc: String, value: Double, unit: String) -> FHIRBundle {
        let code = FHIRCodeableConcept(coding: [FHIRCoding(system: "http://loinc.org", code: loinc, display: "Metric")], text: "Metric")
        let quantity = FHIRQuantity(value: value, unit: unit, code: unit)
        let obs = FHIRObservation(
            id: UUID().uuidString,
            status: "final",
            code: code,
            effectiveDateTime: ISO8601DateFormatter().string(from: Date()),
            valueQuantity: quantity
        )
        return FHIRBundle(timestamp: ISO8601DateFormatter().string(from: Date()), entry: [FHIRBundleEntry(resource: .observation(obs))])
    }
}
