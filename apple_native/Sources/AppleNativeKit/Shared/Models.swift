import Foundation

public struct OCRResult: Codable, Sendable {
    public let rawText: String
    public let lines: [String]

    public init(rawText: String, lines: [String]) {
        self.rawText = rawText
        self.lines = lines
    }
}

public enum MonitoringSessionState: String, Codable, Sendable {
    case idle
    case scheduled
    case collecting
    case analyzing
    case completed
    case cancelled
}

public enum BaselineComputationStatus: String, Codable, Sendable {
    case insufficientData
    case ready
    case stale
}

public enum ActivityState: String, Codable, Sendable {
    case resting
    case walking
    case workout
    case sleeping
    case unknown
}

public enum DayPeriod: String, Codable, Sendable {
    case daytime
    case nighttime
    case unknown
}

public enum SnapshotSource: String, Codable, Sendable {
    case iphone
    case watch
    case merged
    case unknown
}

public struct MonitoringWindow: Codable, Sendable {
    public let logID: String
    public let start: Date
    public let end: Date
    public let medicationName: String?
    public let medicationCategory: String?

    public init(
        logID: String,
        start: Date,
        end: Date,
        medicationName: String? = nil,
        medicationCategory: String? = nil
    ) {
        self.logID = logID
        self.start = start
        self.end = end
        self.medicationName = medicationName
        self.medicationCategory = medicationCategory
    }
}

public struct HealthSnapshot: Codable, Sendable {
    public let heartRate: Double?
    public let hrv: Double?
    public let spo2: Double?
    public let timestamp: Date
    public let sampleTimestamp: Date?
    public let activityState: ActivityState
    public let source: SnapshotSource
    public let sourceDeviceName: String?
    public let sourceDeviceModel: String?
    public let sourceAppName: String?

    public init(
        heartRate: Double?,
        hrv: Double?,
        spo2: Double?,
        timestamp: Date,
        sampleTimestamp: Date? = nil,
        activityState: ActivityState = .unknown,
        source: SnapshotSource = .unknown,
        sourceDeviceName: String? = nil,
        sourceDeviceModel: String? = nil,
        sourceAppName: String? = nil
    ) {
        self.heartRate = heartRate
        self.hrv = hrv
        self.spo2 = spo2
        self.timestamp = timestamp
        self.sampleTimestamp = sampleTimestamp
        self.activityState = activityState
        self.source = source
        self.sourceDeviceName = sourceDeviceName
        self.sourceDeviceModel = sourceDeviceModel
        self.sourceAppName = sourceAppName
    }
}

public struct MonitoringSession: Codable, Sendable {
    public let window: MonitoringWindow
    public let startedAt: Date?
    public let endedAt: Date?
    public let state: MonitoringSessionState
    public let snapshotCount: Int
    public let lastSnapshotAt: Date?

    public init(
        window: MonitoringWindow,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        state: MonitoringSessionState,
        snapshotCount: Int = 0,
        lastSnapshotAt: Date? = nil
    ) {
        self.window = window
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.state = state
        self.snapshotCount = snapshotCount
        self.lastSnapshotAt = lastSnapshotAt
    }
}

public struct HealthSignalBaseline: Codable, Sendable {
    public let min: Double
    public let max: Double
    public let average: Double
    public let median: Double

    public init(min: Double, max: Double, average: Double, median: Double) {
        self.min = min
        self.max = max
        self.average = average
        self.median = median
    }
}

public struct BaselineSample: Codable, Sendable {
    public let snapshot: HealthSnapshot
    public let isMedicationPeriod: Bool
    public let isAnomalous: Bool
    public let isIllnessPeriod: Bool
    public let isHighActivity: Bool
    public let dayPeriod: DayPeriod

    public init(
        snapshot: HealthSnapshot,
        isMedicationPeriod: Bool = false,
        isAnomalous: Bool = false,
        isIllnessPeriod: Bool = false,
        isHighActivity: Bool = false,
        dayPeriod: DayPeriod = .unknown
    ) {
        self.snapshot = snapshot
        self.isMedicationPeriod = isMedicationPeriod
        self.isAnomalous = isAnomalous
        self.isIllnessPeriod = isIllnessPeriod
        self.isHighActivity = isHighActivity
        self.dayPeriod = dayPeriod
    }
}

