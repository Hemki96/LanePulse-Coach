//
//  ExportModels.swift
//  LanePulse Coach
//
//  Transfer models for CSV/JSON export pipelines.
//

import Foundation

struct AthleteExportDTO: Codable, CSVConvertible {
    static let csvHeaders = ["id", "name", "hfmax", "zoneModel", "notes"]

    let id: String
    let name: String
    let hfmax: Int
    let zoneModel: String?
    let notes: String?

    var csvRow: [String: String] {
        [
            "id": id,
            "name": name,
            "hfmax": String(hfmax),
            "zoneModel": zoneModel ?? "",
            "notes": notes ?? ""
        ]
    }
}

struct SensorExportDTO: Codable, CSVConvertible {
    static let csvHeaders = ["id", "vendor", "lastSeen", "firmware", "batteryLevel"]

    let id: String
    let vendor: String
    let lastSeen: String?
    let firmware: String?
    let batteryLevel: Double

    var csvRow: [String: String] {
        [
            "id": id,
            "vendor": vendor,
            "lastSeen": lastSeen ?? "",
            "firmware": firmware ?? "",
            "batteryLevel": String(format: "%.2f", batteryLevel)
        ]
    }
}

struct MappingExportDTO: Codable, CSVConvertible {
    static let csvHeaders = ["id", "athleteId", "sensorId", "since", "nickname"]

    let id: String
    let athleteId: String
    let sensorId: String
    let since: String
    let nickname: String?

    var csvRow: [String: String] {
        [
            "id": id,
            "athleteId": athleteId,
            "sensorId": sensorId,
            "since": since,
            "nickname": nickname ?? ""
        ]
    }
}

struct SessionExportDTO: Codable, CSVConvertible {
    static let csvHeaders = ["id", "date", "laneGroup", "coachNotes"]

    let id: String
    let date: String
    let laneGroup: String?
    let coachNotes: String?

    var csvRow: [String: String] {
        [
            "id": id,
            "date": date,
            "laneGroup": laneGroup ?? "",
            "coachNotes": coachNotes ?? ""
        ]
    }
}

struct HRSampleExportDTO: Codable, CSVConvertible {
    static let csvHeaders = ["id", "sessionId", "athleteId", "timestamp", "hr"]

    let id: String
    let sessionId: String
    let athleteId: String
    let timestamp: String
    let hr: Int

    var csvRow: [String: String] {
        [
            "id": id,
            "sessionId": sessionId,
            "athleteId": athleteId,
            "timestamp": timestamp,
            "hr": String(hr)
        ]
    }
}

struct EventExportDTO: Codable, CSVConvertible {
    static let csvHeaders = ["id", "sessionId", "athleteId", "type", "start", "end", "meta"]

    let id: String
    let sessionId: String
    let athleteId: String?
    let type: String
    let start: String
    let end: String?
    let meta: String?

    var csvRow: [String: String] {
        [
            "id": id,
            "sessionId": sessionId,
            "athleteId": athleteId ?? "",
            "type": type,
            "start": start,
            "end": end ?? "",
            "meta": meta ?? ""
        ]
    }
}

struct MetricConfigExportDTO: Codable, CSVConvertible {
    static let csvHeaders = ["id", "coachProfileId", "visibleMetrics", "thresholds"]

    let id: String
    let coachProfileId: String
    let visibleMetrics: [String]
    let thresholds: [String: Double]

    var csvRow: [String: String] {
        [
            "id": id,
            "coachProfileId": coachProfileId,
            "visibleMetrics": visibleMetrics.jsonString,
            "thresholds": thresholds.jsonString
        ]
    }
}

struct ExportSnapshot: Codable {
    let athletes: [AthleteExportDTO]
    let sensors: [SensorExportDTO]
    let mappings: [MappingExportDTO]
    let sessions: [SessionExportDTO]
    let samples: [HRSampleExportDTO]
    let events: [EventExportDTO]
    let metricConfigs: [MetricConfigExportDTO]
}

private extension Array where Element == String {
    var jsonString: String {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: []) else {
            return "[]"
        }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

private extension Dictionary where Key == String, Value == Double {
    var jsonString: String {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: []) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
