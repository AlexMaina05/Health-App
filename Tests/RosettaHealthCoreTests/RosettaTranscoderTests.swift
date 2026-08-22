import XCTest
@testable import RosettaHealthCore

final class RosettaTranscoderTests: XCTestCase {
    
    // MARK: - Mocks
    
    let validCDAXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
        <id root="2.16.840.1.113883.2.9.2.120.4.4" extension="123456789"/>
        <code code="11502-2" codeSystem="2.16.840.1.113883.6.1" displayName="Referto di Laboratorio"/>
        <effectiveTime value="20231015143000+0200"/>
        <recordTarget>
            <patientRole>
                <id root="2.16.840.1.113883.2.9.4.3.2" extension="RSSMRA80A01H501U"/>
                <patient>
                    <name><given>Mario</given><family>Rossi</family></name>
                </patient>
            </patientRole>
        </recordTarget>
        <component>
            <structuredBody>
                <component>
                    <section>
                        <entry>
                            <observation classCode="OBS" moodCode="EVN">
                                <code code="15074-8" codeSystem="2.16.840.1.113883.6.1" displayName="Glucosio"/>
                                <effectiveTime value="20231015080000+0200"/>
                                <value xsi:type="PQ" value="95.5" unit="mg/dL"/>
                            </observation>
                        </entry>
                        <entry>
                            <observation classCode="OBS" moodCode="EVN">
                                <code code="85354-9" codeSystem="2.16.840.1.113883.6.1" displayName="Pressione Sanguigna"/>
                                <value xsi:type="ST">120/80</value>
                            </observation>
                        </entry>
                    </section>
                </component>
            </structuredBody>
        </component>
    </ClinicalDocument>
    """
    
    let missingPatientCDAXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <component><structuredBody></structuredBody></component>
    </ClinicalDocument>
    """
    
    let malformedCDAXML = "<RandomTag><value>123</value></RandomTag>"

    // MARK: - Tests

    func testTranscodeValidCDA_ExtractsQuantitativeAndStringObservations() throws {
        let transcoder = RosettaTranscoder()
        let bundle = try transcoder.transcode(cdaData: validCDAXML.data(using: .utf8)!)
        
        // Verifica IPS Profile
        XCTAssertEqual(bundle.resourceType, "Bundle")
        XCTAssertTrue(bundle.meta?.profile.contains("http://hl7.org/fhir/uv/ips/StructureDefinition/Bundle-uv-ips") == true)
        
        // Deve esserci: Patient, Composition, e 2 Observations
        XCTAssertEqual(bundle.entry.count, 4)
        
        // Verifica Paziente
        let patient = bundle.entry.compactMap { if case .patient(let p) = $0.resource { return p } else { return nil } }.first
        XCTAssertEqual(patient?.identifier?.first?.value, "RSSMRA80A01H501U")
        
        // Verifica Osservazione Quantitativa (PQ)
        let obsPQ = bundle.entry.compactMap { if case .observation(let o) = $0.resource, o.valueQuantity != nil { return o } else { return nil } }.first
        XCTAssertEqual(obsPQ?.valueQuantity?.value, 95.5)
        XCTAssertEqual(obsPQ?.valueQuantity?.unit, "mg/dL")
        XCTAssertEqual(obsPQ?.code.coding.first?.code, "15074-8")
        
        // Verifica Osservazione Testuale (ST - Pressione Sanguigna composta)
        let obsST = bundle.entry.compactMap { if case .observation(let o) = $0.resource, o.valueString != nil { return o } else { return nil } }.first
        XCTAssertEqual(obsST?.valueString, "120/80")
        XCTAssertEqual(obsST?.code.coding.first?.code, "85354-9")
    }
    
    func testTranscodeMissingPatient_HandlesGracefully() throws {
        let transcoder = RosettaTranscoder()
        let bundle = try transcoder.transcode(cdaData: missingPatientCDAXML.data(using: .utf8)!)
        
        let patient = bundle.entry.compactMap { if case .patient(let p) = $0.resource { return p } else { return nil } }.first
        
        // Se non c'è paziente, l'app genera un "Sconosciuto" anonimo per fallback
        XCTAssertEqual(patient?.name?.first?.family, "Sconosciuto")
        XCTAssertNil(patient?.identifier?.first?.value)
        XCTAssertEqual(bundle.entry.count, 2) // Solo Patient fallback e Composition vuota
    }
    
    func testTranscodeMalformedCDAThrowsError() {
        let transcoder = RosettaTranscoder()
        XCTAssertThrowsError(try transcoder.transcode(cdaData: malformedCDAXML.data(using: .utf8)!)) { error in
            XCTAssertTrue(error is RosettaError)
            if let rosettaError = error as? RosettaError, case .missingClinicalDocumentHeader = rosettaError {
                // Successo
            } else {
                XCTFail("Atteso .missingClinicalDocumentHeader")
            }
        }
    }
}
