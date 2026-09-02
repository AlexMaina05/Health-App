import XCTest
import HealthKit
import SwiftData
@testable import RosettaHealthCore

/// Tier 4: Real-World Workloads Integration Tests
/// Verifies end-to-end processing of real-world Italian FSE HL7 CDA clinical documents:
/// 1. `MockData/Mock_Laboratorio.xml` (Full multi-parameter laboratory chemistry panel)
/// 2. `MockData/Mock_Specialistica.xml` (Cardiology specialist consultation with multi-section clinical narrative)
/// 3. Concurrent batch document processing across multiple patient records.
final class Tier4RealWorldWorkloadTests: XCTestCase {
    
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
    
    // MARK: - 1. Real-World Laboratory Panel Pipeline (Mock_Laboratorio.xml)
    
    func testMockLaboratorioFullPipeline() async throws {
        let xmlData = loadLaboratorioXMLData()
        
        // 1. Transcode CDA to FHIR Bundle
        let bundle = try transcoder.transcode(cdaData: xmlData)
        
        // 2. Validate Bundle Metadata
        XCTAssertEqual(bundle.id, "LAB-MOCK-2026-001", "Extracted Bundle ID must match CDA Document ID extension")
        XCTAssertEqual(bundle.type, "document")
        XCTAssertEqual(bundle.meta?.profile, ["http://hl7.org/fhir/uv/ips/StructureDefinition/Bundle-uv-ips"])
        
        // 3. Validate Patient Information
        let patients = bundle.entry.compactMap { entry -> FHIRPatient? in
            if case .patient(let p) = entry.resource { return p }
            return nil
        }
        XCTAssertEqual(patients.count, 1)
        let patient = patients.first!
        XCTAssertEqual(patient.name?.first?.family, "Rossi")
        XCTAssertEqual(patient.name?.first?.given?.first, "Mario")
        XCTAssertEqual(patient.identifier?.first?.value, "RSSMRA85M01H501Z")
        XCTAssertEqual(patient.identifier?.first?.system, "http://hl7.it/sid/codiceFiscale")
        
        // 4. Validate Composition Header
        let compositions = bundle.entry.compactMap { entry -> FHIRComposition? in
            if case .composition(let c) = entry.resource { return c }
            return nil
        }
        XCTAssertEqual(compositions.count, 1)
        let composition = compositions.first!
        XCTAssertEqual(composition.title, "Esami Ematochimici di Routine")
        XCTAssertEqual(composition.subject.display, "Rossi Mario")
        
        // 5. Validate Quantitative & String Observations (4 total)
        let observations = bundle.entry.compactMap { entry -> FHIRObservation? in
            if case .observation(let o) = entry.resource { return o }
            return nil
        }
        XCTAssertEqual(observations.count, 4, "Must parse all 4 observations from laboratory panel")
        
        // Obs 1: Glucosio basale (LOINC 15074-8)
        guard let glucoseObs = observations.first(where: { $0.code.coding.first?.code == "15074-8" }) else {
            XCTFail("Missing Glucose observation (LOINC 15074-8)")
            return
        }
        XCTAssertEqual(glucoseObs.valueQuantity?.value, 94.5)
        XCTAssertEqual(glucoseObs.valueQuantity?.unit, "mg/dL")
        XCTAssertEqual(glucoseObs.referenceRange?.first?.low?.value, 70.0)
        XCTAssertEqual(glucoseObs.referenceRange?.first?.high?.value, 99.0)
        
        // Obs 2: Colesterolo Totale (LOINC 2093-3)
        guard let cholObs = observations.first(where: { $0.code.coding.first?.code == "2093-3" }) else {
            XCTFail("Missing Cholesterol observation (LOINC 2093-3)")
            return
        }
        XCTAssertEqual(cholObs.valueQuantity?.value, 215.0)
        XCTAssertEqual(cholObs.valueQuantity?.unit, "mg/dL")
        XCTAssertEqual(cholObs.referenceRange?.first?.low?.value, 120.0)
        XCTAssertEqual(cholObs.referenceRange?.first?.high?.value, 200.0)
        
        // Obs 3: Pressione Arteriosa (LOINC 8480-6)
        guard let bpObs = observations.first(where: { $0.code.coding.first?.code == "8480-6" }) else {
            XCTFail("Missing Blood Pressure observation (LOINC 8480-6)")
            return
        }
        XCTAssertNil(bpObs.valueQuantity)
        XCTAssertEqual(bpObs.valueString, "125/80")
        
        // Obs 4: Piastrine (LOINC 777-3)
        guard let pltObs = observations.first(where: { $0.code.coding.first?.code == "777-3" }) else {
            XCTFail("Missing Platelets observation (LOINC 777-3)")
            return
        }
        XCTAssertEqual(pltObs.valueQuantity?.value, 240.0)
        XCTAssertEqual(pltObs.referenceRange?.first?.low?.value, 150.0)
        XCTAssertEqual(pltObs.referenceRange?.first?.high?.value, 400.0)
        
        // 6. Run HealthKit Bridge Ingestion
        let ingestionResult = try await healthBridge.ingestQuantities(fhirBundle: bundle)
        
        // Glucose (15074-8), Cholesterol (2093-3), BP Systolic (8480-6) pass validation
        // Platelets (777-3) is not in HealthKit quantity target map -> skipped gracefully
        XCTAssertEqual(ingestionResult.skippedObservations.count, 1, "Platelets (777-3) should be skipped")
        XCTAssertEqual(ingestionResult.skippedObservations.first?.code.coding.first?.code, "777-3")
        
        // 7. Test Patient Firewall Routing
        let ownerCF = "RSSMRA85M01H501Z"
        let patientCF = patient.identifier?.first?.value ?? ""
        let isOwner = (patientCF == ownerCF)
        XCTAssertTrue(isOwner, "Document owner matching must succeed for Mario Rossi")
    }
    
