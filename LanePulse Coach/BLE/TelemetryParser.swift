import Foundation

struct TelemetryPacket: Equatable {
    let deviceId: UUID
    let timestamp: Date
    let heartRate: Double
    let isStale: Bool
    let metadata: [String: String]
}

enum TelemetryParserError: Error, Equatable {
    case invalidJSON
    case missingField(String)
    case invalidBLEPayload
}

final class TelemetryParser {
    private let dateFormatter: ISO8601DateFormatter

    init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.dateFormatter = formatter
    }

    func parse(json data: Data) throws -> [TelemetryPacket] {
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])

        if let array = jsonObject as? [[String: Any]] {
            return try array.map(parseDictionary)
        } else if let single = jsonObject as? [String: Any] {
            return [try parseDictionary(single)]
        } else {
            throw TelemetryParserError.invalidJSON
        }
    }

    func parseBLE(payload: Data) throws -> TelemetryPacket {
        guard let string = String(data: payload, encoding: .utf8) else {
            throw TelemetryParserError.invalidBLEPayload
        }

        let components = string.split(separator: ",", omittingEmptySubsequences: false)
        guard components.count >= 4 else {
            throw TelemetryParserError.invalidBLEPayload
        }

        guard let deviceId = UUID(uuidString: String(components[0])) else {
            throw TelemetryParserError.invalidBLEPayload
        }

        guard let timestampValue = TimeInterval(String(components[1])) else {
            throw TelemetryParserError.invalidBLEPayload
        }
        let timestamp = Date(timeIntervalSince1970: timestampValue)

        guard let heartRate = Double(String(components[2])) else {
            throw TelemetryParserError.invalidBLEPayload
        }

        let staleComponent = String(components[3]).lowercased()
        let isStale = staleComponent == "1" || staleComponent == "true"

        var metadata: [String: String] = [:]
        if components.count > 4 {
            for pair in components[4...] {
                let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                if kv.count == 2 { metadata[kv[0]] = kv[1] }
            }
        }

        return TelemetryPacket(deviceId: deviceId,
                               timestamp: timestamp,
                               heartRate: heartRate,
                               isStale: isStale,
                               metadata: metadata)
    }

    private func parseDictionary(_ dictionary: [String: Any]) throws -> TelemetryPacket {
        guard let deviceIdString = dictionary["deviceId"] as? String,
              let deviceId = UUID(uuidString: deviceIdString) else {
            throw TelemetryParserError.missingField("deviceId")
        }

        guard let timestampString = dictionary["timestamp"] as? String,
              let timestamp = dateFormatter.date(from: timestampString) else {
            throw TelemetryParserError.missingField("timestamp")
        }

        guard let heartRate = dictionary["heartRate"] as? Double ??
                (dictionary["heartRate"] as? NSNumber)?.doubleValue else {
            throw TelemetryParserError.missingField("heartRate")
        }

        let isStale = dictionary["isStale"] as? Bool ?? false
        let metadata = dictionary["metadata"] as? [String: String] ?? [:]

        return TelemetryPacket(deviceId: deviceId,
                               timestamp: timestamp,
                               heartRate: heartRate,
                               isStale: isStale,
                               metadata: metadata)
    }
}
