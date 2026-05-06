import Foundation

public final class AnomalyPredictor {
    private let baselineStore: BaselineStore

    public init(baselineStore: BaselineStore = BaselineStore()) {
        self.baselineStore = baselineStore
    }

    public func predict(
        from snapshot: HealthSnapshot,
        medicationLogID: String? = nil
    ) async throws -> AnomalyPrediction {
        let baseline = await baselineStore.currentBaseline()
        let deviations = collectDeviations(for: snapshot, baseline: baseline)
        let safetyTriggered = safetyThresholdTriggered(for: snapshot)
        let anomalyLevel = scoreAnomalyLevel(
            deviations: deviations,
            baselineStatus: baseline.status,
            safetyTriggered: safetyTriggered
        )
        let anomalyType = classifyAnomaly(
            deviations: deviations,
            snapshot: snapshot,
            safetyTriggered: safetyTriggered,
            anomalyLevel: anomalyLevel
        )
        let confidence = confidenceScore(
            deviations: deviations,
            baselineStatus: baseline.status,
            safetyTriggered: safetyTriggered
        )

        return AnomalyPrediction(
            medicationLogID: medicationLogID,
            anomalyLevel: anomalyLevel,
            anomalyType: anomalyType,
            confidence: confidence,
            timestamp: snapshot.timestamp,
            deviations: deviations,
            baselineStatus: baseline.status
        )
    }

    private func collectDeviations(
        for snapshot: HealthSnapshot,
        baseline: PersonalBaseline
    ) -> [SignalDeviation] {
        var deviations: [SignalDeviation] = []
        let heartRateBaseline = selectHeartRateBaseline(for: snapshot, baseline: baseline)

        if let heartRate = snapshot.heartRate, let baselineValue = heartRateBaseline {
            deviations.append(
                makeDeviation(
                    signal: "heart_rate",
                    currentValue: heartRate,
                    baselineMedian: baselineValue.median
                )
            )
        }

        if let hrv = snapshot.hrv, let baselineValue = baseline.hrv {
            deviations.append(
                makeDeviation(
                    signal: "hrv",
                    currentValue: hrv,
                    baselineMedian: baselineValue.median
                )
            )
        }

        if let spo2 = snapshot.spo2, let baselineValue = baseline.spo2 {
            deviations.append(
                makeDeviation(
                    signal: "spo2",
                    currentValue: spo2,
                    baselineMedian: baselineValue.median
                )
            )
        }

        return deviations
    }

    private func selectHeartRateBaseline(
        for snapshot: HealthSnapshot,
        baseline: PersonalBaseline
    ) -> HealthSignalBaseline? {
        switch dayPeriod(for: snapshot.timestamp) {
        case .daytime:
            return baseline.daytimeHeartRate ?? baseline.heartRate
        case .nighttime:
            return baseline.nighttimeHeartRate ?? baseline.heartRate
        case .unknown:
            return baseline.heartRate
        }
    }

    private func makeDeviation(
        signal: String,
        currentValue: Double,
        baselineMedian: Double
    ) -> SignalDeviation {
        let delta = currentValue - baselineMedian
        let percentDelta = baselineMedian == 0 ? 0 : (delta / baselineMedian) * 100
        return SignalDeviation(
            signal: signal,
            currentValue: currentValue,
            baselineMedian: baselineMedian,
            delta: delta,
            percentDelta: percentDelta
        )
    }

    private func scoreAnomalyLevel(
        deviations: [SignalDeviation],
        baselineStatus: BaselineComputationStatus,
        safetyTriggered: Bool
    ) -> Int {
        if safetyTriggered {
            return 2
        }

        let highSeverityCount = deviations.filter(isHighSeverityDeviation).count
        let moderateSeverityCount = deviations.filter(isModerateSeverityDeviation).count

        if baselineStatus == .insufficientData {
            return highSeverityCount > 0 ? 1 : 0
        }

        if highSeverityCount >= 2 {
            return 2
        }

        if highSeverityCount == 1 || moderateSeverityCount >= 2 {
            return 1
        }

        if moderateSeverityCount == 1 {
            return 1
        }

        return 0
    }

    private func classifyAnomaly(
        deviations: [SignalDeviation],
        snapshot: HealthSnapshot,
        safetyTriggered: Bool,
        anomalyLevel: Int
    ) -> String {
        if anomalyLevel <= 0 {
            return "normal"
        }

        if safetyTriggered, let spo2 = snapshot.spo2, spo2 < 92 {
            return "low_spo2"
        }

        if let heartRateDeviation = deviations.first(where: { $0.signal == "heart_rate" && $0.delta >= 0 }) {
            if heartRateDeviation.delta >= 25 || heartRateDeviation.percentDelta >= 30 {
                return "high_hr"
            }
        }

        if let hrvDeviation = deviations.first(where: { $0.signal == "hrv" && $0.delta < 0 }) {
            if hrvDeviation.percentDelta <= -35 {
                return "irregular_hrv"
            }
        }

        if let spo2Deviation = deviations.first(where: { $0.signal == "spo2" && $0.delta < 0 }) {
            if spo2Deviation.percentDelta <= -4 {
                return "low_spo2"
            }
        }

        return "combined"
    }

    private func confidenceScore(
        deviations: [SignalDeviation],
        baselineStatus: BaselineComputationStatus,
        safetyTriggered: Bool
    ) -> Double {
        if safetyTriggered {
            return 0.95
        }

        let maxMagnitude = deviations.map { abs($0.percentDelta) }.max() ?? 0
        let normalizedMagnitude = min(maxMagnitude / 50, 1)
        let baselineBoost: Double

        switch baselineStatus {
        case .ready:
            baselineBoost = 0.2
        case .stale:
            baselineBoost = 0.1
        case .insufficientData:
            baselineBoost = 0.0
        }

        return min(0.15 + normalizedMagnitude * 0.7 + baselineBoost, 0.99)
    }

    private func safetyThresholdTriggered(for snapshot: HealthSnapshot) -> Bool {
        if let heartRate = snapshot.heartRate, heartRate >= 120 {
            return true
        }

        if let spo2 = snapshot.spo2, spo2 < 92 {
            return true
        }

        return false
    }

    private func isHighSeverityDeviation(_ deviation: SignalDeviation) -> Bool {
        switch deviation.signal {
        case "heart_rate":
            return deviation.delta >= 25 || deviation.percentDelta >= 30
        case "hrv":
            return deviation.delta <= -15 || deviation.percentDelta <= -35
        case "spo2":
            return deviation.delta <= -3 || deviation.percentDelta <= -4
        default:
            return false
        }
    }

    private func isModerateSeverityDeviation(_ deviation: SignalDeviation) -> Bool {
        switch deviation.signal {
        case "heart_rate":
            return deviation.delta >= 15 || deviation.percentDelta >= 20
        case "hrv":
            return deviation.delta <= -8 || deviation.percentDelta <= -20
        case "spo2":
            return deviation.delta <= -2 || deviation.percentDelta <= -3
        default:
            return false
        }
    }

    private func dayPeriod(for date: Date) -> DayPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<22:
            return .daytime
        case 0..<6, 22..<24:
            return .nighttime
        default:
            return .unknown
        }
    }
}
