//
//  HeartRateStreamCoordinator.swift
//  LanePulse Coach
//
//  Encapsulates heart-rate resampling and stale detection,
//  emitting updates back to observers via delegation.
//

import Foundation

protocol HeartRateStreamCoordinatorDelegate: AnyObject {
    func heartRateStreamCoordinator(_ coordinator: HeartRateStreamCoordinating,
                                    didEmit sample: ResampledHeartRateSample,
                                    consecutiveStaleCount: Int)
}

protocol HeartRateStreamCoordinating: AnyObject {
    var delegate: HeartRateStreamCoordinatorDelegate? { get set }
    var lastSample: ResampledHeartRateSample? { get }

    func start()
    func stop()
    func reset()
    func handleIncomingSample(_ sample: HeartRateSample)
}

final class HeartRateStreamCoordinator: HeartRateStreamCoordinating {
    weak var delegate: HeartRateStreamCoordinatorDelegate?

    private let resampler: HeartRateResampler
    private(set) var lastSample: ResampledHeartRateSample?
    private var consecutiveStaleEmissions: Int = 0

    init(resampler: HeartRateResampler) {
        self.resampler = resampler
        self.resampler.onResampledSample = { [weak self] sample in
            self?.handleResampledSample(sample)
        }
    }

    convenience init(interval: TimeInterval = 1.0) {
        let resampler = HeartRateResampler(interval: interval)
        self.init(resampler: resampler)
    }

    func start() {
        resampler.start()
    }

    func stop() {
        resampler.stop()
        consecutiveStaleEmissions = 0
    }

    func reset() {
        resampler.reset()
        consecutiveStaleEmissions = 0
        lastSample = nil
    }

    func handleIncomingSample(_ sample: HeartRateSample) {
        resampler.receive(sample)
    }

    private func handleResampledSample(_ sample: ResampledHeartRateSample) {
        lastSample = sample
        if sample.isStale {
            consecutiveStaleEmissions += 1
        } else {
            consecutiveStaleEmissions = 0
        }
        delegate?.heartRateStreamCoordinator(self,
                                             didEmit: sample,
                                             consecutiveStaleCount: consecutiveStaleEmissions)
    }
}
