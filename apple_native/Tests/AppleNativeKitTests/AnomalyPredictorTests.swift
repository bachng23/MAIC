import XCTest
@testable import AppleNativeKit

final class AnomalyPredictorTests: XCTestCase {

    // MARK: - Helpers

    private func makePredictor() -> AnomalyPredictor {
        AnomalyPredictor(baselineStore: BaselineStore())
    }

    private func makePredictorWithBaseline(_ baseline: PersonalBaseline) async -> AnomalyPredictor {
        let store = BaselineStore()
        await store.setTestBaseline(baseline)
        return AnomalyPredictor(baselineStore: store)
    }

    private func snapshot(hr: Double? = 72, hrv: Double? = 45, spo2: Double? = 98) -> HealthSnapshot {
        HealthSnapshot(
            heartRate: hr,
            hrv: hrv,
            spo2: spo2,
            timestamp: Date(),
            activityState: .resting
        )
    }

    private func readyBaseline(hr: Double = 72, hrv: Double = 45, spo2: Double = 98) -> PersonalBaseline {
        PersonalBaseline(
            generatedAt: Date(),
            observationStart: Date().addingTimeInterval(-14 * 86400),
            observationEnd: Date(),
            sampleCount: 100,
            status: .ready,
            heartRate: HealthSignalBaseline(min: hr - 10, max: hr + 10, average: hr, median: hr),
            hrv: HealthSignalBaseline(min: hrv - 10, max: hrv + 10, average: hrv, median: hrv),
            spo2: HealthSignalBaseline(min: spo2 - 2, max: spo2 + 1, average: spo2, median: spo2)
        )
    }

    // MARK: - Safety threshold tests

    func testSafetyThreshold_HR120_returnsLevel2() async throws {
        let predictor = makePredictor()
        let snap = snapshot(hr: 121, hrv: 45, spo2: 98)
        let result = try await predictor.predict(from: snap)
        XCTAssertEqual(result.anomalyLevel, 2)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.9)
    }

    func testSafetyThreshold_SpO2Below92_returnsLevel2() async throws {
        let predictor = makePredictor()
        let snap = snapshot(hr: 72, hrv: 45, spo2: 91)
        let result = try await predictor.predict(from: snap)
        XCTAssertEqual(result.anomalyLevel, 2)
        XCTAssertEqual(result.anomalyType, "low_spo2")
    }

    func testCardiacDrug_lowerSafetyThreshold_triggersEarlier() async throws {
        let predictor = makePredictor()
        // HR 115 — below standard threshold (120) but above cardiac threshold (110)
        let snap = snapshot(hr: 115)
        let standardResult = try await predictor.predict(from: snap, drugCategory: nil)
        let cardiacResult  = try await predictor.predict(from: snap, drugCategory: "cardiac")
        XCTAssertEqual(standardResult.anomalyLevel, 0,
                       "Standard thresholds should not flag HR=115")
        XCTAssertEqual(cardiacResult.anomalyLevel, 2,
                       "Cardiac thresholds should flag HR=115 (>110)")
    }

    // MARK: - Normal readings

    func testNormalReadings_returnsLevel0() async throws {
        let predictor = await makePredictorWithBaseline(readyBaseline())
        let snap = snapshot(hr: 72, hrv: 45, spo2: 98)
        let result = try await predictor.predict(from: snap)
        XCTAssertEqual(result.anomalyLevel, 0)
        XCTAssertEqual(result.anomalyType, "normal")
    }

    // MARK: - Insufficient baseline

    func testInsufficientBaseline_onlyHighSeverityTriggersWarning() async throws {
        let predictor = makePredictor()
        // HR 121 — safety threshold triggers even without baseline
        let criticalSnap = snapshot(hr: 121)
        let r1 = try await predictor.predict(from: criticalSnap)
        XCTAssertEqual(r1.anomalyLevel, 2)
    }

    // MARK: - Cross-signal correlation

    func testCrossSignalCorrelation_allThreeDeviating_escalatesToLevel2() async throws {
        let predictor = await makePredictorWithBaseline(readyBaseline(hr: 70, hrv: 50, spo2: 98))
        // HR +20 (moderate), HRV -12 (moderate), SpO2 -2.5 (moderate) — all three concurrent
        let snap = snapshot(hr: 90, hrv: 38, spo2: 95.5)
        let result = try await predictor.predict(from: snap)
        XCTAssertEqual(result.anomalyLevel, 2, "All 3 signals deviating should escalate to level 2")
        XCTAssertGreaterThan(result.confidence, 0.5)
    }

    func testCrossSignalCorrelation_twoSignals_boostsConfidence() async throws {
        let predictor = await makePredictorWithBaseline(readyBaseline(hr: 70, hrv: 50, spo2: 98))
        let singleResult = try await predictor.predict(from: snapshot(hr: 85, hrv: 50, spo2: 98))
        let dualResult   = try await predictor.predict(from: snapshot(hr: 85, hrv: 40, spo2: 98))
        XCTAssertGreaterThan(dualResult.confidence, singleResult.confidence,
                             "Two deviating signals should have higher confidence than one")
    }

    // MARK: - Drug category thresholds

    func testDrugCategoryThresholds_cardiacReturnsCardiacPreset() {
        let thresholds = AnomalyPredictor.drugCategoryThresholds(for: "cardiac medication")
        XCTAssertEqual(thresholds.safetyHrUpper, 110)
    }

    func testDrugCategoryThresholds_nilReturnsStandard() {
        let thresholds = AnomalyPredictor.drugCategoryThresholds(for: nil)
        XCTAssertEqual(thresholds.safetyHrUpper, 120)
    }

    func testDrugCategoryThresholds_chineseCardiac_returnsCardiacPreset() {
        let thresholds = AnomalyPredictor.drugCategoryThresholds(for: "降壓藥")
        XCTAssertEqual(thresholds.safetyHrUpper, 110)
    }
}
