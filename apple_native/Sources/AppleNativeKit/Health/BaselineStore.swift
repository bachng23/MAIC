import Foundation

public actor BaselineStore {
    private let minimumSampleCount: Int
    private let rollingWindowDays: Int
    private let staleAfterDays: Int
    private var samples: [BaselineSample]
    private var cachedBaseline: PersonalBaseline?

    public init(
        minimumSampleCount: Int = 72,
        rollingWindowDays: Int = 14,
        staleAfterDays: Int = 2,
        samples: [BaselineSample] = []
    ) {
        self.minimumSampleCount = minimumSampleCount
        self.rollingWindowDays = rollingWindowDays
        self.staleAfterDays = staleAfterDays
        self.samples = samples.sorted { $0.snapshot.timestamp < $1.snapshot.timestamp }
        self.cachedBaseline = nil
    }

    public func append(_ sample: BaselineSample) {
        samples.append(sample)
        samples.sort { $0.snapshot.timestamp < $1.snapshot.timestamp }
        cachedBaseline = nil
    }

    public func append(contentsOf newSamples: [BaselineSample]) {
        guard !newSamples.isEmpty else { return }
        samples.append(contentsOf: newSamples)
        samples.sort { $0.snapshot.timestamp < $1.snapshot.timestamp }
        cachedBaseline = nil
    }

    public func allSamples() -> [BaselineSample] {
        samples
    }

    public func filteredSamplesForBaseline() -> [BaselineSample] {
        let recentSamples = rollingWindowSamples()
        return recentSamples.filter {
            !$0.isMedicationPeriod &&
            !$0.isAnomalous &&
            !$0.isIllnessPeriod &&
            !$0.isHighActivity &&
            $0.snapshot.activityState != .workout
        }
    }

    public func currentBaseline() -> PersonalBaseline {
        if let cachedBaseline {
            return cachedBaseline
        }

        let baseline = computeBaseline(from: filteredSamplesForBaseline())
        cachedBaseline = baseline
        return baseline
    }

    public func appendMonitoringSample(
        _ snapshot: HealthSnapshot,
        isMedicationPeriod: Bool,
        isAnomalous: Bool = false,
        isIllnessPeriod: Bool = false,
        isHighActivity: Bool? = nil,
        dayPeriod: DayPeriod
    ) {
        let resolvedHighActivity = isHighActivity ?? (snapshot.activityState == .workout)
        append(
            BaselineSample(
                snapshot: snapshot,
                isMedicationPeriod: isMedicationPeriod,
                isAnomalous: isAnomalous,
                isIllnessPeriod: isIllnessPeriod,
                isHighActivity: resolvedHighActivity,
                dayPeriod: dayPeriod
            )
        )
    }

    private func computeBaseline(from samples: [BaselineSample]) -> PersonalBaseline {
        let sortedSamples = samples.sorted { $0.snapshot.timestamp < $1.snapshot.timestamp }
        let timestamps = sortedSamples.map(\.snapshot.timestamp)
        let heartRateValues = sortedSamples.compactMap(\.snapshot.heartRate)
        let hrvValues = sortedSamples.compactMap(\.snapshot.hrv)
        let spo2Values = sortedSamples.compactMap(\.snapshot.spo2)

        let daytimeHeartRates = sortedSamples
            .filter { $0.dayPeriod == .daytime }
            .compactMap(\.snapshot.heartRate)
        let nighttimeHeartRates = sortedSamples
            .filter { $0.dayPeriod == .nighttime }
            .compactMap(\.snapshot.heartRate)

        let sampleCount = sortedSamples.count
        let status = baselineStatus(for: sortedSamples, sampleCount: sampleCount)

        return PersonalBaseline(
            generatedAt: Date(),
            observationStart: timestamps.first ?? Date(),
            observationEnd: timestamps.last ?? Date(),
            sampleCount: sampleCount,
            status: status,
            heartRate: summarize(values: heartRateValues),
            hrv: summarize(values: hrvValues),
            spo2: summarize(values: spo2Values),
            daytimeHeartRate: summarize(values: daytimeHeartRates),
            nighttimeHeartRate: summarize(values: nighttimeHeartRates)
        )
    }

    private func rollingWindowSamples(asOf date: Date = Date()) -> [BaselineSample] {
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -rollingWindowDays, to: date) else {
            return samples
        }

        return samples.filter { $0.snapshot.timestamp >= cutoffDate }
    }

    private func baselineStatus(
        for samples: [BaselineSample],
        sampleCount: Int
    ) -> BaselineComputationStatus {
        guard sampleCount >= minimumSampleCount else {
            return .insufficientData
        }

        guard
            let latestDate = samples.last?.snapshot.timestamp,
            let staleCutoff = Calendar.current.date(byAdding: .day, value: -staleAfterDays, to: Date())
        else {
            return .ready
        }

        return latestDate < staleCutoff ? .stale : .ready
    }

    private func summarize(values: [Double]) -> HealthSignalBaseline? {
        guard !values.isEmpty else { return nil }

        let sortedValues = values.sorted()
        let minValue = sortedValues[0]
        let maxValue = sortedValues[sortedValues.count - 1]
        let averageValue = sortedValues.reduce(0, +) / Double(sortedValues.count)
        let medianValue: Double

        if sortedValues.count.isMultiple(of: 2) {
            let upperIndex = sortedValues.count / 2
            medianValue = (sortedValues[upperIndex - 1] + sortedValues[upperIndex]) / 2
        } else {
            medianValue = sortedValues[sortedValues.count / 2]
        }

        return HealthSignalBaseline(
            min: minValue,
            max: maxValue,
            average: averageValue,
            median: medianValue
        )
    }
}
