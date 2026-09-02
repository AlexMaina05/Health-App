import XCTest
import HealthKit
@testable import RosettaHealthCore

final class ValidationGateTests: XCTestCase {
    var healthBridge: HealthKitBridge!
    
    override func setUp() {
        super.setUp()
        healthBridge = HealthKitBridge()
    }
    
    // Test the internal validation method directly via a wrapper if needed, 
    // or test the public ingestQuantities method with mock FHIR bundles.
    func testGlucosePhysiologicalLimits() async throws {
        // Arrange
        let mockBundle = createMockFHIRBundle(loinc: "15074-8", value: 3000, unit: "mg/dL") // Assurdamente alto (Poisoning)
        
        // Act
        let result = try await healthBridge.ingestQuantities(fhirBundle: mockBundle)
        
        // Assert
        XCTAssertEqual(result.savedCount, 0, "Il Validation Gate ha fallito nel bloccare un valore di glucosio letale (3000 mg/dL)")
        XCTAssertEqual(result.skippedObservations.count, 1)
    }
    
    func testGlucoseValid() async throws {
        let mockBundle = createMockFHIRBundle(loinc: "15074-8", value: 95, unit: "mg/dL")
        let result = try await healthBridge.ingestQuantities(fhirBundle: mockBundle)
        // HKHealthStore requires permissions to actually save in tests, so savedCount might be 0 anyway if unauthorized, 
        // but we can check if it was SKIPPED by the validation gate.
        XCTAssertEqual(result.skippedObservations.count, 0, "Il Validation Gate ha bloccato erroneamente un valore sano")
    }
    
    func testBloodPressureLimits() async throws {
        let mockBundle = createMockFHIRBundle(loinc: "85354-9", valueString: "400/90") // Sistolica impossibile
        let result = try await healthBridge.ingestQuantities(fhirBundle: mockBundle)
        XCTAssertEqual(result.skippedObservations.count, 1, "Validation Gate fallito su pressione sistolica")
    }
    
    private func createMockFHIRBundle(loinc: String, value: Double? = nil, valueString: String? = nil, unit: String = "") -> FHIRBundle {
        let code = FHIRCodeableConcept(coding: [FHIRCoding(system: "http://loinc.org", code: loinc, display: "Test")], text: "Test")
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
        return FHIRBundle(timestamp: ISO8601DateFormatter().string(from: Date()), entry: [FHIRBundleEntry(fullUrl: nil, resource: .observation(obs))])
    }
}
