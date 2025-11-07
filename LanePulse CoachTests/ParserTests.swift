import XCTest
@testable import LanePulse_Coach

final class ParserTests: XCTestCase {
    func testTelemetryParserDecodesJSONArray() throws {
        let parser = TelemetryParser()
        let json = """
        [
          {
            \"deviceId\": \"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA\",
            \"timestamp\": \"2024-03-20T10:15:30.000Z\",
            \"heartRate\": 142,
            \"metadata\": {\"signal\": \"excellent\"}
          },
          {
            \"deviceId\": \"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB\",
            \"timestamp\": \"2024-03-20T10:15:31.500Z\",
            \"heartRate\": 137,
            \"isStale\": true
          }
        ]
        """.data(using: .utf8)!

        let packets = try parser.parse(json: json)
        XCTAssertEqual(packets.count, 2)
        XCTAssertEqual(packets[0].metadata["signal"], "excellent")
        XCTAssertEqual(packets[1].isStale, true)
        XCTAssertEqual(packets[0].heartRate, 142)
        XCTAssertEqual(packets[1].heartRate, 137)
    }

    func testTelemetryParserBLEPayload() throws {
        let parser = TelemetryParser()
        let deviceId = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        let timestamp = Date(timeIntervalSince1970: 1_708_500_000).timeIntervalSince1970
        let payload = "\(deviceId),\(timestamp),134,false,signal=weak,quality=2".data(using: .utf8)!

        let packet = try parser.parseBLE(payload: payload)
        XCTAssertEqual(packet.deviceId.uuidString, deviceId)
        XCTAssertFalse(packet.isStale)
        XCTAssertEqual(packet.metadata["signal"], "weak")
        XCTAssertEqual(packet.metadata["quality"], "2")
    }

    func testTelemetryParserThrowsForMalformedPayload() {
        let parser = TelemetryParser()
        let payload = "invalid-payload".data(using: .utf8)!

        XCTAssertThrowsError(try parser.parseBLE(payload: payload)) { error in
            XCTAssertEqual(error as? TelemetryParserError, .invalidBLEPayload)
        }
    }

    func testSessionParserParsesJSON() throws {
        let parser = SessionParser()
        let json = """
        {
          \"id\": \"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA\",
          \"startDate\": \"2024-03-20T10:00:00Z\",
          \"endDate\": \"2024-03-20T11:00:00Z\",
          \"laneGroup\": \"A\",
          \"athleteIds\": [\"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB\"],
          \"coachNotes\": \"Focus on turn speed.\"
        }
        """.data(using: .utf8)!

        let metadata = try parser.parse(json: json)
        XCTAssertEqual(metadata.laneGroup, "A")
        XCTAssertEqual(metadata.athleteIds.count, 1)
        XCTAssertEqual(metadata.coachNotes, "Focus on turn speed.")
    }

    func testSessionParserStreamsPartialJSON() throws {
        let parser = SessionParser()
        let segments = [
            "{\"id\":\"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA\",\"startDate\":\"2024-03-20T10:00:00Z\",".data(using: .utf8)!,
            "\"athleteIds\":[\"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB\"],".data(using: .utf8)!,
            "\"endDate\":\"2024-03-20T10:30:00Z\",\"coachNotes\":\"Relax shoulders\"}".data(using: .utf8)!
        ]

        var result: SessionMetadata?
        for segment in segments {
            if let metadata = try parser.append(jsonChunk: segment) {
                result = metadata
            }
        }

        XCTAssertNotNil(result)
        try parser.finalizeStream()
    }

    func testSessionParserDetectsIncompleteStream() throws {
        let parser = SessionParser()
        let chunk = "{\"id\":\"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA\"".data(using: .utf8)!
        XCTAssertNil(try parser.append(jsonChunk: chunk))
        XCTAssertThrowsError(try parser.finalizeStream()) { error in
            XCTAssertEqual(error as? SessionParserError, .incompleteStream)
        }
    }

    func testSessionParserValidatesRequiredFields() throws {
        let parser = SessionParser()
        let json = """
        {
          \"id\": \"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA\",
          \"startDate\": \"2024-03-20T10:00:00Z\",
          \"athleteIds\": []
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try parser.parse(json: json)) { error in
            XCTAssertEqual(error as? SessionParserError, .missingField("athleteIds"))
        }
    }
}
