import XCTest
@testable import LanePulse_Coach

final class LatencyMonitorTests: XCTestCase {
    func testRecordsLatencyBelowWarningThreshold() {
        let analytics = MockAnalyticsService()
        let logger = MockLogger()
        let eventsExpectation = expectation(description: "analytics events")
        eventsExpectation.expectedFulfillmentCount = 1
        analytics.expectation = eventsExpectation

        let monitor = LatencyMonitor(analytics: analytics,
                                     logger: logger,
                                     thresholds: LatencyThresholds(warning: 2, critical: 4),
                                     reportURL: nil)

        let streamId = UUID()
        monitor.recordLatency(streamId: streamId,
                               label: "Warmup",
                               sampleTimestamp: Date(timeIntervalSince1970: 100),
                               latency: 0.5)

        wait(for: [eventsExpectation], timeout: 1)

        XCTAssertEqual(analytics.events.map(\.name), ["latency_observed"])
        XCTAssertTrue(logger.entries.isEmpty)
    }

    func testEmitsWarningWhenLatencyExceedsWarningThreshold() {
        let analytics = MockAnalyticsService()
        let analyticsExpectation = expectation(description: "analytics warning")
        analyticsExpectation.expectedFulfillmentCount = 2
        analytics.expectation = analyticsExpectation

        let logger = MockLogger()
        let logExpectation = expectation(description: "warning log")
        logger.expectation = logExpectation

        let monitor = LatencyMonitor(analytics: analytics,
                                     logger: logger,
                                     thresholds: LatencyThresholds(warning: 0.5, critical: 5),
                                     reportURL: nil)

        monitor.recordLatency(streamId: UUID(),
                               label: "Main",
                               sampleTimestamp: Date(),
                               latency: 0.75)

        wait(for: [analyticsExpectation, logExpectation], timeout: 1)

        XCTAssertEqual(analytics.events.map(\.name), ["latency_observed", "latency_warning"])
        XCTAssertEqual(logger.entries.count, 1)
        XCTAssertEqual(logger.entries.first?.level, .warning)
    }

    func testEmitsCriticalWhenLatencyExceedsCriticalThreshold() {
        let analytics = MockAnalyticsService()
        let analyticsExpectation = expectation(description: "analytics critical")
        analyticsExpectation.expectedFulfillmentCount = 2
        analytics.expectation = analyticsExpectation

        let logger = MockLogger()
        let logExpectation = expectation(description: "critical log")
        logger.expectation = logExpectation

        let monitor = LatencyMonitor(analytics: analytics,
                                     logger: logger,
                                     thresholds: LatencyThresholds(warning: 0.5, critical: 1.0),
                                     reportURL: nil)

        monitor.recordLatency(streamId: UUID(),
                               label: "Stream",
                               sampleTimestamp: Date(),
                               latency: 1.5)

        wait(for: [analyticsExpectation, logExpectation], timeout: 1)

        XCTAssertEqual(analytics.events.map(\.name), ["latency_observed", "latency_critical"])
        XCTAssertEqual(logger.entries.first?.level, .error)
    }

    func testPersistsReportWithLatestSamplesSortedByLabel() throws {
        let analytics = MockAnalyticsService()
        let analyticsExpectation = expectation(description: "analytics persistence")
        analyticsExpectation.expectedFulfillmentCount = 2
        analytics.expectation = analyticsExpectation

        let logger = MockLogger()

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("latency-report-\(UUID().uuidString).json")

        let monitor = LatencyMonitor(analytics: analytics,
                                     logger: logger,
                                     thresholds: LatencyThresholds(warning: 1, critical: 2),
                                     reportURL: tempURL)

        let base = Date(timeIntervalSince1970: 500)
        monitor.recordLatency(streamId: UUID(),
                               label: "Beta",
                               sampleTimestamp: base,
                               latency: 0.4)
        monitor.recordLatency(streamId: UUID(),
                               label: "Alpha",
                               sampleTimestamp: base.addingTimeInterval(1),
                               latency: 0.8)

        wait(for: [analyticsExpectation], timeout: 1)

        let data = try Data(contentsOf: tempURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(LatencyReport.self, from: data)

        XCTAssertEqual(report.samples.map { $0.label }, ["Alpha", "Beta"])
        XCTAssertTrue(logger.entries.isEmpty)

        try? FileManager.default.removeItem(at: tempURL)
    }

    func testLogsErrorWhenPersistingReportFails() {
        let analytics = MockAnalyticsService()
        let analyticsExpectation = expectation(description: "analytics failure")
        analyticsExpectation.expectedFulfillmentCount = 1
        analytics.expectation = analyticsExpectation

        let logger = MockLogger()
        let logExpectation = expectation(description: "error log")
        logger.expectation = logExpectation

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("latency-dir-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let monitor = LatencyMonitor(analytics: analytics,
                                     logger: logger,
                                     thresholds: .default,
                                     reportURL: directoryURL)

        monitor.recordLatency(streamId: UUID(),
                               label: "Err",
                               sampleTimestamp: Date(),
                               latency: 0.1)

        wait(for: [analyticsExpectation, logExpectation], timeout: 1)

        XCTAssertEqual(logger.entries.first?.level, .error)

        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private final class MockAnalyticsService: AnalyticsServicing {
    private let lock = NSLock()
    private(set) var events: [AnalyticsEvent] = []
    var expectation: XCTestExpectation?

    func track(event: AnalyticsEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
        expectation?.fulfill()
    }
}

private final class MockLogger: Logging {
    struct Entry {
        let level: LogLevel
        let message: String
        let metadata: [String: String]?
    }

    private let lock = NSLock()
    private(set) var entries: [Entry] = []
    var expectation: XCTestExpectation?

    func log(level: LogLevel, message: String, metadata: [String: String]?) {
        lock.lock()
        entries.append(Entry(level: level, message: message, metadata: metadata))
        lock.unlock()
        expectation?.fulfill()
    }
}
