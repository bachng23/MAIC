import Foundation

public enum FlutterBridgeContracts {
    public static let recognizeTextMethod = "recognizeTextFromImage"
    public static let recognizeTextFromFileMethod = "recognizeTextFromFile"
    public static let pickImageFromLibraryMethod = "pickImageFromLibrary"
    public static let requestHealthPermissionsMethod = "requestHealthPermissions"
    public static let startMonitoringMethod = "startMonitoring"
    public static let stopMonitoringMethod = "stopMonitoring"
    public static let latestSnapshotMethod = "getLatestHealthSnapshot"
    public static let currentMonitoringSessionMethod = "getCurrentMonitoringSession"
    public static let currentBaselineMethod = "getCurrentBaseline"
    public static let predictAnomalyMethod = "predictAnomaly"
    public static let loadModelStatusMethod = "loadModelStatus"

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601String(from: date))
        }
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = iso8601Date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected date string to be ISO8601-formatted."
            )
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    public static func decode<T: Decodable>(_ type: T.Type, from arguments: Any?) throws -> T {
        guard let arguments else {
            throw FlutterBridgeError.missingArguments
        }

        let data: Data
        if let dictionary = arguments as? [String: Any] {
            data = try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
        } else if let array = arguments as? [Any] {
            data = try JSONSerialization.data(withJSONObject: array, options: [.sortedKeys])
        } else if let string = arguments as? String {
            guard let stringData = string.data(using: .utf8) else {
                throw FlutterBridgeError.invalidUTF8Payload
            }
            data = stringData
        } else {
            throw FlutterBridgeError.unsupportedArguments
        }

        return try decoder.decode(type, from: data)
    }

    public static func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data, options: [])

        guard let dictionary = object as? [String: Any] else {
            throw FlutterBridgeError.nonDictionaryResponse
        }

        return dictionary
    }

    private static func iso8601Date(from value: String) -> Date? {
        if let date = fractionalSecondsDateFormatter.date(from: value) {
            return date
        }

        return defaultDateFormatter.date(from: value)
    }

    private static func iso8601String(from date: Date) -> String {
        fractionalSecondsDateFormatter.string(from: date)
    }

    private static let fractionalSecondsDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        return formatter
    }()

    private static let defaultDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

public enum FlutterBridgeError: Error {
    case missingArguments
    case unsupportedArguments
    case invalidUTF8Payload
    case nonDictionaryResponse
}

public struct FlutterBridgeErrorPayload: Codable, Sendable {
    public let code: String
    public let message: String
    public let details: String?
    public let timestamp: Date

    public init(
        code: String,
        message: String,
        details: String? = nil,
        timestamp: Date = Date()
    ) {
        self.code = code
        self.message = message
        self.details = details
        self.timestamp = timestamp
    }
}

public struct HealthPermissionResponse: Codable, Sendable {
    public let granted: Bool
    public let requestedAt: Date

    public init(granted: Bool, requestedAt: Date = Date()) {
        self.granted = granted
        self.requestedAt = requestedAt
    }
}

public struct StartMonitoringRequest: Codable, Sendable {
    public let logId: String
    public let start: Date
    public let end: Date
    public let medicationName: String?
    public let medicationCategory: String?

    public init(
        logId: String,
        start: Date,
        end: Date,
        medicationName: String? = nil,
        medicationCategory: String? = nil
    ) {
        self.logId = logId
        self.start = start
        self.end = end
        self.medicationName = medicationName
        self.medicationCategory = medicationCategory
    }

    public func monitoringWindow() -> MonitoringWindow {
        MonitoringWindow(
            logID: logId,
            start: start,
            end: end,
            medicationName: medicationName,
            medicationCategory: medicationCategory
        )
    }
}

public struct StopMonitoringResponse: Codable, Sendable {
    public let stopped: Bool
    public let timestamp: Date

    public init(stopped: Bool, timestamp: Date = Date()) {
        self.stopped = stopped
        self.timestamp = timestamp
    }
}

public struct SnapshotResponse: Codable, Sendable {
    public let snapshot: HealthSnapshot?

    public init(snapshot: HealthSnapshot?) {
        self.snapshot = snapshot
    }
}

public struct MonitoringSessionResponse: Codable, Sendable {
    public let session: MonitoringSession?

    public init(session: MonitoringSession?) {
        self.session = session
    }
}

public struct BaselineResponse: Codable, Sendable {
    public let baseline: PersonalBaseline

    public init(baseline: PersonalBaseline) {
        self.baseline = baseline
    }
}

public struct PredictAnomalyRequest: Codable, Sendable {
    public let medicationLogId: String?
    public let snapshot: HealthSnapshot

    public init(medicationLogId: String? = nil, snapshot: HealthSnapshot) {
        self.medicationLogId = medicationLogId
        self.snapshot = snapshot
    }
}

public struct PredictAnomalyResponse: Codable, Sendable {
    public let prediction: AnomalyPrediction
    public let backendReport: BackendAnomalyReport?

    public init(prediction: AnomalyPrediction) {
        self.prediction = prediction
        self.backendReport = BackendAnomalyReport(prediction: prediction)
    }
}

public struct ModelStatusResponse: Codable, Sendable {
    public let loaded: Bool
    public let modelName: String
    public let modelVersion: String
    public let mode: String

    public init(
        loaded: Bool,
        modelName: String,
        modelVersion: String,
        mode: String
    ) {
        self.loaded = loaded
        self.modelName = modelName
        self.modelVersion = modelVersion
        self.mode = mode
    }
}

public struct PickedImageResponse: Codable, Sendable {
    public let imagePath: String

    public init(imagePath: String) {
        self.imagePath = imagePath
    }
}
