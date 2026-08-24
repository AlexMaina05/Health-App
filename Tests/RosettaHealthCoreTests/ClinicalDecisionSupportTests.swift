import XCTest
import HealthKit
@testable import RosettaHealthCore

final class ClinicalDecisionSupportTests: XCTestCase {
    
    func testCholesterolWorseningTrend() async throws {
        let cds = ClinicalDecisionSupport()
        let unit = HKUnit(from: "mg/dL")
        let type = HKQuantityType.quantityType(forIdentifier: .dietaryCholesterol)!
        
        let now = Date()
        let s1 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 150), start: now.addingTimeInterval(-86400 * 30), end: now.addingTimeInterval(-86400 * 30))
        let s2 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 180), start: now.addingTimeInterval(-86400 * 15), end: now.addingTimeInterval(-86400 * 15))
        let s3 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 210), start: now, end: now)
        
        let alert = await cds.analyze(samples: [s1, s2, s3], type: .dietaryCholesterol)
        
        XCTAssertNotNil(alert)
        XCTAssertEqual(alert?.metricName, "Colesterolo")
        XCTAssertEqual(alert?.severity, .warning)
    }
    
    func testCholesterolImprovingTrend() async throws {
        let cds = ClinicalDecisionSupport()
        let unit = HKUnit(from: "mg/dL")
        let type = HKQuantityType.quantityType(forIdentifier: .dietaryCholesterol)!
        
        let now = Date()
        let s1 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 220), start: now.addingTimeInterval(-86400 * 30), end: now.addingTimeInterval(-86400 * 30))
        let s2 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 190), start: now.addingTimeInterval(-86400 * 15), end: now.addingTimeInterval(-86400 * 15))
        let s3 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 160), start: now, end: now)
        
        let alert = await cds.analyze(samples: [s1, s2, s3], type: .dietaryCholesterol)
        
        XCTAssertNil(alert, "Non ci deve essere alert se il colesterolo sta migliorando")
    }
    
    func testGlucoseCriticalTrend() async throws {
        let cds = ClinicalDecisionSupport()
        let unit = HKUnit(from: "mg/dL")
        let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
        
        let now = Date()
        let s1 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 80), start: now.addingTimeInterval(-86400 * 30), end: now.addingTimeInterval(-86400 * 30))
        let s2 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 95), start: now.addingTimeInterval(-86400 * 15), end: now.addingTimeInterval(-86400 * 15))
        let s3 = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 105), start: now, end: now)
        
        let alert = await cds.analyze(samples: [s1, s2, s3], type: .bloodGlucose)
        
        XCTAssertNotNil(alert)
        XCTAssertEqual(alert?.metricName, "Glicemia")
    }
}