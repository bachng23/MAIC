import Foundation

// MARK: - Configurable Thresholds

public struct AnomalyThresholds: Sendable {
    public let hrHighDelta: Double
    public let hrHighPercent: Double
    public let hrModerateDelta: Double
    public let hrModeratePercent: Double
    public let hrvHighDelta: Double
    public let hrvHighPercent: Double
    public let hrvModerateDelta: Double
    public let hrvModeratePercent: Double
    public let spo2HighDelta: Double
    public let spo2HighPercent: Double
    public let spo2ModerateDelta: Double
    public let spo2ModeratePercent: Double
    public let safetyHrUpper: Double
    public let safetySpo2Lower: Double

    public static let standard = AnomalyThresholds(
        hrHighDelta: 25, hrHighPercent: 30,
        hrModerateDelta: 15, hrModeratePercent: 20,
        hrvHighDelta: -15, hrvHighPercent: -35,
        hrvModerateDelta: -8, hrvModeratePercent: -20,
        spo2HighDelta: -3, spo2HighPercent: -4,
        spo2ModerateDelta: -2, spo2ModeratePercent: -3,
        safetyHrUpper: 120, safetySpo2Lower: 92
    )

    /// Tighter thresholds for drugs that directly affect heart rate / blood pressure.
    public static let cardiac = AnomalyThresholds(
        hrHighDelta: 20, hrHighPercent: 25,
        hrModerateDelta: 12, hrModeratePercent: 15,
        hrvHighDelta: -12, hrvHighPercent: -28,
        hrvModerateDelta: -6, hrvModeratePercent: -16,
        spo2HighDelta: -2.5, spo2HighPercent: -3.5,
        spo2ModerateDelta: -1.5, spo2ModeratePercent: -2.5,
        safetyHrUpper: 110, safetySpo2Lower: 93
    )

    public init(
        hrHighDelta: Double, hrHighPercent: Double,
        hrModerateDelta: Double, hrModeratePercent: Double,
        hrvHighDelta: Double, hrvHighPercent: Double,
        hrvModerateDelta: Double, hrvModeratePercent: Double,
        spo2HighDelta: Double, spo2HighPercent: Double,
        spo2ModerateDelta: Double, spo2ModeratePercent: Double,
        safetyHrUpper: Double, safetySpo2Lower: Double
    ) {
        self.hrHighDelta = hrHighDelta
        self.hrHighPercent = hrHighPercent
        self.hrModerateDelta = hrModerateDelta
        self.hrModeratePercent = hrModeratePercent
        self.hrvHighDelta = hrvHighDelta
        self.hrvHighPercent = hrvHighPercent
        self.hrvModerateDelta = hrvModerateDelta
        self.hrvModeratePercent = hrvModeratePercent
        self.spo2HighDelta = spo2HighDelta
        self.spo2HighPercent = spo2HighPercent
        self.spo2ModerateDelta = spo2ModerateDelta
        self.spo2ModeratePercent = spo2ModeratePercent
        self.safetyHrUpper = safetyHrUpper
        self.safetySpo2Lower = safetySpo2Lower
    }
}

// MARK: - AnomalyPredictor

public final class AnomalyPredictor {
    private let baselineStore: BaselineStore

    public init(baselineStore: BaselineStore = BaselineStore()) {
        self.baselineStore = baselineStore
    }

