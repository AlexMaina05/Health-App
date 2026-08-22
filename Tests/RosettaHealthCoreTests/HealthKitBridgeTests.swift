import XCTest
@testable import RosettaHealthCore
import HealthKit

final class HealthKitBridgeTests: XCTestCase {
    
    // MARK: - LOINC Mapping Tests
    
    func testLOINCtoHealthKitMapping() {
        let bridge = HealthKitBridge()
        
        // Verifica Glicemia
        XCTAssertEqual(bridge.mapLOINCToHKTypeIdentifier(loinc: "15074-8"), .bloodGlucose)
        XCTAssertEqual(bridge.mapLOINCToHKTypeIdentifier(loinc: "2345-7"), .bloodGlucose)
        
        // Verifica Colesterolo
        XCTAssertEqual(bridge.mapLOINCToHKTypeIdentifier(loinc: "2093-3"), .dietaryCholesterol)
        XCTAssertEqual(bridge.mapLOINCToHKTypeIdentifier(loinc: "35200-5"), .dietaryCholesterol)
        
        // Verifica Pressione (Spesso composte)
        XCTAssertEqual(bridge.mapLOINCToHKTypeIdentifier(loinc: "8480-6"), .bloodPressureSystolic)
        XCTAssertEqual(bridge.mapLOINCToHKTypeIdentifier(loinc: "8462-4"), .bloodPressureDiastolic)
        
        // Verifica non mappati
        XCTAssertNil(bridge.mapLOINCToHKTypeIdentifier(loinc: "99999-9"), "LOINC sconosciuto dovrebbe restituire nil")
    }
    
    // MARK: - Blood Pressure String Parsing Tests
    
    func testBloodPressureStringParsing() {
        let bridge = HealthKitBridge()
        
        // Caso Perfetto: "120/80"
        let (sys1, dia1) = bridge.parseBloodPressureString("120/80")
        XCTAssertEqual(sys1, 120.0)
        XCTAssertEqual(dia1, 80.0)
        
        // Caso Sporco (Spazi extra): " 135 / 85  "
        let (sys2, dia2) = bridge.parseBloodPressureString(" 135 / 85  ")
        XCTAssertEqual(sys2, 135.0)
        XCTAssertEqual(dia2, 85.0)
        
        // Caso Formato Errato: "120"
        let (sys3, dia3) = bridge.parseBloodPressureString("120")
        XCTAssertNil(sys3)
        XCTAssertNil(dia3)
        
        // Caso Non Numerico: "Alta/Bassa"
        let (sys4, dia4) = bridge.parseBloodPressureString("Alta/Bassa")
        XCTAssertNil(sys4)
        XCTAssertNil(dia4)
    }
}
