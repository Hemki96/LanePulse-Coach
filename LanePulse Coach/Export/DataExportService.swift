//
//  DataExportService.swift
//  LanePulse Coach
//
//  Provides CSV/JSON export for recorded data entities.
//

import Foundation

enum DataExportFormat {
    case csv
    case json

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        }
    }

    var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        }
    }
}

protocol DataExporting {
    @discardableResult
    func exportData(format: DataExportFormat) throws -> URL
}

final class DataExportService: DataExporting {
    private let athleteRepository: AthleteRepositoryProtocol
    private let sensorRepository: SensorRepositoryProtocol
    private let mappingRepository: MappingRepositoryProtocol
    private let sessionRepository: SessionRepositoryProtocol
    private let hrSampleRepository: HRSampleRepositoryProtocol
    private let eventRepository: EventRepositoryProtocol
    private let metricConfigRepository: MetricConfigRepositoryProtocol
    private let logger: Logging

    private let dateFormatter: ISO8601DateFormatter
    private let csvExporter: CSVExporter
    private let jsonExporter: JSONExporter

    init(athleteRepository: AthleteRepositoryProtocol,
         sensorRepository: SensorRepositoryProtocol,
         mappingRepository: MappingRepositoryProtocol,
         sessionRepository: SessionRepositoryProtocol,
         hrSampleRepository: HRSampleRepositoryProtocol,
         eventRepository: EventRepositoryProtocol,
         metricConfigRepository: MetricConfigRepositoryProtocol,
         logger: Logging) {
        self.athleteRepository = athleteRepository
        self.sensorRepository = sensorRepository
        self.mappingRepository = mappingRepository
        self.sessionRepository = sessionRepository
        self.hrSampleRepository = hrSampleRepository
        self.eventRepository = eventRepository
        self.metricConfigRepository = metricConfigRepository
        self.logger = logger
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.csvExporter = CSVExporter()
        self.jsonExporter = JSONExporter()
    }

    func exportData(format: DataExportFormat) throws -> URL {
        let snapshot = try buildSnapshot()
        let destinationDirectory = makeDestinationDirectory(for: format)

        switch format {
        case .csv:
            try writeCSV(snapshot: snapshot, to: destinationDirectory)
        case .json:
            try writeJSON(snapshot: snapshot, to: destinationDirectory)
        }

        logger.log(level: .info, message: "Exported data in \(format) format to \(destinationDirectory.path)")
        return destinationDirectory
    }

    private func buildSnapshot() throws -> ExportSnapshot {
        let athletes = try athleteRepository.fetchAll().map(mapAthlete)
        let sensors = try sensorRepository.fetchAll().map(mapSensor)
        let mappings = try mappingRepository.fetchAll().map(mapMapping)
        let sessions = try sessionRepository.fetchAllSessions().map(mapSession)
        let samples = try hrSampleRepository.fetchSamples(sessionId: nil).map(mapSample)
        let events = try eventRepository.fetchAll().map(mapEvent)
        let metricConfigs = try metricConfigRepository.fetchAll().map(mapMetricConfig)

        return ExportSnapshot(athletes: athletes,
                              sensors: sensors,
                              mappings: mappings,
                              sessions: sessions,
                              samples: samples,
                              events: events,
                              metricConfigs: metricConfigs)
    }

    private func writeCSV(snapshot: ExportSnapshot, to directory: URL) throws {
        try write(csvExporter.makeCSV(from: snapshot.athletes), named: "athletes.csv", at: directory)
        try write(csvExporter.makeCSV(from: snapshot.sensors), named: "sensors.csv", at: directory)
        try write(csvExporter.makeCSV(from: snapshot.mappings), named: "mappings.csv", at: directory)
        try write(csvExporter.makeCSV(from: snapshot.sessions), named: "sessions.csv", at: directory)
        try write(csvExporter.makeCSV(from: snapshot.samples), named: "hr_samples.csv", at: directory)
        try write(csvExporter.makeCSV(from: snapshot.events), named: "events.csv", at: directory)
        try write(csvExporter.makeCSV(from: snapshot.metricConfigs), named: "metric_configs.csv", at: directory)
    }

    private func writeJSON(snapshot: ExportSnapshot, to directory: URL) throws {
        let data = try jsonExporter.makeJSON(from: snapshot)
        try write(data, named: "lanepulse_export.json", at: directory)
    }

    private func write(_ string: String, named fileName: String, at directory: URL) throws {
        let url = directory.appendingPathComponent(fileName)
        try string.write(to: url, atomically: true, encoding: .utf8)
    }

    private func write(_ data: Data, named fileName: String, at directory: URL) throws {
        let url = directory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
    }

    private func makeDestinationDirectory(for format: DataExportFormat) -> URL {
        let rawTimestamp = dateFormatter.string(from: Date())
        let safeTimestamp = rawTimestamp
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LanePulseExport-\(safeTimestamp)", isDirectory: true)
        if FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.removeItem(at: directory)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func mapAthlete(_ record: AthleteRecord) -> AthleteExportDTO {
        AthleteExportDTO(id: record.id.uuidString,
                         name: record.name,
                         hfmax: Int(record.hfMax),
                         zoneModel: record.zoneModel,
                         notes: record.notes)
    }

    private func mapSensor(_ record: SensorRecord) -> SensorExportDTO {
        SensorExportDTO(id: record.id.uuidString,
                        vendor: record.vendor,
                        lastSeen: record.lastSeen.map(dateFormatter.string(from:)),
                        firmware: record.firmware,
                        batteryLevel: record.batteryLevel)
    }

    private func mapMapping(_ record: MappingRecord) -> MappingExportDTO {
        MappingExportDTO(id: record.id.uuidString,
                         athleteId: record.athleteId.uuidString,
                         sensorId: record.sensorId.uuidString,
                         since: dateFormatter.string(from: record.since),
                         nickname: record.nickname)
    }

    private func mapSession(_ record: SessionRecord) -> SessionExportDTO {
        SessionExportDTO(id: record.id.uuidString,
                         date: dateFormatter.string(from: record.startDate),
                         laneGroup: record.laneGroup,
                         coachNotes: record.coachNotes)
    }

    private func mapSample(_ record: HRSampleRecord) -> HRSampleExportDTO {
        HRSampleExportDTO(id: record.id.uuidString,
                          sessionId: record.sessionId.uuidString,
                          athleteId: record.athleteId.uuidString,
                          timestamp: dateFormatter.string(from: record.timestamp),
                          hr: Int(record.heartRate))
    }

    private func mapEvent(_ record: EventRecord) -> EventExportDTO {
        EventExportDTO(id: record.id.uuidString,
                       sessionId: record.sessionId.uuidString,
                       athleteId: record.athleteId?.uuidString,
                       type: record.type,
                       start: dateFormatter.string(from: record.start),
                       end: record.end.map(dateFormatter.string(from:)),
                       meta: makeMetadataString(record.metadata))
    }

    private func mapMetricConfig(_ record: MetricConfigRecord) -> MetricConfigExportDTO {
        MetricConfigExportDTO(id: record.id.uuidString,
                              coachProfileId: record.coachProfileId.uuidString,
                              visibleMetrics: record.visibleMetrics,
                              thresholds: record.thresholds)
    }

    private func makeMetadataString(_ data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        if let string = String(data: data, encoding: .utf8), !string.isEmpty {
            return string
        }
        return data.base64EncodedString()
    }
}
