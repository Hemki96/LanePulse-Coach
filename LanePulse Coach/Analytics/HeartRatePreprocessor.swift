//
//  HeartRatePreprocessor.swift
//  LanePulse Coach
//
//  Created by OpenAI Assistant.
//

import Foundation

/// Represents the resampled heart-rate input used by the analytics layer.
struct HeartRateInputSample: Equatable {
    let timestamp: Date
    let bpm: Double?
    let isStale: Bool
}

/// The enriched output of the preprocessing pipeline.
struct ProcessedHeartRateSample: Equatable {
    let timestamp: Date
    let rawBpm: Double?
    let smoothedBpm: Double?
    /// Trend expressed in **bpm per second**.
    let trendPerSecond: Double?
    let isStale: Bool
}

struct HeartRatePreprocessorConfiguration {
    let ewmaAlpha: Double
    let trendWindow: TimeInterval

    static let `default` = HeartRatePreprocessorConfiguration(ewmaAlpha: 0.3, trendWindow: 10)
}

/// Applies EWMA smoothing and trend calculation on streaming HR samples.
final class HeartRatePreprocessor {
    private let configuration: HeartRatePreprocessorConfiguration
    private var lastSmoothedValue: Double?
    private var history: [(timestamp: Date, value: Double)] = []

    init(configuration: HeartRatePreprocessorConfiguration = .default) {
        self.configuration = configuration
    }

    func reset() {
        lastSmoothedValue = nil
        history.removeAll()
    }

    func process(sample: HeartRateInputSample) -> ProcessedHeartRateSample {
        let smoothedValue = computeSmoothedValue(for: sample)
        let trend = computeTrend(currentTimestamp: sample.timestamp)

        return ProcessedHeartRateSample(
            timestamp: sample.timestamp,
            rawBpm: sample.bpm,
            smoothedBpm: smoothedValue,
            trendPerSecond: trend,
            isStale: sample.isStale
        )
    }

    private func computeSmoothedValue(for sample: HeartRateInputSample) -> Double? {
        defer {
            pruneHistory(olderThan: sample.timestamp.addingTimeInterval(-configuration.trendWindow))
        }

        guard let bpm = sample.bpm else {
            return lastSmoothedValue
        }

        let alpha = configuration.ewmaAlpha
        let smoothed: Double

        if let last = lastSmoothedValue {
            smoothed = alpha * bpm + (1 - alpha) * last
        } else {
            smoothed = bpm
        }

        lastSmoothedValue = smoothed
        history.append((timestamp: sample.timestamp, value: smoothed))
        return smoothed
    }

    private func pruneHistory(olderThan limit: Date) {
        history.removeAll { $0.timestamp < limit }
    }

    private func computeTrend(currentTimestamp: Date) -> Double? {
        guard history.count >= 2 else { return nil }

        let oldest = history.first!
        let newest = history.last!
        let deltaTime = newest.timestamp.timeIntervalSince(oldest.timestamp)

        guard deltaTime > 0 else { return nil }

        let deltaValue = newest.value - oldest.value
        return deltaValue / deltaTime
    }
}
