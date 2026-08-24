import XCTest
@testable import RosettaHealthCore

final class RosettaTranscoderTests: XCTestCase {
    
    func testExtractPatientInfo() throws {
        let xmlString = """
        <ClinicalDocument>
            <patientRole>
                <id root="2.16.840.1.113883.2.9.4.3.2" extension="RSSMRA80A01H501U"/>
                <patient>
                    <name>
                        <family>Rossi</family>
                        <given>Mario</given>
                    </name>
                </patient>
            </patientRole>
            <effectiveTime value="20231024143000+0200"/>
        </ClinicalDocument>
        """
        
        let transcoder = RosettaTranscoder()
        let bundle = try transcoder.transcode(cdaData: xmlString.data(using: .utf8)!)
        
        let patientEntries = bundle.entry.compactMap { entry -> FHIRPatient? in
            if case .patient(let p) = entry.resource { return p }
            return nil
        }
        
        XCTAssertEqual(patientEntries.count, 1)
        let patient = patientEntries.first!
        
        XCTAssertEqual(patient.identifier?.first?.value, "RSSMRA80A01H501U")
        XCTAssertEqual(patient.name?.first?.family, "Rossi")
        XCTAssertEqual(patient.name?.first?.given?.first, "Mario")
    }
}