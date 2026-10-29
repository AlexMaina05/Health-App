import XCTest
@testable import RosettaEdgeCore

final class RosettaTranscoderTests2: XCTestCase {
    
    func testDirtyXMLValuesFallback() throws {
        // XML con valore < 0.05 che fallirebbe il parse Double nativo
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument>
            <component><structuredBody><component><section>
                <entry>
                    <observation classCode="OBS" moodCode="EVN">
                        <code><originalText>Proteina C Reattiva</originalText></code>
                        <value xsi:type="PQ" value="&lt; 0.05" unit="mg/dL"/>
                    </observation>
                </entry>
            </section></component></structuredBody></component>
        </ClinicalDocument>
        """
        
        let transcoder = RosettaTranscoder()
        let bundle = try transcoder.transcode(cdaData: xmlString.data(using: .utf8)!)
        
        let obsEntries = bundle.entry.compactMap { entry -> FHIRObservation? in
            if case .observation(let obs) = entry.resource { return obs }
            return nil
        }
        
        guard let obs = obsEntries.first else {
            XCTFail("Nessuna osservazione trovata")
            return
        }
        
        XCTAssertNil(obs.valueQuantity, "Il valore non dovrebbe essere un quantity valido")
        XCTAssertEqual(obs.valueString, "< 0.05 mg/dL", "Il fallback testuale ha fallito")
    }
    
    func testDocumentIDExtraction() throws {
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument>
            <id extension="SOLE_DOC_12345" root="1.2.3.4"/>
            <patientRole>
                <id extension="CF123" root="2.16.840.1.113883.2.9.4.3.2"/>
            </patientRole>
        </ClinicalDocument>
        """
        
        let transcoder = RosettaTranscoder()
        let bundle = try transcoder.transcode(cdaData: xmlString.data(using: .utf8)!)
        
        XCTAssertEqual(bundle.id, "SOLE_DOC_12345", "Estrazione attributo ID FSE fallita")
    }
}
