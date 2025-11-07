//
//  DataExportService.swift
//  LanePulse Coach
//
//  Provides CSV/JSON export for recorded data entities.
//

import Foundation
import CoreData

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

struct DataExportProgress: Equatable {
    enum Stage: String {
        case preparing
        case athletes
        case sensors
        case mappings
        case sessions
        case samples
        case events
        case metricConfigs
        case finalizing
        case completed

        var displayName: String {
            switch self {
            case .preparing: return "Vorbereitung"
            case .athletes: return "Athleten"
            case .sensors: return "Sensoren"
            case .mappings: return "Mappings"
            case .sessions: return "Sessions"
            case .samples: return "Herzfrequenzdaten"
            case .events: return "Events"
            case .metricConfigs: return "Metrik-Konfigurationen"
            case .finalizing: return "Abschließen"
            case .completed: return "Fertig"
            }
        }
    }

    let stage: Stage
    let processedItems: Int
    let totalItems: Int

    var fractionCompleted: Double {
        guard totalItems > 0 else {
            return stage == .completed ? 1.0 : 0.0
        }
        return min(1.0, Double(processedItems) / Double(totalItems))
    }
}

protocol DataExporting {
    @discardableResult
    func export(format: DataExportFormat,
                progress: ((DataExportProgress) -> Void)?,
                completion: ((Result<URL, Error>) -> Void)?) async throws -> URL
}

final class DataExportService: DataExporting {
    private let logger: Logging
    private let exportContext: NSManagedObjectContext

    private let dateFormatter: ISO8601DateFormatter
    private let csvExporter: CSVExporter
    private let jsonExporter: JSONExporter

    private enum Constants {
        static let batchSize: Int = 500
    }

    init(athleteRepository _: AthleteRepositoryProtocol,
         sensorRepository _: SensorRepositoryProtocol,
         mappingRepository _: MappingRepositoryProtocol,
         sessionRepository _: SessionRepositoryProtocol,
         hrSampleRepository _: HRSampleRepositoryProtocol,
         eventRepository _: EventRepositoryProtocol,
         metricConfigRepository _: MetricConfigRepositoryProtocol,
         exportContext: NSManagedObjectContext,
         logger: Logging) {
        self.logger = logger
        self.exportContext = exportContext
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.csvExporter = CSVExporter()
        self.jsonExporter = JSONExporter()
    }

