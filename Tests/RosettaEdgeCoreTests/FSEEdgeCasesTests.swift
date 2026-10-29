import XCTest
@testable import RosettaEdgeCore

final class FSEEdgeCasesTests: XCTestCase {
    
    func testMissingClinicalDocumentHeader() {
        let xmlString = "<RandomXML></RandomXML>"
        let transcoder = RosettaTranscoder()
        XCTAssertThrowsError(try transcoder.transcode(cdaData: xmlString.data(using: .utf8)!)) { error in
            guard let rosettaError = error as? RosettaError else {
                XCTFail("Wrong error type")
                return
            }
            if case .missingClinicalDocumentHeader = rosettaError {
                // Success
            } else {
                XCTFail("Expected missingClinicalDocumentHeader")
            }
        }
    }
    
    func testNarrativeTextExtraction() throws {
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument>
            <component><structuredBody><component><section>
                <text>Il paziente presenta un quadro clinico stabile.</text>
            </section></component></structuredBody></component>
        </ClinicalDocument>
        """
        let transcoder = RosettaTranscoder()
        let bundle = try transcoder.transcode(cdaData: xmlString.data(using: .utf8)!)
        
        let compositionEntries = bundle.entry.compactMap { entry -> FHIRComposition? in
            if case .composition(let c) = entry.resource { return c }
            return nil
        }
        
        XCTAssertFalse(compositionEntries.isEmpty, "Composition resource should be present")
        let composition = compositionEntries.first
        XCTAssertNotNil(composition?.text, "Narrative text should be populated in composition")
        XCTAssertTrue(composition?.text?.div.contains("Il paziente presenta un quadro clinico stabile.") == true, "Narrative text div content mismatch")
        
        let observationEntries = bundle.entry.compactMap { entry -> FHIRObservation? in
            if case .observation(let o) = entry.resource { return o }
            return nil
        }
        XCTAssertEqual(observationEntries.count, 0, "No observations should be generated from narrative only XML")
    }
    
    func testBillionLaughsXXEMitigation() {
        // XMLParser resolves internally, but since we disabled it, this shouldn't crash or hang
        let xmlString = """
        <?xml version="1.0"?>
        <!DOCTYPE lolz [
         <!ENTITY lol "lol">
         <!ELEMENT lolz (#PCDATA)>
         <!ENTITY lol1 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;">
         <!ENTITY lol2 "&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;">
        ]>
        <ClinicalDocument>&lol2;</ClinicalDocument>
        """
        let transcoder = RosettaTranscoder()
        XCTAssertNoThrow(try transcoder.transcode(cdaData: xmlString.data(using: .utf8)!))
    }
}
