import Foundation
import Testing
@testable import LanePulse_Coach

struct HeartRatePreprocessorTests {
    @Test func smoothingAndTrend() throws {
        let configuration = HeartRatePreprocessorConfiguration(ewmaAlpha: 0.3, trendWindow: 10)
        let preprocessor = HeartRatePreprocessor(configuration: configuration)
        let start = Date(timeIntervalSince1970: 0)

        let samples = [
            HeartRateInputSample(timestamp: start, bpm: 100, isStale: false),
            HeartRateInputSample(timestamp: start.addingTimeInterval(1), bpm: 110, isStale: false),
            HeartRateInputSample(timestamp: start.addingTimeInterval(2), bpm: 120, isStale: false),
            HeartRateInputSample(timestamp: start.addingTimeInterval(3), bpm: nil, isStale: true)
        ]

        let processed = samples.map { preprocessor.process(sample: $0) }

        #expect(processed[0].smoothedBpm == 100)
        #expect(processed[0].trendPerSecond == nil)

        #expect(processed[1].smoothedBpm?.rounded(toPlaces: 2) == 103.0)
        #expect(processed[1].trendPerSecond?.rounded(toPlaces: 2) == 3.0)

        #expect(processed[2].smoothedBpm?.rounded(toPlaces: 2) == 108.1.rounded(toPlaces: 2))
        #expect(processed[2].trendPerSecond?.rounded(toPlaces: 2) == 4.05.rounded(toPlaces: 2))

        #expect(processed[3].smoothedBpm?.rounded(toPlaces: 2) == processed[2].smoothedBpm?.rounded(toPlaces: 2))
    }
}

struct ActivityStateMachineTests {
    @Test func transitionsWithHysteresisAndRecoverySlope() throws {
        let zoneModel = HeartRateZoneModel(boundaries: [130, 150, 170, 190])
        let configuration = ActivityDetectionConfiguration(
            baselineBpm: 120,
            deltaOn: 12,
            deltaOff: 6,
            minActiveDuration: 8,
            minPauseDuration: 10,
            activeZoneThreshold: 2,
            recoveryTrendThreshold: -0.5,
            recoverySlopeWindow: 60,
            zoneModel: zoneModel
        )

        let machine = ActivityStateMachine(configuration: configuration)
        let start = Date(timeIntervalSince1970: 0)

        func sample(at second: Int, bpm: Double, trend: Double? = nil) -> ProcessedHeartRateSample {
            ProcessedHeartRateSample(
                timestamp: start.addingTimeInterval(TimeInterval(second)),
                rawBpm: bpm,
                smoothedBpm: bpm,
                trendPerSecond: trend,
                isStale: false
            )
        }

        // Initial idle samples.
        let initialSnapshot = machine.process(sample: sample(at: 0, bpm: 100))
        #expect(initialSnapshot.state == .paused)
        #expect(initialSnapshot.zone == 1)

        // Eight seconds in activation range.
        for second in 1...8 {
            let snapshot = machine.process(sample: sample(at: second, bpm: 135))
            if second < 8 {
                #expect(snapshot.state == .paused)
            }
            if second == 8 {
                #expect(snapshot.state == .active)
            }
        }

        // Remain active for a few seconds above threshold.
        for second in 9...12 {
            let snapshot = machine.process(sample: sample(at: second, bpm: 140))
            #expect(snapshot.state == .active)
        }

        // Begin recovery with bpm below hysteresis off threshold.
        for second in 13...22 {
            let snapshot = machine.process(sample: sample(at: second, bpm: 125, trend: -0.6))
            if second < 22 {
                #expect(snapshot.state == .active)
            }
            if second == 22 {
                #expect(snapshot.state == .paused)
                #expect(snapshot.zone == 2)
            }
        }

        // Collect recovery slope samples (first 60 seconds of pause).
        let pausedSamples: [(Int, Double)] = [(23, 120), (24, 118), (25, 116)]
        for (second, bpm) in pausedSamples {
            let snapshot = machine.process(sample: sample(at: second, bpm: bpm))
            #expect(snapshot.state == .paused)
            if second == 25 {
                #expect(snapshot.recoverySlopeBpmPerMinute?.rounded(toPlaces: 1) == -180.0.rounded(toPlaces: 1))
            }
        }
    }
}

struct HeartRateStatisticsCalculatorTests {
    @Test func aggregatesTimeInZoneAndAverages() throws {
        let zoneModel = HeartRateZoneModel(boundaries: [120, 140, 160, 180])
        let calculator = HeartRateStatisticsCalculator(zoneModel: zoneModel)
        let start = Date(timeIntervalSince1970: 0)

        func sample(at second: Int, bpm: Double) -> ProcessedHeartRateSample {
            ProcessedHeartRateSample(
                timestamp: start.addingTimeInterval(TimeInterval(second)),
                rawBpm: bpm,
                smoothedBpm: bpm,
                trendPerSecond: nil,
                isStale: false
            )
        }

        let bpmValues: [Double] = [100, 130, 150, 170, 190]
        for (index, bpm) in bpmValues.enumerated() {
            calculator.ingest(sample: sample(at: index, bpm: bpm))
        }

        let summary = calculator.makeSummary()

        #expect(summary.averageBpm?.rounded(toPlaces: 1) == 148.0)
        #expect(summary.maxBpm == 190)
        #expect(summary.minBpm == 100)
        #expect(summary.totalDuration.rounded() == 5)
        #expect(summary.timeInZones[1]?.rounded() == 1)
        #expect(summary.timeInZones[2]?.rounded() == 1)
        #expect(summary.timeInZones[3]?.rounded() == 1)
        #expect(summary.timeInZones[4]?.rounded() == 1)
        #expect(summary.timeInZones[5]?.rounded() == 1)
    }

    @Test func skipsStaleSamples() throws {
        let zoneModel = HeartRateZoneModel(boundaries: [120, 140, 160, 180])
        let calculator = HeartRateStatisticsCalculator(zoneModel: zoneModel)
        let start = Date(timeIntervalSince1970: 0)

        let validSample = ProcessedHeartRateSample(
            timestamp: start,
            rawBpm: 130,
            smoothedBpm: 130,
            trendPerSecond: nil,
            isStale: false
        )

        let staleSample = ProcessedHeartRateSample(
            timestamp: start.addingTimeInterval(1),
            rawBpm: nil,
            smoothedBpm: nil,
            trendPerSecond: nil,
            isStale: true
        )

        calculator.ingest(sample: validSample)
        calculator.ingest(sample: staleSample)
        let summary = calculator.makeSummary()

        #expect(summary.totalDuration.rounded() == 1)
        #expect(summary.timeInZones[2]?.rounded() == 1)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