    func export(format: DataExportFormat,
                progress progressHandler: ((DataExportProgress) -> Void)? = nil,
                completion completionHandler: ((Result<URL, Error>) -> Void)? = nil) async throws -> URL {
        let destinationDirectory = makeDestinationDirectory(for: format)
        report(progress: DataExportProgress(stage: .preparing, processedItems: 0, totalItems: 0), handler: progressHandler)

        do {
            switch format {
            case .csv:
                try await exportContext.perform {
                    try self.writeCSV(to: destinationDirectory, progress: progressHandler)
                }
            case .json:
                try await exportContext.perform {
                    try self.writeJSON(to: destinationDirectory, progress: progressHandler)
                }
            }

            report(progress: DataExportProgress(stage: .finalizing, processedItems: 0, totalItems: 0), handler: progressHandler)
            report(progress: DataExportProgress(stage: .completed, processedItems: 1, totalItems: 1), handler: progressHandler)
            report(completion: .success(destinationDirectory), handler: completionHandler)
            logger.log(level: .info, message: "Exported data in \(format) format to \(destinationDirectory.path)")
            return destinationDirectory
        } catch {
            report(completion: .failure(error), handler: completionHandler)
            logger.log(level: .error, message: "Export failed: \(error.localizedDescription)")
            throw error
        }
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

    private func writeCSV(to directory: URL, progress progressHandler: ((DataExportProgress) -> Void)?) throws {
        do {
            var writer = try csvExporter.makeWriter(for: AthleteExportDTO.self, url: directory.appendingPathComponent("athletes.csv"))
            defer { try? writer.finish() }
            try stream(stage: .athletes,
                       request: makeFetchRequest(AthleteRecord.self, sort: [NSSortDescriptor(keyPath: \AthleteRecord.name, ascending: true)]),
                       transform: mapAthlete,
                       progress: progressHandler) { values in
                try writer.append(contentsOf: values)
            }
        }

        do {
            var writer = try csvExporter.makeWriter(for: SensorExportDTO.self, url: directory.appendingPathComponent("sensors.csv"))
            defer { try? writer.finish() }
            try stream(stage: .sensors,
                       request: makeFetchRequest(SensorRecord.self, sort: [NSSortDescriptor(keyPath: \SensorRecord.vendor, ascending: true)]),
                       transform: mapSensor,
                       progress: progressHandler) { values in
                try writer.append(contentsOf: values)
            }
        }

        do {
            var writer = try csvExporter.makeWriter(for: MappingExportDTO.self, url: directory.appendingPathComponent("mappings.csv"))
            defer { try? writer.finish() }
            try stream(stage: .mappings,
                       request: makeFetchRequest(MappingRecord.self, sort: [NSSortDescriptor(keyPath: \MappingRecord.since, ascending: true)]),
                       transform: mapMapping,
                       progress: progressHandler) { values in
                try writer.append(contentsOf: values)
            }
        }

        do {
            var writer = try csvExporter.makeWriter(for: SessionExportDTO.self, url: directory.appendingPathComponent("sessions.csv"))
            defer { try? writer.finish() }
            try stream(stage: .sessions,
                       request: makeFetchRequest(SessionRecord.self, sort: [NSSortDescriptor(keyPath: \SessionRecord.startDate, ascending: true)]),
                       transform: mapSession,
                       progress: progressHandler) { values in
                try writer.append(contentsOf: values)
            }
        }

        do {
            var writer = try csvExporter.makeWriter(for: HRSampleExportDTO.self, url: directory.appendingPathComponent("hr_samples.csv"))
            defer { try? writer.finish() }
            try stream(stage: .samples,
                       request: makeFetchRequest(HRSampleRecord.self, sort: [NSSortDescriptor(keyPath: \HRSampleRecord.timestamp, ascending: true)]),
                       transform: mapSample,
                       progress: progressHandler) { values in
                try writer.append(contentsOf: values)
            }
        }

        do {
            var writer = try csvExporter.makeWriter(for: EventExportDTO.self, url: directory.appendingPathComponent("events.csv"))
            defer { try? writer.finish() }
            try stream(stage: .events,
                       request: makeFetchRequest(EventRecord.self, sort: [NSSortDescriptor(keyPath: \EventRecord.start, ascending: true)]),
                       transform: mapEvent,
                       progress: progressHandler) { values in
                try writer.append(contentsOf: values)
            }
        }

        do {
            var writer = try csvExporter.makeWriter(for: MetricConfigExportDTO.self, url: directory.appendingPathComponent("metric_configs.csv"))
            defer { try? writer.finish() }
            try stream(stage: .metricConfigs,
                       request: makeFetchRequest(MetricConfigRecord.self, sort: [NSSortDescriptor(keyPath: \MetricConfigRecord.coachProfileId, ascending: true)]),
                       transform: mapMetricConfig,
                       progress: progressHandler) { values in
                try writer.append(contentsOf: values)
            }
        }
    }

    private func writeJSON(to directory: URL, progress progressHandler: ((DataExportProgress) -> Void)?) throws {
        let url = directory.appendingPathComponent("lanepulse_export.json")
        var writer = try jsonExporter.makeWriter(url: url)
        defer { try? writer.finish() }

        try writer.writeArray(key: "athletes") { array in
            try self.stream(stage: .athletes,
                            request: self.makeFetchRequest(AthleteRecord.self, sort: [NSSortDescriptor(keyPath: \AthleteRecord.name, ascending: true)]),
                            transform: self.mapAthlete,
                            progress: progressHandler) { values in
                try array.append(contentsOf: values)
            }
        }

        try writer.writeArray(key: "sensors") { array in
            try self.stream(stage: .sensors,
                            request: self.makeFetchRequest(SensorRecord.self, sort: [NSSortDescriptor(keyPath: \SensorRecord.vendor, ascending: true)]),
                            transform: self.mapSensor,
                            progress: progressHandler) { values in
                try array.append(contentsOf: values)
            }
        }

        try writer.writeArray(key: "mappings") { array in
            try self.stream(stage: .mappings,
                            request: self.makeFetchRequest(MappingRecord.self, sort: [NSSortDescriptor(keyPath: \MappingRecord.since, ascending: true)]),
                            transform: self.mapMapping,
                            progress: progressHandler) { values in
                try array.append(contentsOf: values)
            }
        }

        try writer.writeArray(key: "sessions") { array in
            try self.stream(stage: .sessions,
                            request: self.makeFetchRequest(SessionRecord.self, sort: [NSSortDescriptor(keyPath: \SessionRecord.startDate, ascending: true)]),
                            transform: self.mapSession,
                            progress: progressHandler) { values in
                try array.append(contentsOf: values)
            }
        }

        try writer.writeArray(key: "samples") { array in
            try self.stream(stage: .samples,
                            request: self.makeFetchRequest(HRSampleRecord.self, sort: [NSSortDescriptor(keyPath: \HRSampleRecord.timestamp, ascending: true)]),
                            transform: self.mapSample,
                            progress: progressHandler) { values in
                try array.append(contentsOf: values)
            }
        }

        try writer.writeArray(key: "events") { array in
            try self.stream(stage: .events,
                            request: self.makeFetchRequest(EventRecord.self, sort: [NSSortDescriptor(keyPath: \EventRecord.start, ascending: true)]),
                            transform: self.mapEvent,
                            progress: progressHandler) { values in
                try array.append(contentsOf: values)
            }
        }

        try writer.writeArray(key: "metricConfigs") { array in
            try self.stream(stage: .metricConfigs,
                            request: self.makeFetchRequest(MetricConfigRecord.self, sort: [NSSortDescriptor(keyPath: \MetricConfigRecord.coachProfileId, ascending: true)]),
                            transform: self.mapMetricConfig,
                            progress: progressHandler) { values in
                try array.append(contentsOf: values)
            }
        }
    }

    private func writeCSV<T: CSVConvertible>(_ values: [T], fileName: String, directory: URL) throws {
        let url = directory.appendingPathComponent(fileName)
        var writer = try csvExporter.makeWriter(for: T.self, url: url)
        try writer.append(contentsOf: values)
        try writer.finish()
    }

    private func stream<Record: NSManagedObject, DTO: Encodable>(stage: DataExportProgress.Stage,
                                                                 request: NSFetchRequest<Record>,
                                                                 transform: (Record) -> DTO,
                                                                 progress progressHandler: ((DataExportProgress) -> Void)?,
                                                                 consume: ([DTO]) throws -> Void) throws {
        let total = try exportContext.count(for: request)
        report(progress: DataExportProgress(stage: stage, processedItems: 0, totalItems: total), handler: progressHandler)
        guard total > 0 else { return }

        var processed = 0
        while true {
            request.fetchOffset = processed
            request.fetchLimit = Constants.batchSize
            let records = try exportContext.fetch(request)
            if records.isEmpty { break }
            let mapped = records.map(transform)
            try consume(mapped)
            processed += records.count
            report(progress: DataExportProgress(stage: stage, processedItems: processed, totalItems: total), handler: progressHandler)
            records.forEach { exportContext.refresh($0, mergeChanges: false) }
        }
    }

    private func makeFetchRequest<T: NSManagedObject>(_ type: T.Type, sort: [NSSortDescriptor]) -> NSFetchRequest<T> {
        let request = T.fetchRequest() as! NSFetchRequest<T>
        request.sortDescriptors = sort
        request.fetchBatchSize = Constants.batchSize
        request.returnsObjectsAsFaults = false
        return request
    }

    private func report(progress: DataExportProgress, handler: ((DataExportProgress) -> Void)?) {
        guard let handler else { return }
        DispatchQueue.main.async {
            handler(progress)
        }
    }

    private func report(completion: Result<URL, Error>, handler: ((Result<URL, Error>) -> Void)?) {
        guard let handler else { return }
        DispatchQueue.main.async {
            handler(completion)
        }
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