    public func predict(
        from snapshot: HealthSnapshot,
        medicationLogID: String? = nil,
        drugCategory: String? = nil
    ) async throws -> AnomalyPrediction {
        let thresholds = Self.drugCategoryThresholds(for: drugCategory)
        let baseline = await baselineStore.currentBaseline()
        let deviations = collectDeviations(for: snapshot, baseline: baseline)
        let safetyTriggered = safetyThresholdTriggered(for: snapshot, thresholds: thresholds)
        let crossSignalCount = countConcerningSignals(deviations: deviations, thresholds: thresholds)
        let anomalyLevel = scoreAnomalyLevel(
            deviations: deviations,
            baselineStatus: baseline.status,
            safetyTriggered: safetyTriggered,
            crossSignalCount: crossSignalCount,
            thresholds: thresholds
        )
        let anomalyType = classifyAnomaly(
            deviations: deviations,
            snapshot: snapshot,
            safetyTriggered: safetyTriggered,
            anomalyLevel: anomalyLevel,
            thresholds: thresholds
        )
        let confidence = confidenceScore(
            deviations: deviations,
            baselineStatus: baseline.status,
            safetyTriggered: safetyTriggered,
            crossSignalCount: crossSignalCount
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

    // MARK: - Drug-aware thresholds

    static func drugCategoryThresholds(for category: String?) -> AnomalyThresholds {
        guard let category else { return .standard }
        let lower = category.lowercased()
        let cardiacKeywords = [
            "cardiac", "cardiovascular", "antihypertensive", "antiarrhythmic",
            "beta-blocker", "beta blocker", "ace inhibitor", "calcium channel",
            "digoxin", "heart", "血壓", "心臟", "降壓"
        ]
        if cardiacKeywords.contains(where: { lower.contains($0) }) {
            return .cardiac
        }
        return .standard
    }

    // MARK: - Cross-signal correlation

    /// Returns how many signals are deviating in a concerning direction at the same time.
    private func countConcerningSignals(
        deviations: [SignalDeviation],
        thresholds: AnomalyThresholds
    ) -> Int {
        var count = 0
        for d in deviations {
            if isModerateSeverityDeviation(d, thresholds: thresholds) ||
               isHighSeverityDeviation(d, thresholds: thresholds) {
                count += 1
            }
        }
        return count
    }

    // MARK: - Deviation collection

    private func collectDeviations(
        for snapshot: HealthSnapshot,
        baseline: PersonalBaseline
    ) -> [SignalDeviation] {
        var deviations: [SignalDeviation] = []
        let heartRateBaseline = selectHeartRateBaseline(for: snapshot, baseline: baseline)

        if let heartRate = snapshot.heartRate, let baselineValue = heartRateBaseline {
            deviations.append(makeDeviation(signal: "heart_rate", currentValue: heartRate, baselineMedian: baselineValue.median))
        }
        if let hrv = snapshot.hrv, let baselineValue = baseline.hrv {
            deviations.append(makeDeviation(signal: "hrv", currentValue: hrv, baselineMedian: baselineValue.median))
        }
        if let spo2 = snapshot.spo2, let baselineValue = baseline.spo2 {
            deviations.append(makeDeviation(signal: "spo2", currentValue: spo2, baselineMedian: baselineValue.median))
        }
        return deviations
    }

    private func selectHeartRateBaseline(
        for snapshot: HealthSnapshot,
        baseline: PersonalBaseline
    ) -> HealthSignalBaseline? {
        switch Self.dayPeriod(for: snapshot.timestamp) {
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

    // MARK: - Scoring

    private func scoreAnomalyLevel(
        deviations: [SignalDeviation],
        baselineStatus: BaselineComputationStatus,
        safetyTriggered: Bool,
        crossSignalCount: Int,
        thresholds: AnomalyThresholds
    ) -> Int {
        if safetyTriggered { return 2 }

        let highSeverityCount = deviations.filter { isHighSeverityDeviation($0, thresholds: thresholds) }.count
        let moderateSeverityCount = deviations.filter { isModerateSeverityDeviation($0, thresholds: thresholds) }.count

        if baselineStatus == .insufficientData {
            return highSeverityCount > 0 ? 1 : 0
        }

        if highSeverityCount >= 2 { return 2 }

        // Cross-signal escalation: ≥2 moderate signals all concerning simultaneously → bump to 2
        if crossSignalCount >= 3 { return 2 }

        if highSeverityCount == 1 || moderateSeverityCount >= 2 { return 1 }
        if moderateSeverityCount == 1 { return 1 }

        return 0
    }

    private func classifyAnomaly(
        deviations: [SignalDeviation],
        snapshot: HealthSnapshot,
        safetyTriggered: Bool,
        anomalyLevel: Int,
        thresholds: AnomalyThresholds
    ) -> String {
        if anomalyLevel <= 0 { return "normal" }

        if safetyTriggered, let spo2 = snapshot.spo2, spo2 < thresholds.safetySpo2Lower {
            return "low_spo2"
        }

        if let hrDev = deviations.first(where: { $0.signal == "heart_rate" && $0.delta >= 0 }) {
            if hrDev.delta >= thresholds.hrHighDelta || hrDev.percentDelta >= thresholds.hrHighPercent {
                return "high_hr"
            }
        }

        if let hrvDev = deviations.first(where: { $0.signal == "hrv" && $0.delta < 0 }) {
            if hrvDev.percentDelta <= thresholds.hrvHighPercent { return "irregular_hrv" }
        }

        if let spo2Dev = deviations.first(where: { $0.signal == "spo2" && $0.delta < 0 }) {
            if spo2Dev.percentDelta <= thresholds.spo2HighPercent { return "low_spo2" }
        }

        return "combined"
    }

    private func confidenceScore(
        deviations: [SignalDeviation],
        baselineStatus: BaselineComputationStatus,
        safetyTriggered: Bool,
        crossSignalCount: Int
    ) -> Double {
        if safetyTriggered { return 0.95 }

        let maxMagnitude = deviations.map { abs($0.percentDelta) }.max() ?? 0
        let normalizedMagnitude = min(maxMagnitude / 50, 1)
        let baselineBoost: Double = switch baselineStatus {
            case .ready: 0.2
            case .stale: 0.1
            case .insufficientData: 0.0
        }
        // Multi-signal correlation bonus: more signals deviating together → higher confidence
        let correlationBonus: Double = switch crossSignalCount {
            case 2: 0.08
            case 3...: 0.15
            default: 0.0
        }

        return min(0.15 + normalizedMagnitude * 0.7 + baselineBoost + correlationBonus, 0.99)
    }

    // MARK: - Threshold helpers

    private func safetyThresholdTriggered(
        for snapshot: HealthSnapshot,
        thresholds: AnomalyThresholds
    ) -> Bool {
        if let hr = snapshot.heartRate, hr >= thresholds.safetyHrUpper { return true }
        if let spo2 = snapshot.spo2, spo2 < thresholds.safetySpo2Lower { return true }
        return false
    }

    private func isHighSeverityDeviation(
        _ deviation: SignalDeviation,
        thresholds: AnomalyThresholds
    ) -> Bool {
        switch deviation.signal {
        case "heart_rate":
            return deviation.delta >= thresholds.hrHighDelta || deviation.percentDelta >= thresholds.hrHighPercent
        case "hrv":
            return deviation.delta <= thresholds.hrvHighDelta || deviation.percentDelta <= thresholds.hrvHighPercent
        case "spo2":
            return deviation.delta <= thresholds.spo2HighDelta || deviation.percentDelta <= thresholds.spo2HighPercent
        default:
            return false
        }
    }

    private func isModerateSeverityDeviation(
        _ deviation: SignalDeviation,
        thresholds: AnomalyThresholds
    ) -> Bool {
        switch deviation.signal {
        case "heart_rate":
            return deviation.delta >= thresholds.hrModerateDelta || deviation.percentDelta >= thresholds.hrModeratePercent
        case "hrv":
            return deviation.delta <= thresholds.hrvModerateDelta || deviation.percentDelta <= thresholds.hrvModeratePercent
        case "spo2":
            return deviation.delta <= thresholds.spo2ModerateDelta || deviation.percentDelta <= thresholds.spo2ModeratePercent
        default:
            return false
        }
    }

    static func dayPeriod(for date: Date) -> DayPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<22: return .daytime
        case 0..<6, 22..<24: return .nighttime
        default: return .unknown
        }
    }
}