    // MARK: - 2. Real-World Specialist Cardiology Report Pipeline (Mock_Specialistica.xml)
    
    func testMockSpecialisticaFullPipeline() async throws {
        let xmlData = loadSpecialisticaXMLData()
        
        // 1. Transcode Specialist CDA
        let bundle = try transcoder.transcode(cdaData: xmlData)
        
        // 2. Validate Metadata & Patient
        XCTAssertEqual(bundle.id, "VIS-SPEC-2026-889")
        XCTAssertEqual(bundle.type, "document")
        
        let patients = bundle.entry.compactMap { entry -> FHIRPatient? in
            if case .patient(let p) = entry.resource { return p }
            return nil
        }
        XCTAssertEqual(patients.count, 1)
        let patient = patients.first!
        XCTAssertEqual(patient.name?.first?.family, "Bianchi")
        XCTAssertEqual(patient.name?.first?.given?.first, "Alessandro")
        XCTAssertEqual(patient.identifier?.first?.value, "BNCLSN90A01F205X")
        
        // 3. Validate Composition Multi-Section Narrative
        let compositions = bundle.entry.compactMap { entry -> FHIRComposition? in
            if case .composition(let c) = entry.resource { return c }
            return nil
        }
        XCTAssertEqual(compositions.count, 1)
        let composition = compositions.first!
        XCTAssertEqual(composition.title, "Visita Specialistica Cardiologica con ECG")
        
        guard let narrativeDiv = composition.text?.div else {
            XCTFail("Composition narrative text must not be nil")
            return
        }
        
        // Verify text from all 3 sections was accumulated
        XCTAssertTrue(narrativeDiv.contains("Paziente di 36 anni, asintomatico per angor o dispnea da sforzo."))
        XCTAssertTrue(narrativeDiv.contains("Toni cardiaci netti, pause libere."))
        XCTAssertTrue(narrativeDiv.contains("Ritmo sinusale a frequenza cardiaca media di 68 bpm."))
        XCTAssertTrue(narrativeDiv.contains("Quadro clinico-strumentale di normalità cardiologica."))
        
        // 4. Verify Quantitative Observations are 0 (Pure narrative document)
        let observations = bundle.entry.compactMap { entry -> FHIRObservation? in
            if case .observation(let o) = entry.resource { return o }
            return nil
        }
        XCTAssertEqual(observations.count, 0, "Cardiology report without structured entries has 0 observations")
        
        // 5. Ingestion in HealthKit Bridge produces 0 saved and 0 skipped
        let ingestionResult = try await healthBridge.ingestQuantities(fhirBundle: bundle)
        XCTAssertEqual(ingestionResult.savedCount, 0)
        XCTAssertEqual(ingestionResult.skippedObservations.count, 0)
    }
    
