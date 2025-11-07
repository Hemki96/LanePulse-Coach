//
//  LatencyMonitor.swift
//  LanePulse Coach
//
//  Provides latency tracking for streamed telemetry and optional
//  CI reporting hooks.
//

import Foundation

struct LatencyThresholds: Codable, Equatable {
    let warning: TimeInterval
    let critical: TimeInterval

    static let `default` = LatencyThresholds(warning: 2.0, critical: 5.0)
}

struct LatencySample: Codable, Equatable {
    let streamId: UUID
    let label: String
    let latency: TimeInterval
    let sampleTimestamp: Date
    let recordedAt: Date

    var latencyMilliseconds: Int {
        Int((latency * 1000).rounded())
    }
}

struct LatencyReport: Codable, Equatable {
    let generatedAt: Date
    let thresholds: LatencyThresholds
    let samples: [LatencySample]
}

protocol LatencyMonitoring {
    func recordLatency(streamId: UUID, label: String, sampleTimestamp: Date, latency: TimeInterval)
}

final class LatencyMonitor: LatencyMonitoring {
    private let analytics: AnalyticsServicing
    private let logger: Logging
    private let thresholds: LatencyThresholds
    private let reportURL: URL?
    private let queue = DispatchQueue(label: "com.lanepulse.coach.latency-monitor")

    private var latestSamples: [UUID: LatencySample] = [:]

    init(analytics: AnalyticsServicing,
         logger: Logging,
         thresholds: LatencyThresholds = .default,
         reportURL: URL? = nil) {
        self.analytics = analytics
        self.logger = logger
        self.thresholds = thresholds
        self.reportURL = reportURL
    }

    func recordLatency(streamId: UUID, label: String, sampleTimestamp: Date, latency: TimeInterval) {
        queue.async { [weak self] in
            guard let self else { return }
            let sample = LatencySample(streamId: streamId,
                                       label: label,
                                       latency: latency,
                                       sampleTimestamp: sampleTimestamp,
                                       recordedAt: Date())
            self.latestSamples[streamId] = sample
            self.emitAnalytics(for: sample)
            self.persistReportLocked()
        }
    }

    private func emitAnalytics(for sample: LatencySample) {
        let latencyString = String(sample.latencyMilliseconds)
        analytics.track(event: AnalyticsEvent(name: "latency_observed",
                                              metadata: [
                                                  "stream_id": sample.streamId.uuidString,
                                                  "label": sample.label,
                                                  "latency_ms": latencyString
                                              ]))

        switch sample.latency {
        case let value where value >= thresholds.critical:
            analytics.track(event: AnalyticsEvent(name: "latency_critical",
                                                  metadata: [
                                                      "stream_id": sample.streamId.uuidString,
                                                      "latency_ms": latencyString
                                                  ]))
            logger.log(level: .error,
                       message: "Latency critical for \(sample.label)",
                       metadata: ["latency_ms": latencyString])
        case let value where value >= thresholds.warning:
            analytics.track(event: AnalyticsEvent(name: "latency_warning",
                                                  metadata: [
                                                      "stream_id": sample.streamId.uuidString,
                                                      "latency_ms": latencyString
                                                  ]))
            logger.log(level: .warning,
                       message: "Latency warning for \(sample.label)",
                       metadata: ["latency_ms": latencyString])
        default:
            break
        }
    }

    private func persistReportLocked() {
        guard let reportURL else { return }
        let samples = Array(latestSamples.values).sorted(by: { $0.label < $1.label })
        let report = LatencyReport(generatedAt: Date(), thresholds: thresholds, samples: samples)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)
            try data.write(to: reportURL, options: [.atomic])
        } catch {
            logger.log(level: .error,
                       message: "Failed to persist latency report",
                       metadata: ["error": error.localizedDescription])
        }
    }
}
