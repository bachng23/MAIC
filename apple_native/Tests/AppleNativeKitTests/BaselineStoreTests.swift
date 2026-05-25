import XCTest
@testable import AppleNativeKit

final class BaselineStoreTests: XCTestCase {

    func testInitialBaseline_returnsInsufficient() async {
        let store = BaselineStore()
        let baseline = await store.currentBaseline()
        XCTAssertEqual(baseline.status, .insufficientData)
        XCTAssertEqual(baseline.sampleCount, 0)
    }

    func testCurrentBaseline_afterSetTestBaseline_returnsReady() async {
        let store = BaselineStore()
        let baseline = PersonalBaseline(
            generatedAt: Date(),
            observationStart: Date().addingTimeInterval(-14 * 86400),
            observationEnd: Date(),
            sampleCount: 100,
            status: .ready,
            heartRate: HealthSignalBaseline(min: 60, max: 80, average: 70, median: 70),
            hrv: nil,
            spo2: nil
        )
        await store.setTestBaseline(baseline)
        let result = await store.currentBaseline()
        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.sampleCount, 100)
    }

    func testDayPeriodClassification() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())

        components.hour = 10
        components.minute = 0
        let daytime = calendar.date(from: components)!
        XCTAssertEqual(AnomalyPredictor.dayPeriod(for: daytime), .daytime)

        components.hour = 2
        let nighttime = calendar.date(from: components)!
        XCTAssertEqual(AnomalyPredictor.dayPeriod(for: nighttime), .nighttime)

        components.hour = 23
        let lateNight = calendar.date(from: components)!
        XCTAssertEqual(AnomalyPredictor.dayPeriod(for: lateNight), .nighttime)
    }
}
