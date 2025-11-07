//
//  ActivityStateMachine.swift
//  LanePulse Coach
//
//  Created by OpenAI Assistant.
//

import Foundation

enum ActivityState: Equatable {
    case active
    case paused
}

struct HeartRateZoneModel {
    /// Ordered ascending boundaries (upper bpm limits) for zones 1...n-1. The last zone is open ended.
    let boundaries: [Double]

    func zone(for bpm: Double) -> Int {
        for (index, boundary) in boundaries.enumerated() {
            if bpm < boundary {
                return index + 1
            }
        }
        return boundaries.count + 1
    }
}

struct ActivityDetectionConfiguration {
    let baselineBpm: Double
    let deltaOn: Double
    let deltaOff: Double
    let minActiveDuration: TimeInterval
    let minPauseDuration: TimeInterval
    let activeZoneThreshold: Int
    /// Negative slope in **bpm per second** that signals recovery.
    let recoveryTrendThreshold: Double
    let recoverySlopeWindow: TimeInterval
    let zoneModel: HeartRateZoneModel
}

struct ActivityStateSnapshot: Equatable {
    let state: ActivityState
    let zone: Int?
    let recoverySlopeBpmPerMinute: Double?
}

final class ActivityStateMachine {
    private let configuration: ActivityDetectionConfiguration
    private var state: ActivityState = .paused
    private var lastTimestamp: Date?
    private var activeDurationAccumulator: TimeInterval = 0
    private var pauseDurationAccumulator: TimeInterval = 0
    private var recoverySamples: [(Date, Double)] = []
    private var pauseStartTime: Date?

    init(configuration: ActivityDetectionConfiguration) {
        self.configuration = configuration
    }

    func reset() {
        state = .paused
        lastTimestamp = nil
        activeDurationAccumulator = 0
        pauseDurationAccumulator = 0
        recoverySamples.removeAll()
        pauseStartTime = nil
    }

    func process(sample: ProcessedHeartRateSample) -> ActivityStateSnapshot {
        let timestamp = sample.timestamp
        let delta = lastTimestamp.map { timestamp.timeIntervalSince($0) } ?? 0
        lastTimestamp = timestamp
        if state == .paused && pauseStartTime == nil {
            pauseStartTime = timestamp
        }
        let bestBpm = sample.smoothedBpm ?? sample.rawBpm
        let zone = bestBpm.map(configuration.zoneModel.zone(for:))

        var newState = state

        switch state {
        case .paused:
            if meetsActivationCriteria(bpm: bestBpm, zone: zone) {
                activeDurationAccumulator += delta
                pauseDurationAccumulator = 0
            } else {
                activeDurationAccumulator = 0
            }

            if activeDurationAccumulator >= configuration.minActiveDuration {
                newState = .active
            }
        case .active:
            if meetsPauseCriteria(bpm: bestBpm, trend: sample.trendPerSecond) {
                pauseDurationAccumulator += delta
                activeDurationAccumulator = 0
            } else {
                pauseDurationAccumulator = 0
            }

            if pauseDurationAccumulator >= configuration.minPauseDuration {
                newState = .paused
            }
        }

        if newState != state {
            transition(to: newState, at: timestamp, bpm: bestBpm)
        } else {
            handleStateMaintenance(state: newState, timestamp: timestamp, bpm: bestBpm)
        }

        let slope = computeRecoverySlope()
        return ActivityStateSnapshot(state: state, zone: zone, recoverySlopeBpmPerMinute: slope)
    }

    private func meetsActivationCriteria(bpm: Double?, zone: Int?) -> Bool {
        guard let bpm, let zone else { return false }
        let aboveBaseline = bpm >= configuration.baselineBpm + configuration.deltaOn
        let zoneCondition = zone >= configuration.activeZoneThreshold
        return aboveBaseline || zoneCondition
    }

    private func meetsPauseCriteria(bpm: Double?, trend: Double?) -> Bool {
        let bpmCondition: Bool
        if let bpm {
            bpmCondition = bpm <= configuration.baselineBpm + configuration.deltaOff
        } else {
            bpmCondition = false
        }

        let trendCondition: Bool
        if let trend {
            trendCondition = trend <= configuration.recoveryTrendThreshold
        } else {
            trendCondition = false
        }

        return bpmCondition || trendCondition
    }

    private func transition(to newState: ActivityState, at timestamp: Date, bpm: Double?) {
        state = newState
        activeDurationAccumulator = 0
        pauseDurationAccumulator = 0
        pauseStartTime = (newState == .paused) ? timestamp : nil
        recoverySamples.removeAll()
        handleStateMaintenance(state: newState, timestamp: timestamp, bpm: bpm)
    }

    private func handleStateMaintenance(state: ActivityState, timestamp: Date, bpm: Double?) {
        switch state {
        case .active:
            recoverySamples.removeAll()
            pauseStartTime = nil
        case .paused:
            guard let bpm else { return }
            guard let pauseStartTime else { return }
            let elapsed = timestamp.timeIntervalSince(pauseStartTime)
            guard elapsed <= configuration.recoverySlopeWindow else { return }
            recoverySamples.append((timestamp, bpm))
        }
    }

    private func computeRecoverySlope() -> Double? {
        guard state == .paused else {
            return nil
        }

        guard recoverySamples.count >= 2 else { return nil }

        let first = recoverySamples.first!
        let last = recoverySamples.last!
        let duration = last.0.timeIntervalSince(first.0)
        guard duration > 0 else { return nil }

        let slopePerSecond = (last.1 - first.1) / duration
        return slopePerSecond * 60
    }
}
