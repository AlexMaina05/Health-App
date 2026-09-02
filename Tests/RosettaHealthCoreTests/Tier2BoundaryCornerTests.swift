import XCTest
import HealthKit
@testable import RosettaHealthCore

/// Tier 2: Boundary & Corner Cases Integration Tests
/// Verifies resilience under malformed input, XML security boundaries,
/// exact physiological threshold boundaries, comma-decimal formatting,
/// inequality string fallbacks, and composite metric parsing.
final class Tier2BoundaryCornerTests: XCTestCase {
    
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
    
    // MARK: - 1. Malformed XML & Security Handling
    
    func testMalformedXMLSyntaxThrowsError() {
        let badXML = "<ClinicalDocument><brokenTag></ClinicalDocument>"
        XCTAssertThrowsError(try transcoder.transcode(cdaData: badXML.data(using: .utf8)!)) { error in
            guard let rosettaError = error as? RosettaError else {
                XCTFail("Expected RosettaError, got \(error)")
                return
            }
            if case .malformedXML = rosettaError {
                // Success
            } else {
                XCTFail("Expected RosettaError.malformedXML, got \(rosettaError)")
            }
        }
    }
    
    func testMissingClinicalDocumentHeaderThrowsError() {
        let nonCDAXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <GenericMedicalRecord>
            <patient>John Doe</patient>
        </GenericMedicalRecord>
        """
        XCTAssertThrowsError(try transcoder.transcode(cdaData: nonCDAXML.data(using: .utf8)!)) { error in
            guard let rosettaError = error as? RosettaError else {
                XCTFail("Expected RosettaError, got \(error)")
                return
            }
            if case .missingClinicalDocumentHeader = rosettaError {
                // Success
            } else {
                XCTFail("Expected RosettaError.missingClinicalDocumentHeader, got \(rosettaError)")
            }
        }
    }
    
    func testEmptyDataThrowsError() {
        let emptyData = Data()
        XCTAssertThrowsError(try transcoder.transcode(cdaData: emptyData)) { error in
            guard let rosettaError = error as? RosettaError else {
                XCTFail("Expected RosettaError, got \(error)")
                return
            }
            if case .malformedXML = rosettaError {
                // Success
            } else {
                XCTFail("Expected RosettaError.malformedXML, got \(rosettaError)")
            }
        }
    }
    
    func testBillionLaughsXXEMitigationSafe() {
        let xxeAttackXML = """
        <?xml version="1.0"?>
        <!DOCTYPE lolz [
         <!ENTITY lol "lol">
         <!ELEMENT lolz (#PCDATA)>
         <!ENTITY lol1 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;">
         <!ENTITY lol2 "&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;">
         <!ENTITY lol3 "&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;">
        ]>
        <ClinicalDocument>&lol3;</ClinicalDocument>
        """
        // shouldResolveExternalEntities = false prevents denial of service / memory explosion by throwing an error
        XCTAssertThrowsError(try transcoder.transcode(cdaData: xxeAttackXML.data(using: .utf8)!)) { error in
            XCTAssertTrue(error is RosettaError)
        }
    }
    
    // MARK: - 2. Exact Physiological Threshold Boundaries (Min/Max & Off-by-One)
    
    func testExactPhysiologicalBoundariesGlucose() async throws {
        let loinc = "15074-8" // Glucose (Limits: 10 - 1500 mg/dL)
        
        // Exact Min Threshold (10.0 mg/dL) -> Must Pass
        let minBundle = createMockBundle(loinc: loinc, value: 10.0, unit: "mg/dL")
        let minRes = try await healthBridge.ingestQuantities(fhirBundle: minBundle)
        XCTAssertEqual(minRes.skippedObservations.count, 0, "Glucose 10.0 mg/dL (exact min) must pass")
        
        // Exact Max Threshold (1500.0 mg/dL) -> Must Pass
        let maxBundle = createMockBundle(loinc: loinc, value: 1500.0, unit: "mg/dL")
        let maxRes = try await healthBridge.ingestQuantities(fhirBundle: maxBundle)
        XCTAssertEqual(maxRes.skippedObservations.count, 0, "Glucose 1500.0 mg/dL (exact max) must pass")
        
        // Off-by-one Below Min (9.9 mg/dL) -> Must Reject
        let belowMinBundle = createMockBundle(loinc: loinc, value: 9.9, unit: "mg/dL")
        let belowRes = try await healthBridge.ingestQuantities(fhirBundle: belowMinBundle)
        XCTAssertEqual(belowRes.skippedObservations.count, 1, "Glucose 9.9 mg/dL (below min) must be rejected")
        
        // Off-by-one Above Max (1500.1 mg/dL) -> Must Reject
        let aboveMaxBundle = createMockBundle(loinc: loinc, value: 1500.1, unit: "mg/dL")
        let aboveRes = try await healthBridge.ingestQuantities(fhirBundle: aboveMaxBundle)
        XCTAssertEqual(aboveRes.skippedObservations.count, 1, "Glucose 1500.1 mg/dL (above max) must be rejected")
    }
    
    func testExactPhysiologicalBoundariesBloodPressure() async throws {
        // Systolic LOINC 8480-6 (Limits: 40 - 350 mmHg)
        let sysMinBundle = createMockBundle(loinc: "8480-6", value: 40.0, unit: "mm[Hg]")
        let sysMinRes = try await healthBridge.ingestQuantities(fhirBundle: sysMinBundle)
        XCTAssertEqual(sysMinRes.skippedObservations.count, 0, "Systolic 40.0 mmHg (exact min) must pass")
        
        let sysMaxBundle = createMockBundle(loinc: "8480-6", value: 350.0, unit: "mm[Hg]")
        let sysMaxRes = try await healthBridge.ingestQuantities(fhirBundle: sysMaxBundle)
        XCTAssertEqual(sysMaxRes.skippedObservations.count, 0, "Systolic 350.0 mmHg (exact max) must pass")
        
        let sysBelowBundle = createMockBundle(loinc: "8480-6", value: 39.9, unit: "mm[Hg]")
        let sysBelowRes = try await healthBridge.ingestQuantities(fhirBundle: sysBelowBundle)
        XCTAssertEqual(sysBelowRes.skippedObservations.count, 1, "Systolic 39.9 mmHg must be rejected")
        
        let sysAboveBundle = createMockBundle(loinc: "8480-6", value: 350.1, unit: "mm[Hg]")
        let sysAboveRes = try await healthBridge.ingestQuantities(fhirBundle: sysAboveBundle)
        XCTAssertEqual(sysAboveRes.skippedObservations.count, 1, "Systolic 350.1 mmHg must be rejected")
        
        // Diastolic LOINC 8462-4 (Limits: 20 - 200 mmHg)
        let diaMinBundle = createMockBundle(loinc: "8462-4", value: 20.0, unit: "mm[Hg]")
        let diaMinRes = try await healthBridge.ingestQuantities(fhirBundle: diaMinBundle)
        XCTAssertEqual(diaMinRes.skippedObservations.count, 0, "Diastolic 20.0 mmHg (exact min) must pass")
        
        let diaMaxBundle = createMockBundle(loinc: "8462-4", value: 200.0, unit: "mm[Hg]")
        let diaMaxRes = try await healthBridge.ingestQuantities(fhirBundle: diaMaxBundle)
        XCTAssertEqual(diaMaxRes.skippedObservations.count, 0, "Diastolic 200.0 mmHg (exact max) must pass")
        
        let diaBelowBundle = createMockBundle(loinc: "8462-4", value: 19.9, unit: "mm[Hg]")
        let diaBelowRes = try await healthBridge.ingestQuantities(fhirBundle: diaBelowBundle)
        XCTAssertEqual(diaBelowRes.skippedObservations.count, 1, "Diastolic 19.9 mmHg must be rejected")
        
        let diaAboveBundle = createMockBundle(loinc: "8462-4", value: 200.1, unit: "mm[Hg]")
        let diaAboveRes = try await healthBridge.ingestQuantities(fhirBundle: diaAboveBundle)
        XCTAssertEqual(diaAboveRes.skippedObservations.count, 1, "Diastolic 200.1 mmHg must be rejected")
    }
    
    func testExactPhysiologicalBoundariesHeartRateAndTemp() async throws {
        // Heart Rate LOINC 8867-4 (Limits: 10 - 300 bpm)
        let hrMinBundle = createMockBundle(loinc: "8867-4", value: 10.0, unit: "count/min")
        let hrMinRes = try await healthBridge.ingestQuantities(fhirBundle: hrMinBundle)
        XCTAssertEqual(hrMinRes.skippedObservations.count, 0, "HR 10 bpm (exact min) must pass")
        
        let hrMaxBundle = createMockBundle(loinc: "8867-4", value: 300.0, unit: "count/min")
        let hrMaxRes = try await healthBridge.ingestQuantities(fhirBundle: hrMaxBundle)
        XCTAssertEqual(hrMaxRes.skippedObservations.count, 0, "HR 300 bpm (exact max) must pass")
        
        let hrBelowBundle = createMockBundle(loinc: "8867-4", value: 9.9, unit: "count/min")
        let hrBelowRes = try await healthBridge.ingestQuantities(fhirBundle: hrBelowBundle)
        XCTAssertEqual(hrBelowRes.skippedObservations.count, 1, "HR 9.9 bpm must be rejected")
        
        let hrAboveBundle = createMockBundle(loinc: "8867-4", value: 300.1, unit: "count/min")
        let hrAboveRes = try await healthBridge.ingestQuantities(fhirBundle: hrAboveBundle)
        XCTAssertEqual(hrAboveRes.skippedObservations.count, 1, "HR 300.1 bpm must be rejected")
        
        // Temperature LOINC 8310-5 (Limits: 20 - 45 C)
        let tempMinBundle = createMockBundle(loinc: "8310-5", value: 20.0, unit: "Cel")
        let tempMinRes = try await healthBridge.ingestQuantities(fhirBundle: tempMinBundle)
        XCTAssertEqual(tempMinRes.skippedObservations.count, 0, "Temp 20.0 C (exact min) must pass")
        
        let tempMaxBundle = createMockBundle(loinc: "8310-5", value: 45.0, unit: "Cel")
        let tempMaxRes = try await healthBridge.ingestQuantities(fhirBundle: tempMaxBundle)
        XCTAssertEqual(tempMaxRes.skippedObservations.count, 0, "Temp 45.0 C (exact max) must pass")
        
        let tempBelowBundle = createMockBundle(loinc: "8310-5", value: 19.9, unit: "Cel")
        let tempBelowRes = try await healthBridge.ingestQuantities(fhirBundle: tempBelowBundle)
        XCTAssertEqual(tempBelowRes.skippedObservations.count, 1, "Temp 19.9 C must be rejected")
        
        let tempAboveBundle = createMockBundle(loinc: "8310-5", value: 45.1, unit: "Cel")
        let tempAboveRes = try await healthBridge.ingestQuantities(fhirBundle: tempAboveBundle)
        XCTAssertEqual(tempAboveRes.skippedObservations.count, 1, "Temp 45.1 C must be rejected")
    }
    
    // MARK: - 3. Comma-Separated Decimal Parsing & Numerical Normalization
    
    func testCommaSeparatedDecimalParsing() throws {
        let xmlWithCommas = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument>
            <component><structuredBody><component><section>
                <entry>
                    <observation classCode="OBS" moodCode="EVN">
                        <code code="15074-8" codeSystem="2.16.840.1.113883.6.1" displayName="Glucosio"/>
                        <value xsi:type="PQ" value="94,5" unit="mg/dL"/>
                    </observation>
                </entry>
                <entry>
                    <observation classCode="OBS" moodCode="EVN">
                        <code code="2093-3" codeSystem="2.16.840.1.113883.6.1" displayName="Colesterolo"/>
                        <value xsi:type="PQ" value="215,8" unit="mg/dL"/>
                    </observation>
                </entry>
            </section></component></structuredBody></component>
        </ClinicalDocument>
        """
        
        let bundle = try transcoder.transcode(cdaData: xmlWithCommas.data(using: .utf8)!)
        let obs = bundle.entry.compactMap { entry -> FHIRObservation? in
            if case .observation(let o) = entry.resource { return o }
            return nil
        }
        
        XCTAssertEqual(obs.count, 2)
        XCTAssertEqual(obs[0].valueQuantity?.value, 94.5, "Comma decimal '94,5' must parse to 94.5 Double")
        XCTAssertEqual(obs[1].valueQuantity?.value, 215.8, "Comma decimal '215,8' must parse to 215.8 Double")
    }
    
    // MARK: - 4. Inequality String Fallbacks & Composite Blood Pressure
    
    func testInequalityStringFallbackPreservation() throws {
        let xmlWithInequalities = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument>
            <component><structuredBody><component><section>
                <entry>
                    <observation classCode="OBS" moodCode="EVN">
                        <code code="1988-5" codeSystem="2.16.840.1.113883.6.1" displayName="Proteina C Reattiva"/>
                        <value xsi:type="PQ" value="&lt; 0.05" unit="mg/dL"/>
                    </observation>
                </entry>
                <entry>
                    <observation classCode="OBS" moodCode="EVN">
                        <code code="48642-3" codeSystem="2.16.840.1.113883.6.1" displayName="Ferritina"/>
                        <value xsi:type="PQ" value="&gt; 1000" unit="ng/mL"/>
                    </observation>
                </entry>
            </section></component></structuredBody></component>
        </ClinicalDocument>
        """
        
        let bundle = try transcoder.transcode(cdaData: xmlWithInequalities.data(using: .utf8)!)
        let obs = bundle.entry.compactMap { entry -> FHIRObservation? in
            if case .observation(let o) = entry.resource { return o }
            return nil
        }
        
        XCTAssertEqual(obs.count, 2)
        XCTAssertNil(obs[0].valueQuantity)
        XCTAssertEqual(obs[0].valueString, "< 0.05 mg/dL")
        XCTAssertNil(obs[1].valueQuantity)
        XCTAssertEqual(obs[1].valueString, "> 1000 ng/mL")
    }
    
    func testCompositeBloodPressureParsing() async throws {
        let mockBundle = createMockBundle(loinc: "8480-6", valueString: "125/82")
        let result = try await healthBridge.ingestQuantities(fhirBundle: mockBundle)
        
        // 125/82 systolic parsing must succeed
        XCTAssertEqual(result.skippedObservations.count, 0, "Composite blood pressure '125/82' must be split and parsed successfully")
    }
    
    // MARK: - 5. Multi-Section Narrative Text Extraction
    
    func testNarrativeTextMultiSectionExtraction() throws {
        let narrativeXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument>
            <component><structuredBody>
                <component>
                    <section>
                        <title>Anamnesi</title>
                        <text>Paziente con ipertensione nota in terapia medica.</text>
                    </section>
                </component>
                <component>
                    <section>
                        <title>Esame Fisico</title>
                        <text>Toni cardiaci validi ritmici, pause libere.</text>
                    </section>
                </component>
            </structuredBody></component>
        </ClinicalDocument>
        """
        
        let bundle = try transcoder.transcode(cdaData: narrativeXML.data(using: .utf8)!)
        let compositionEntries = bundle.entry.compactMap { entry -> FHIRComposition? in
            if case .composition(let c) = entry.resource { return c }
            return nil
        }
        
        XCTAssertEqual(compositionEntries.count, 1)
        let composition = compositionEntries.first!
        let fullText = composition.text?.div ?? ""
        XCTAssertTrue(fullText.contains("Paziente con ipertensione nota in terapia medica."))
        XCTAssertTrue(fullText.contains("Toni cardiaci validi ritmici, pause libere."))
    }
    
    // MARK: - Helper Methods
    
    private func createMockBundle(loinc: String, value: Double? = nil, valueString: String? = nil, unit: String = "") -> FHIRBundle {
        let code = FHIRCodeableConcept(coding: [FHIRCoding(system: "http://loinc.org", code: loinc, display: "Metric")], text: "Metric")
        var qty: FHIRQuantity? = nil
        if let v = value {
            qty = FHIRQuantity(value: v, unit: unit, code: unit)
        }
        let obs = FHIRObservation(
            id: UUID().uuidString,
            status: "final",
            code: code,
            effectiveDateTime: ISO8601DateFormatter().string(from: Date()),
            valueQuantity: qty,
            valueString: valueString
        )
        return FHIRBundle(timestamp: ISO8601DateFormatter().string(from: Date()), entry: [FHIRBundleEntry(resource: .observation(obs))])
    }
}
