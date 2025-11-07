import XCTest
@testable import LanePulse_Coach

final class HeartRatePreprocessorTests: XCTestCase {
    func testInitialSampleProducesSmoothedValueAndNoTrend() {
        let preprocessor = HeartRatePreprocessor(configuration: .init(ewmaAlpha: 0.5, trendWindow: 10))
        let timestamp = Date(timeIntervalSince1970: 0)
        let sample = HeartRateInputSample(timestamp: timestamp, bpm: 150, isStale: false)

        let processed = preprocessor.process(sample: sample)

        XCTAssertEqual(processed.timestamp, timestamp)
        XCTAssertEqual(processed.rawBpm, 150)
        XCTAssertEqual(processed.smoothedBpm, 150)
        XCTAssertNil(processed.trendPerSecond)
        XCTAssertFalse(processed.isStale)
    }

    func testAppliesExponentialSmoothingAndTrendCalculation() {
        let configuration = HeartRatePreprocessorConfiguration(ewmaAlpha: 0.5, trendWindow: 60)
        let preprocessor = HeartRatePreprocessor(configuration: configuration)
        let base = Date(timeIntervalSince1970: 100)

        _ = preprocessor.process(sample: HeartRateInputSample(timestamp: base, bpm: 100, isStale: false))
        let second = preprocessor.process(sample: HeartRateInputSample(timestamp: base.addingTimeInterval(2), bpm: 120, isStale: false))

        XCTAssertEqual(second.smoothedBpm, 110, accuracy: 0.0001)
        XCTAssertEqual(second.trendPerSecond, 5, accuracy: 0.0001)
    }

    func testNilHeartRatePropagatesPreviousSmoothedValue() {
        let configuration = HeartRatePreprocessorConfiguration(ewmaAlpha: 0.4, trendWindow: 60)
        let preprocessor = HeartRatePreprocessor(configuration: configuration)
        let base = Date(timeIntervalSince1970: 200)

        _ = preprocessor.process(sample: HeartRateInputSample(timestamp: base, bpm: 100, isStale: false))
        let second = preprocessor.process(sample: HeartRateInputSample(timestamp: base.addingTimeInterval(1), bpm: nil, isStale: true))

        XCTAssertEqual(second.smoothedBpm, 100)
        XCTAssertNil(second.trendPerSecond)
        XCTAssertTrue(second.isStale)
    }

    func testResetClearsSmoothingState() {
        let preprocessor = HeartRatePreprocessor(configuration: .init(ewmaAlpha: 0.2, trendWindow: 60))
        let base = Date(timeIntervalSince1970: 300)

        _ = preprocessor.process(sample: HeartRateInputSample(timestamp: base, bpm: 90, isStale: false))
        preprocessor.reset()
        let processed = preprocessor.process(sample: HeartRateInputSample(timestamp: base.addingTimeInterval(5), bpm: 150, isStale: false))

        XCTAssertEqual(processed.smoothedBpm, 150)
        XCTAssertNil(processed.trendPerSecond)
    }

    func testTrendRequiresPositiveElapsedTime() {
        let preprocessor = HeartRatePreprocessor(configuration: .init(ewmaAlpha: 1.0, trendWindow: 60))
        let base = Date(timeIntervalSince1970: 400)

        _ = preprocessor.process(sample: HeartRateInputSample(timestamp: base, bpm: 100, isStale: false))
        let second = preprocessor.process(sample: HeartRateInputSample(timestamp: base, bpm: 110, isStale: false))

        XCTAssertNil(second.trendPerSecond)
    }

    func testHistoryPruningRemovesOutdatedSamples() {
        let configuration = HeartRatePreprocessorConfiguration(ewmaAlpha: 1.0, trendWindow: 5)
        let preprocessor = HeartRatePreprocessor(configuration: configuration)
        let base = Date(timeIntervalSince1970: 500)

        _ = preprocessor.process(sample: HeartRateInputSample(timestamp: base, bpm: 100, isStale: false))
        let second = preprocessor.process(sample: HeartRateInputSample(timestamp: base.addingTimeInterval(10), bpm: 110, isStale: false))
        XCTAssertNil(second.trendPerSecond)

        let third = preprocessor.process(sample: HeartRateInputSample(timestamp: base.addingTimeInterval(11), bpm: 120, isStale: false))
        XCTAssertEqual(third.trendPerSecond, 10, accuracy: 0.0001)
    }
}