public struct PersonalBaseline: Codable, Sendable {
    public let generatedAt: Date
    public let observationStart: Date
    public let observationEnd: Date
    public let sampleCount: Int
    public let status: BaselineComputationStatus
    public let heartRate: HealthSignalBaseline?
    public let hrv: HealthSignalBaseline?
    public let spo2: HealthSignalBaseline?
    public let daytimeHeartRate: HealthSignalBaseline?
    public let nighttimeHeartRate: HealthSignalBaseline?

    public init(
        generatedAt: Date,
        observationStart: Date,
        observationEnd: Date,
        sampleCount: Int,
        status: BaselineComputationStatus,
        heartRate: HealthSignalBaseline?,
        hrv: HealthSignalBaseline?,
        spo2: HealthSignalBaseline?,
        daytimeHeartRate: HealthSignalBaseline? = nil,
        nighttimeHeartRate: HealthSignalBaseline? = nil
    ) {
        self.generatedAt = generatedAt
        self.observationStart = observationStart
        self.observationEnd = observationEnd
        self.sampleCount = sampleCount
        self.status = status
        self.heartRate = heartRate
        self.hrv = hrv
        self.spo2 = spo2
        self.daytimeHeartRate = daytimeHeartRate
        self.nighttimeHeartRate = nighttimeHeartRate
    }
}

public struct SignalDeviation: Codable, Sendable {
    public let signal: String
    public let currentValue: Double
    public let baselineMedian: Double
    public let delta: Double
    public let percentDelta: Double

    public init(
        signal: String,
        currentValue: Double,
        baselineMedian: Double,
        delta: Double,
        percentDelta: Double
    ) {
        self.signal = signal
        self.currentValue = currentValue
        self.baselineMedian = baselineMedian
        self.delta = delta
        self.percentDelta = percentDelta
    }
}

public struct AnomalyPrediction: Codable, Sendable {
    public let medicationLogID: String?
    public let anomalyLevel: Int
    public let anomalyType: String
    public let confidence: Double
    public let timestamp: Date
    public let deviations: [SignalDeviation]
    public let baselineStatus: BaselineComputationStatus?

    public init(
        medicationLogID: String? = nil,
        anomalyLevel: Int,
        anomalyType: String,
        confidence: Double,
        timestamp: Date,
        deviations: [SignalDeviation] = [],
        baselineStatus: BaselineComputationStatus? = nil
    ) {
        self.medicationLogID = medicationLogID
        self.anomalyLevel = anomalyLevel
        self.anomalyType = anomalyType
        self.confidence = confidence
        self.timestamp = timestamp
        self.deviations = deviations
        self.baselineStatus = baselineStatus
    }
}

public struct BackendAnomalyReport: Codable, Sendable {
    public let medicationLogID: String
    public let anomalyLevel: Int
    public let anomalyType: String
    public let coreMLConfidence: Double
    public let timestamp: Date

    public init(
        medicationLogID: String,
        anomalyLevel: Int,
        anomalyType: String,
        coreMLConfidence: Double,
        timestamp: Date
    ) {
        self.medicationLogID = medicationLogID
        self.anomalyLevel = anomalyLevel
        self.anomalyType = anomalyType
        self.coreMLConfidence = coreMLConfidence
        self.timestamp = timestamp
    }

    public init?(prediction: AnomalyPrediction) {
        guard
            let medicationLogID = prediction.medicationLogID,
            prediction.anomalyLevel > 0
        else {
            return nil
        }

        self.init(
            medicationLogID: medicationLogID,
            anomalyLevel: prediction.anomalyLevel,
            anomalyType: prediction.anomalyType,
            coreMLConfidence: prediction.confidence,
            timestamp: prediction.timestamp
        )
    }
}
