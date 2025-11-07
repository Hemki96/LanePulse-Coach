import XCTest
@testable import LanePulse_Coach

final class AnalyticsManagerTests: XCTestCase {
    private let zoneModel = HeartRateZoneModel(boundaries: [120, 150, 180])

    func testAggregatesKPIsAcrossAthletesAndSessions() throws {
        let manager = AnalyticsManager(zoneModel: zoneModel,
                                       preprocessorConfiguration: HeartRatePreprocessorConfiguration(ewmaAlpha: 1, trendWindow: 5))
        let base = Date(timeIntervalSince1970: 0)
        let athleteA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let athleteB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

        let session1 = AnalyticsSessionDescriptor(
            sessionId: UUID(),
            athleteId: athleteA,
            samples: [
                makeSample(at: base, bpm: 130),
                makeSample(at: base.addingTimeInterval(1), bpm: 150),
                makeSample(at: base.addingTimeInterval(2), bpm: 155)
            ]
        )

        let session2 = AnalyticsSessionDescriptor(
            sessionId: UUID(),
            athleteId: athleteA,
            samples: [
                makeSample(at: base.addingTimeInterval(10), bpm: 140),
                makeSample(at: base.addingTimeInterval(11), bpm: nil, stale: true),
                makeSample(at: base.addingTimeInterval(12), bpm: 170),
                makeSample(at: base.addingTimeInterval(13), bpm: 175)
            ]
        )

        let session3 = AnalyticsSessionDescriptor(
            sessionId: UUID(),
            athleteId: athleteB,
            samples: [
                makeSample(at: base.addingTimeInterval(5), bpm: 100),
                makeSample(at: base.addingTimeInterval(6), bpm: 110),
                makeSample(at: base.addingTimeInterval(7), bpm: 120)
            ]
        )

        let summary = try manager.evaluate(sessions: [session1, session2, session3])

        XCTAssertEqual(summary.sessionsPerAthlete[athleteA], 2)
        XCTAssertEqual(summary.sessionsPerAthlete[athleteB], 1)

        let athleteAStats = try XCTUnwrap(summary.athleteSummaries[athleteA])
        XCTAssertEqual(round(athleteAStats.averageBpm ?? 0), 153)
        XCTAssertEqual(athleteAStats.maxBpm, 175)
        XCTAssertEqual(athleteAStats.minBpm, 130)
        XCTAssertEqual(athleteAStats.totalDuration, 5, accuracy: 0.0001)
        XCTAssertEqual(athleteAStats.timeInZones[2], 1, accuracy: 0.0001)
        XCTAssertEqual(athleteAStats.timeInZones[3], 4, accuracy: 0.0001)

        let athleteBStats = try XCTUnwrap(summary.athleteSummaries[athleteB])
        XCTAssertEqual(athleteBStats.averageBpm, 110)
        XCTAssertEqual(athleteBStats.maxBpm, 120)
        XCTAssertEqual(athleteBStats.minBpm, 100)
        XCTAssertEqual(athleteBStats.totalDuration, 3, accuracy: 0.0001)
        XCTAssertEqual(athleteBStats.timeInZones[1], 2, accuracy: 0.0001)
        XCTAssertEqual(athleteBStats.timeInZones[2], 1, accuracy: 0.0001)

        XCTAssertEqual(round((summary.overall.averageBpm ?? 0) * 100) / 100, 138.89, accuracy: 0.01)
        XCTAssertEqual(summary.overall.maxBpm, 175)
        XCTAssertEqual(summary.overall.minBpm, 100)
        XCTAssertEqual(summary.overall.totalDuration, 8, accuracy: 0.0001)
        XCTAssertEqual(summary.overall.timeInZones[1], 2, accuracy: 0.0001)
        XCTAssertEqual(summary.overall.timeInZones[2], 2, accuracy: 0.0001)
        XCTAssertEqual(summary.overall.timeInZones[3], 4, accuracy: 0.0001)
    }

    func testThrowsForEmptySessions() {
        let manager = AnalyticsManager(zoneModel: zoneModel)
        XCTAssertThrowsError(try manager.evaluate(sessions: [])) { error in
            XCTAssertEqual(error as? AnalyticsManagerError, .noSessions)
        }
    }

    func testThrowsForSessionWithoutSamples() {
        let manager = AnalyticsManager(zoneModel: zoneModel)
        let descriptor = AnalyticsSessionDescriptor(athleteId: UUID(), samples: [])

        XCTAssertThrowsError(try manager.evaluate(sessions: [descriptor])) { error in
            switch error as? AnalyticsManagerError {
            case .emptySamples(let sessionId):
                XCTAssertEqual(sessionId, descriptor.sessionId)
            default:
                XCTFail("Unexpected error: \(String(describing: error))")
            }
        }
    }

    private func makeSample(at date: Date, bpm: Double?, stale: Bool = false) -> HeartRateInputSample {
        HeartRateInputSample(timestamp: date, bpm: bpm, isStale: stale)
    }
}
