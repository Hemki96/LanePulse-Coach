//
//  HeartRateResampler.swift
//  LanePulse Coach
//
//  Resamples irregular heart-rate updates to a steady 1 Hz cadence
//  and marks stale output when samples are missing.
//

import Foundation

struct HeartRateSample {
    let timestamp: Date
    let bpm: Int
    let isStale: Bool
}

struct ResampledHeartRateSample: Equatable {
    let timestamp: Date
    let bpm: Double?
    let isStale: Bool
}

final class HeartRateResampler {
    private let interval: TimeInterval
    private let queue = DispatchQueue(label: "com.lanepulse.coach.hresampler")
    private var timer: DispatchSourceTimer?
    private var bucket: [HeartRateSample] = []
    private var lastKnownBpm: Double?
    private var consecutiveEmptyEmissions: Int = 0
    private var lastEmissionDate: Date?

    var onResampledSample: ((ResampledHeartRateSample) -> Void)?

    init(interval: TimeInterval = 1.0) {
        self.interval = interval
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.timer?.cancel()
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + self.interval, repeating: self.interval)
            timer.setEventHandler { [weak self] in
                self?.emitSample()
            }
            timer.resume()
            self.timer = timer
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.timer?.cancel()
            self.timer = nil
            self.bucket.removeAll()
            self.consecutiveEmptyEmissions = 0
            self.lastKnownBpm = nil
            self.lastEmissionDate = nil
        }
    }

    func reset() {
        queue.async { [weak self] in
            guard let self else { return }
            self.bucket.removeAll()
            self.consecutiveEmptyEmissions = 0
            self.lastEmissionDate = nil
        }
    }

    func receive(_ sample: HeartRateSample) {
        queue.async { [weak self] in
            guard let self else { return }
            self.bucket.append(sample)
            self.consecutiveEmptyEmissions = 0
            self.lastEmissionDate = sample.timestamp
        }
    }

    private func emitSample() {
        let timestamp = Date()
        let output: ResampledHeartRateSample

        if !bucket.isEmpty {
            let samples = bucket
            bucket.removeAll()
            let values = samples.map { Double($0.bpm) }
            let average = values.reduce(0, +) / Double(values.count)
            let stale = samples.allSatisfy { $0.isStale }
            lastKnownBpm = average
            consecutiveEmptyEmissions = 0
            output = ResampledHeartRateSample(timestamp: timestamp, bpm: average, isStale: stale)
        } else {
            consecutiveEmptyEmissions += 1
            let stale = consecutiveEmptyEmissions > 0
            output = ResampledHeartRateSample(timestamp: timestamp, bpm: lastKnownBpm, isStale: stale)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onResampledSample?(output)
        }
    }
}

