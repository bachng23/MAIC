import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

@available(macOS 13.0, iOS 17.0, watchOS 10.0, *)
public final class HealthMonitoringService {
    private let state: MonitoringRuntimeState
    private let baselineStore: BaselineStore
    private let pollingIntervalNanoseconds: UInt64

    public init(
        baselineStore: BaselineStore = BaselineStore(),
        pollingIntervalNanoseconds: UInt64 = 60_000_000_000
    ) {
        self.state = MonitoringRuntimeState()
        self.baselineStore = baselineStore
        self.pollingIntervalNanoseconds = pollingIntervalNanoseconds
    }

    public func requestPermissions() async throws {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthMonitoringError.healthDataUnavailable
        }

        let healthStore = HKHealthStore()
        let quantityTypes = Set(Self.requiredQuantityTypes())
        try await requestAuthorization(healthStore: healthStore, quantityTypes: quantityTypes)
        await state.setHealthStore(healthStore)
        #else
        throw HealthMonitoringError.healthKitUnavailable
        #endif
    }

    public func startMonitoring(window: MonitoringWindow) async throws {
        let healthStore = try await state.requireHealthStore()
        let now = Date()
        let initialState: MonitoringSessionState = now >= window.start ? .collecting : .scheduled
        await state.beginSession(
            MonitoringSession(
                window: window,
                startedAt: now >= window.start ? now : nil,
                state: initialState
            )
        )

        let task = Task { [weak self] in
            guard let self else { return }
            await self.runMonitoringLoop(healthStore: healthStore, window: window)
        }

        await state.setMonitoringTask(task)
    }

    public func stopMonitoring() async {
        await state.stopCurrentSession(markAs: .cancelled)
    }

    public func latestSnapshot() async -> HealthSnapshot? {
        await state.latestSnapshot()
    }

    public func currentSession() async -> MonitoringSession? {
        await state.currentSession()
    }

    public func currentBaseline() async -> PersonalBaseline {
        await baselineStore.currentBaseline()
    }

    private func runMonitoringLoop(
        healthStore: Any,
        window: MonitoringWindow
    ) async {
        #if canImport(HealthKit)
        guard let healthStore = healthStore as? HKHealthStore else { return }

        do {
            while !Task.isCancelled {
                let now = Date()
                if now < window.start {
                    let waitTime = min(
                        pollingIntervalNanoseconds,
                        nanoseconds(until: window.start, from: now)
                    )
                    try await Task.sleep(nanoseconds: waitTime)
                    continue
                }

                if now >= window.end {
                    await state.finishCurrentSession(at: now)
                    return
                }

                await state.updateSessionState(.collecting, startedAt: now)
                let snapshot = try await fetchLatestSnapshot(healthStore: healthStore, at: now)
                await state.record(snapshot)
                await baselineStore.appendMonitoringSample(
                    snapshot,
                    isMedicationPeriod: true,
                    isAnomalous: false,
                    dayPeriod: Self.dayPeriod(for: snapshot.timestamp)
                )

                let remaining = nanoseconds(until: window.end, from: Date())
                if remaining == 0 {
                    await state.finishCurrentSession(at: Date())
                    return
                }

                try await Task.sleep(
                    nanoseconds: min(pollingIntervalNanoseconds, remaining)
                )
            }
        } catch is CancellationError {
            await state.stopCurrentSession(markAs: .cancelled)
        } catch {
            await state.stopCurrentSession(markAs: .cancelled)
        }
        #else
        _ = healthStore
        _ = window
        #endif
    }

    #if canImport(HealthKit)
    private static func requiredQuantityTypes() -> [HKQuantityType] {
        [
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
        ].compactMap { $0 }
    }

    private func requestAuthorization(
        healthStore: HKHealthStore,
        quantityTypes: Set<HKQuantityType>
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: quantityTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthMonitoringError.authorizationDenied)
                }
            }
        }
    }

    private func fetchLatestSnapshot(
        healthStore: HKHealthStore,
        at timestamp: Date
    ) async throws -> HealthSnapshot {
        async let heartRateSample = latestQuantitySample(
            for: .heartRate,
            from: healthStore
        )
        async let hrvSample = latestQuantitySample(
            for: .heartRateVariabilitySDNN,
            from: healthStore
        )
        async let spo2Sample = latestQuantitySample(
            for: .oxygenSaturation,
            from: healthStore
        )

        let heartRate = try await heartRateSample
        let hrv = try await hrvSample
        let spo2 = try await spo2Sample

        let sourceSummary = Self.summarizeSources(
            from: [heartRate?.sample, hrv?.sample, spo2?.sample].compactMap { $0 }
        )

        return HealthSnapshot(
            heartRate: heartRate?.value,
            hrv: hrv?.value,
            spo2: spo2?.value,
            timestamp: timestamp,
            sampleTimestamp: sourceSummary.sampleTimestamp,
            activityState: .unknown,
            source: sourceSummary.source,
            sourceDeviceName: sourceSummary.deviceName,
            sourceDeviceModel: sourceSummary.deviceModel,
            sourceAppName: sourceSummary.sourceAppName
        )
    }

    private func latestQuantitySample(
        for identifier: HKQuantityTypeIdentifier,
        from healthStore: HKHealthStore
    ) async throws -> QuantityReading? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(
                    returning: QuantityReading(
                        sample: sample,
                        value: Self.convert(sample: sample, for: identifier)
                    )
                )
            }

            healthStore.execute(query)
        }
    }

    private static func convert(
        sample: HKQuantitySample,
        for identifier: HKQuantityTypeIdentifier
    ) -> Double {
        switch identifier {
        case .heartRate:
            let unit = HKUnit.count().unitDivided(by: .minute())
            return sample.quantity.doubleValue(for: unit)
        case .heartRateVariabilitySDNN:
            let unit = HKUnit.secondUnit(with: .milli)
            return sample.quantity.doubleValue(for: unit)
        case .oxygenSaturation:
            let unit = HKUnit.percent()
            return sample.quantity.doubleValue(for: unit) * 100
        default:
            return 0
        }
    }

    private static func inferSource(from sample: HKQuantitySample) -> SnapshotSource {
        let sourceText = [
            sample.device?.model,
            sample.device?.name,
            sample.sourceRevision.source.name,
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")

        if sourceText.contains("watch") {
            return .watch
        }

        if sourceText.contains("iphone") || sourceText.contains("ios") {
            return .iphone
        }

        return .unknown
    }

    private static func summarizeSources(from samples: [HKQuantitySample]) -> SampleSourceSummary {
        guard !samples.isEmpty else {
            return SampleSourceSummary(
                source: .unknown,
                sampleTimestamp: nil,
                deviceName: nil,
                deviceModel: nil,
                sourceAppName: nil
            )
        }

        let sampleOrigins = samples.map { sample in
            SampleOrigin(
                source: inferSource(from: sample),
                sampleTimestamp: sample.endDate,
                deviceName: sample.device?.name,
                deviceModel: sample.device?.model,
                sourceAppName: sample.sourceRevision.source.name
            )
        }

        let knownSources = Set(sampleOrigins.map(\.source).filter { $0 != .unknown })
        let resolvedSource: SnapshotSource
        if knownSources.count > 1 {
            resolvedSource = .merged
        } else if let singleSource = knownSources.first {
            resolvedSource = singleSource
        } else {
            resolvedSource = .unknown
        }

        let representativeSample = sampleOrigins.max(by: {
            ($0.sampleTimestamp ?? .distantPast) < ($1.sampleTimestamp ?? .distantPast)
        })

        return SampleSourceSummary(
            source: resolvedSource,
            sampleTimestamp: representativeSample?.sampleTimestamp,
            deviceName: representativeSample?.deviceName,
            deviceModel: representativeSample?.deviceModel,
            sourceAppName: representativeSample?.sourceAppName
        )
    }
    #endif

    private static func dayPeriod(for date: Date) -> DayPeriod {
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

    private func nanoseconds(until endDate: Date, from startDate: Date) -> UInt64 {
        let interval = max(0, endDate.timeIntervalSince(startDate))
        return UInt64(interval * 1_000_000_000)
    }
}

public enum HealthMonitoringError: Error {
    case healthKitUnavailable
    case healthDataUnavailable
    case authorizationDenied
    case permissionsNotRequested
}

@available(macOS 13.0, iOS 17.0, watchOS 10.0, *)
private actor MonitoringRuntimeState {
    private var healthStore: Any?
    private var monitoringTask: Task<Void, Never>?
    private var session: MonitoringSession?
    private var latestSnapshotValue: HealthSnapshot?

    func setHealthStore(_ healthStore: Any) {
        self.healthStore = healthStore
    }

    func requireHealthStore() throws -> Any {
        guard let healthStore else {
            throw HealthMonitoringError.permissionsNotRequested
        }
        return healthStore
    }

    func beginSession(_ session: MonitoringSession) {
        monitoringTask?.cancel()
        latestSnapshotValue = nil
        self.session = session
    }

    func setMonitoringTask(_ task: Task<Void, Never>) {
        monitoringTask?.cancel()
        monitoringTask = task
    }

    func updateSessionState(_ state: MonitoringSessionState, startedAt: Date? = nil) {
        guard let current = session else { return }
        session = MonitoringSession(
            window: current.window,
            startedAt: current.startedAt ?? startedAt,
            endedAt: current.endedAt,
            state: state,
            snapshotCount: current.snapshotCount,
            lastSnapshotAt: current.lastSnapshotAt
        )
    }

    func record(_ snapshot: HealthSnapshot) {
        latestSnapshotValue = snapshot
        guard let current = session else { return }
        session = MonitoringSession(
            window: current.window,
            startedAt: current.startedAt ?? snapshot.timestamp,
            endedAt: current.endedAt,
            state: .collecting,
            snapshotCount: current.snapshotCount + 1,
            lastSnapshotAt: snapshot.timestamp
        )
    }

    func finishCurrentSession(at endedAt: Date) {
        monitoringTask?.cancel()
        monitoringTask = nil
        guard let current = session else { return }
        session = MonitoringSession(
            window: current.window,
            startedAt: current.startedAt,
            endedAt: endedAt,
            state: .completed,
            snapshotCount: current.snapshotCount,
            lastSnapshotAt: current.lastSnapshotAt
        )
    }

    func stopCurrentSession(markAs state: MonitoringSessionState) {
        monitoringTask?.cancel()
        monitoringTask = nil
        guard let current = session else { return }
        session = MonitoringSession(
            window: current.window,
            startedAt: current.startedAt,
            endedAt: Date(),
            state: state,
            snapshotCount: current.snapshotCount,
            lastSnapshotAt: current.lastSnapshotAt
        )
    }

    func latestSnapshot() -> HealthSnapshot? {
        latestSnapshotValue
    }

    func currentSession() -> MonitoringSession? {
        session
    }
}

#if canImport(HealthKit)
@available(macOS 13.0, iOS 17.0, watchOS 10.0, *)
private struct QuantityReading {
    let sample: HKQuantitySample
    let value: Double
}

@available(macOS 13.0, iOS 17.0, watchOS 10.0, *)
private struct SampleOrigin {
    let source: SnapshotSource
    let sampleTimestamp: Date?
    let deviceName: String?
    let deviceModel: String?
    let sourceAppName: String?
}

@available(macOS 13.0, iOS 17.0, watchOS 10.0, *)
private struct SampleSourceSummary {
    let source: SnapshotSource
    let sampleTimestamp: Date?
    let deviceName: String?
    let deviceModel: String?
    let sourceAppName: String?
}
#endif