    // MARK: - 3. Concurrent Real-World Document Ingestion
    
    func testConcurrentRealWorldDocumentBatchProcessing() async throws {
        let labData = loadLaboratorioXMLData()
        let specData = loadSpecialisticaXMLData()
        
        // Process both documents in parallel tasks
        async let labTask = Task { () -> FHIRBundle in
            let localTranscoder = RosettaTranscoder()
            return try localTranscoder.transcode(cdaData: labData)
        }.value
        
        async let specTask = Task { () -> FHIRBundle in
            let localTranscoder = RosettaTranscoder()
            return try localTranscoder.transcode(cdaData: specData)
        }.value
        
        let (labBundle, specBundle) = try await (labTask, specTask)
        
        XCTAssertEqual(labBundle.id, "LAB-MOCK-2026-001")
        XCTAssertEqual(specBundle.id, "VIS-SPEC-2026-889")
        
        let labObsCount = labBundle.entry.compactMap { if case .observation(let o) = $0.resource { return o } else { return nil } }.count
        let specObsCount = specBundle.entry.compactMap { if case .observation(let o) = $0.resource { return o } else { return nil } }.count
        
        XCTAssertEqual(labObsCount, 4)
        XCTAssertEqual(specObsCount, 0)
    }
    
    // MARK: - Fixture Loaders
    
    private func loadLaboratorioXMLData() -> Data {
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" classCode="DOCCLIN" moodCode="EVN">
            <realmCode code="IT"/>
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="2.16.840.1.113883.2.9.2.130.4.1" extension="LAB-MOCK-2026-001"/>
            <code code="11502-2" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="Referto di Laboratorio"/>
            <title>Esami Ematochimici di Routine</title>
            <effectiveTime value="20260821083000"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="it-IT"/>

            <recordTarget>
                <patientRole>
                    <id root="2.16.840.1.113883.2.9.4.3.2" extension="RSSMRA85M01H501Z"/>
                    <patient>
                        <name>
                            <family>Rossi</family>
                            <given>Mario</given>
                        </name>
                        <administrativeGenderCode code="M" codeSystem="2.16.840.1.113883.5.1"/>
                        <birthTime value="19850801"/>
                    </patient>
                </patientRole>
            </recordTarget>

            <component>
                <structuredBody>
                    <component>
                        <section>
                            <code code="18719-5" codeSystem="2.16.840.1.113883.6.1" displayName="Chimica Clinica"/>
                            <title>Esami di Laboratorio</title>
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
                            <entry>
                                <observation classCode="OBS" moodCode="EVN">
                                    <code code="2093-3" codeSystem="2.16.840.1.113883.6.1" displayName="Colesterolo Totale"/>
                                    <effectiveTime value="20260821083000"/>
                                    <value xsi:type="PQ" value="215.0" unit="mg/dL"/>
                                    <referenceRange>
                                        <observationRange>
                                            <value xsi:type="IVL_PQ">
                                                <low value="120.0" unit="mg/dL"/>
                                                <high value="200.0" unit="mg/dL"/>
                                            </value>
                                        </observationRange>
                                    </referenceRange>
                                </observation>
                            </entry>
                            <entry>
                                <observation classCode="OBS" moodCode="EVN">
                                    <code code="8480-6" codeSystem="2.16.840.1.113883.6.1" displayName="Pressione Arteriosa"/>
                                    <effectiveTime value="20260821083000"/>
                                    <value xsi:type="ST" value="125/80"/>
                                </observation>
                            </entry>
                            <entry>
                                <observation classCode="OBS" moodCode="EVN">
                                    <code code="777-3" codeSystem="2.16.840.1.113883.6.1" displayName="Piastrine"/>
                                    <effectiveTime value="20260821083000"/>
                                    <value xsi:type="PQ" value="240" unit="10*3/uL"/>
                                    <referenceRange>
                                        <observationRange>
                                            <value xsi:type="IVL_PQ">
                                                <low value="150" unit="10*3/uL"/>
                                                <high value="400" unit="10*3/uL"/>
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
        return xmlString.data(using: .utf8)!
    }
    
