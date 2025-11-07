//
//  AnalyticsService.swift
//  LanePulse Coach
//
//  Lightweight analytics abstraction for instrumentation.
//

import Foundation

struct AnalyticsEvent {
    let name: String
    let metadata: [String: String]

    init(name: String, metadata: [String: String] = [:]) {
        self.name = name
        self.metadata = metadata
    }
}

protocol AnalyticsServicing {
    func track(event: AnalyticsEvent)
}

final class AnalyticsService: AnalyticsServicing {
    private let logger: Logging

    init(logger: Logging) {
        self.logger = logger
    }

    func track(event: AnalyticsEvent) {
        logger.log(level: .debug, message: "Analytics event: \(event.name)", metadata: event.metadata)
    }
}
