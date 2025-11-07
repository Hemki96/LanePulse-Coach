import Foundation

struct AnalyticsSessionDescriptor: Equatable {
    let sessionId: UUID
    let athleteId: UUID
    let samples: [HeartRateInputSample]

    init(sessionId: UUID = UUID(), athleteId: UUID, samples: [HeartRateInputSample]) {
        self.sessionId = sessionId
        self.athleteId = athleteId
        self.samples = samples
    }
}

struct AnalyticsSummary: Equatable {
    let overall: HeartRateStatistics
    let athleteSummaries: [UUID: HeartRateStatistics]
    let sessionsPerAthlete: [UUID: Int]
}

enum AnalyticsManagerError: Error, Equatable {
    case noSessions
    case emptySamples(sessionId: UUID)
}

final class AnalyticsManager {
    private let zoneModel: HeartRateZoneModel
    private let preprocessorConfiguration: HeartRatePreprocessorConfiguration

    init(zoneModel: HeartRateZoneModel,
         preprocessorConfiguration: HeartRatePreprocessorConfiguration = .default) {
        self.zoneModel = zoneModel
        self.preprocessorConfiguration = preprocessorConfiguration
    }

    func evaluate(sessions: [AnalyticsSessionDescriptor]) throws -> AnalyticsSummary {
        guard !sessions.isEmpty else {
            throw AnalyticsManagerError.noSessions
        }

        var athleteAccumulators: [UUID: StatisticsAccumulator] = [:]
        var sessionsPerAthlete: [UUID: Int] = [:]
        var overallAccumulator = StatisticsAccumulator()

        for session in sessions {
            guard !session.samples.isEmpty else {
                throw AnalyticsManagerError.emptySamples(sessionId: session.sessionId)
            }

            let preprocessor = HeartRatePreprocessor(configuration: preprocessorConfiguration)
            var processed: [ProcessedHeartRateSample] = []
            processed.reserveCapacity(session.samples.count)

            for sample in session.samples {
                processed.append(preprocessor.process(sample: sample))
            }

            let result = makeSessionResult(from: processed)

            var accumulator = athleteAccumulators[session.athleteId] ?? StatisticsAccumulator()
            accumulator.append(result)
            athleteAccumulators[session.athleteId] = accumulator

            overallAccumulator.append(result)
            sessionsPerAthlete[session.athleteId, default: 0] += 1
        }

        let athleteSummaries = Dictionary(uniqueKeysWithValues: athleteAccumulators.map { (key, value) in
            (key, value.makeStatistics())
        })
        let overallSummary = overallAccumulator.makeStatistics()

        return AnalyticsSummary(overall: overallSummary,
                                athleteSummaries: athleteSummaries,
                                sessionsPerAthlete: sessionsPerAthlete)
    }

    private func makeSessionResult(from samples: [ProcessedHeartRateSample]) -> SessionResult {
        let calculator = HeartRateStatisticsCalculator(zoneModel: zoneModel)
        var bpmSum: Double = 0
        var bpmCount = 0

        for sample in samples {
            calculator.ingest(sample: sample)
            if !sample.isStale, let value = sample.smoothedBpm ?? sample.rawBpm {
                bpmSum += value
                bpmCount += 1
            }
        }

        let summary = calculator.makeSummary(finalSampleDuration: Self.finalSampleDuration(from: samples))
        return SessionResult(summary: summary, bpmSum: bpmSum, bpmCount: bpmCount)
    }

    private static func finalSampleDuration(from samples: [ProcessedHeartRateSample]) -> TimeInterval {
        let valid = samples.filter { !$0.isStale }
        guard valid.count >= 2 else {
            return valid.isEmpty ? 0 : 1
        }

        let last = valid[valid.count - 1]
        let previous = valid[valid.count - 2]
        let duration = last.timestamp.timeIntervalSince(previous.timestamp)
        return duration > 0 ? duration : 1
    }
}

private struct SessionResult {
    let summary: HeartRateStatistics
    let bpmSum: Double
    let bpmCount: Int
}

private struct StatisticsAccumulator {
    private var bpmSum: Double = 0
    private var bpmCount: Int = 0
    private var maxBpm: Double?
    private var minBpm: Double?
    private var totalDuration: TimeInterval = 0
    private var zoneDurations: [Int: TimeInterval] = [:]

    mutating func append(_ session: SessionResult) {
        bpmSum += session.bpmSum
        bpmCount += session.bpmCount

        if let sessionMax = session.summary.maxBpm {
            maxBpm = max(maxBpm ?? sessionMax, sessionMax)
        }

        if let sessionMin = session.summary.minBpm {
            minBpm = min(minBpm ?? sessionMin, sessionMin)
        }

        totalDuration += session.summary.totalDuration
        for (zone, duration) in session.summary.timeInZones {
            zoneDurations[zone, default: 0] += duration
        }
    }

    func makeStatistics() -> HeartRateStatistics {
        let average = bpmCount > 0 ? bpmSum / Double(bpmCount) : nil
        return HeartRateStatistics(
            averageBpm: average,
            maxBpm: maxBpm,
            minBpm: minBpm,
            timeInZones: zoneDurations,
            totalDuration: totalDuration
        )
    }
}