    private func loadSpecialisticaXMLData() -> Data {
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" classCode="DOCCLIN" moodCode="EVN">
            <realmCode code="IT"/>
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="2.16.840.1.113883.2.9.2.130.4.1" extension="VIS-SPEC-2026-889"/>
            <code code="11488-4" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="Relazione di Visita Specialistica"/>
            <title>Visita Specialistica Cardiologica con ECG</title>
            <effectiveTime value="20260821101500"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="it-IT"/>

            <recordTarget>
                <patientRole>
                    <id root="2.16.840.1.113883.2.9.4.3.2" extension="BNCLSN90A01F205X"/>
                    <patient>
                        <name>
                            <family>Bianchi</family>
                            <given>Alessandro</given>
                        </name>
                        <administrativeGenderCode code="M" codeSystem="2.16.840.1.113883.5.1"/>
                        <birthTime value="19900101"/>
                    </patient>
                </patientRole>
            </recordTarget>

            <author>
                <time value="20260821101500"/>
                <assignedAuthor>
                    <id root="2.16.840.1.113883.2.9.4.3.2" extension="DOCVRD70C15H501K"/>
                    <assignedPerson>
                        <name>
                            <family>Verdi</family>
                            <given>Dott. Roberto</given>
                        </name>
                    </assignedPerson>
                </assignedAuthor>
            </author>

            <component>
                <structuredBody>
                    <component>
                        <section>
                            <code code="11329-0" codeSystem="2.16.840.1.113883.6.1" displayName="Anamnesi e Motivo della Visita"/>
                            <title>Anamnesi e Valutazione Clinica</title>
                            <text>
                                Paziente di 36 anni, asintomatico per angor o dispnea da sforzo.
                                Riferisce sporadiche palpitazioni a riposo correlate a periodi di stress lavorativo.
                                Non familiarità per cardiopatia ischemica precoce.
                            </text>
                        </section>
                    </component>
                    <component>
                        <section>
                            <code code="10219-4" codeSystem="2.16.840.1.113883.6.1" displayName="Esame Obiettivo ed ECG"/>
                            <title>Reperti Obiettivi e Strumentali</title>
                            <text>
                                Toni cardiaci netti, pause libere. Soffi assenti. Murmure vescicolare fisiologico su tutto l'ambito.
                                ECG: Ritmo sinusale a frequenza cardiaca media di 68 bpm. Asse elettrico intermedio. 
                                Conduzione AV e IV nei limiti (PR 140 ms, QRS 85 ms). Assenza di anomalie della ripolarizzazione ventricolare.
                            </text>
                        </section>
                    </component>
                    <component>
                        <section>
                            <code code="55110-1" codeSystem="2.16.840.1.113883.6.1" displayName="Conclusioni e Terapia"/>
                            <title>Conclusioni Diagnostiche e Indicazioni</title>
                            <text>
                                Quadro clinico-strumentale di normalità cardiologica. Non si ravvisano indicazioni a terapia farmacologica.
                                Si consiglia controllo periodico tra 12 mesi o prima in caso di comparsa di sintomatologia tipica.
                            </text>
                        </section>
                    </component>
                </structuredBody>
            </component>
        </ClinicalDocument>
        """
        return xmlString.data(using: .utf8)!
    }
}
