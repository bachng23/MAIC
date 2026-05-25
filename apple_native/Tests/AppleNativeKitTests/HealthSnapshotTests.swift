import XCTest
@testable import AppleNativeKit

final class HealthSnapshotTests: XCTestCase {

    func testSnapshotSource_watchSource_isWatch() {
        let snap = HealthSnapshot(
            heartRate: 72,
            hrv: 45,
            spo2: 98,
            timestamp: Date(),
            source: .watch,
            sourceDeviceName: "Apple Watch Series 9"
        )
        XCTAssertEqual(snap.source, .watch)
        XCTAssertTrue(snap.sourceDeviceName?.contains("Watch") == true)
    }

    func testSnapshotSource_iPhoneSource_isIPhone() {
        let snap = HealthSnapshot(
            heartRate: 72,
            hrv: nil,
            spo2: nil,
            timestamp: Date(),
            source: .iphone,
            sourceDeviceName: "iPhone 15"
        )
        XCTAssertEqual(snap.source, .iphone)
    }

    func testSnapshotSource_unknownSource_defaultsToUnknown() {
        let snap = HealthSnapshot(
            heartRate: 72,
            hrv: nil,
            spo2: nil,
            timestamp: Date()
        )
        XCTAssertEqual(snap.source, .unknown)
    }

    func testHealthSnapshot_allNilVitals_stillValid() {
        let snap = HealthSnapshot(
            heartRate: nil,
            hrv: nil,
            spo2: nil,
            timestamp: Date()
        )
        XCTAssertNil(snap.heartRate)
        XCTAssertNil(snap.hrv)
        XCTAssertNil(snap.spo2)
    }

    func testAnomalyThresholds_cardiacTighterThanStandard() {
        let cardiac = AnomalyThresholds.cardiac
        let standard = AnomalyThresholds.standard
        XCTAssertLessThan(cardiac.hrHighDelta, standard.hrHighDelta)
        XCTAssertLessThan(cardiac.safetyHrUpper, standard.safetyHrUpper)
        XCTAssertGreaterThan(cardiac.safetySpo2Lower, standard.safetySpo2Lower)
    }
}
