//
//  HeartRateStatistics.swift
//  LanePulse Coach
//
//  Created by OpenAI Assistant.
//

import Foundation

struct HeartRateStatistics: Equatable {
    let averageBpm: Double?
    let maxBpm: Double?
    let minBpm: Double?
    /// Seconds spent in each zone (zone index → seconds).
    let timeInZones: [Int: TimeInterval]
    let totalDuration: TimeInterval
}

final class HeartRateStatisticsCalculator {
    private let zoneModel: HeartRateZoneModel
    private var zoneDurations: [Int: TimeInterval] = [:]
    private var totalDuration: TimeInterval = 0
    private var sumBpm: Double = 0
    private var countBpm: Int = 0
    private var maxBpm: Double?
    private var minBpm: Double?
    private var lastTimestamp: Date?
    private var lastZone: Int?

    init(zoneModel: HeartRateZoneModel) {
        self.zoneModel = zoneModel
    }

    func reset() {
        zoneDurations.removeAll()
        totalDuration = 0
        sumBpm = 0
        countBpm = 0
        maxBpm = nil
        minBpm = nil
        lastTimestamp = nil
        lastZone = nil
    }

    func ingest(sample: ProcessedHeartRateSample) {
        guard !sample.isStale else {
            lastTimestamp = sample.timestamp
            lastZone = nil
            return
        }

        guard let bpm = sample.smoothedBpm ?? sample.rawBpm else {
            lastTimestamp = sample.timestamp
            lastZone = nil
            return
        }

        if let lastTimestamp, let lastZone {
            let delta = sample.timestamp.timeIntervalSince(lastTimestamp)
            if delta > 0 {
                zoneDurations[lastZone, default: 0] += delta
                totalDuration += delta
            }
        }

        let zone = zoneModel.zone(for: bpm)
        sumBpm += bpm
        countBpm += 1
        maxBpm = max(maxBpm ?? bpm, bpm)
        minBpm = min(minBpm ?? bpm, bpm)
        lastTimestamp = sample.timestamp
        lastZone = zone
    }

    func makeSummary(finalSampleDuration: TimeInterval = 1) -> HeartRateStatistics {
        var durations = zoneDurations
        var total = totalDuration
        if let lastZone = lastZone, finalSampleDuration > 0 {
            durations[lastZone, default: 0] += finalSampleDuration
            total += finalSampleDuration
        }

        let average = countBpm > 0 ? sumBpm / Double(countBpm) : nil
        return HeartRateStatistics(
            averageBpm: average,
            maxBpm: maxBpm,
            minBpm: minBpm,
            timeInZones: durations,
            totalDuration: total
        )
    }
}
