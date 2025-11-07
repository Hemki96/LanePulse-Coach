//
//  DataExportService.swift
//  LanePulse Coach
//
//  Provides simple CSV export for recorded sessions.
//

import Foundation

protocol DataExporting {
    @discardableResult
    func exportSessions() throws -> URL
}

final class DataExportService: DataExporting {
    private let repository: SessionRepositoryProtocol
    private let logger: Logging
    private let dateFormatter: ISO8601DateFormatter

    init(repository: SessionRepositoryProtocol, logger: Logging) {
        self.repository = repository
        self.logger = logger
        self.dateFormatter = ISO8601DateFormatter()
    }

    func exportSessions() throws -> URL {
        let sessions = try repository.fetchAllSessions()
        guard !sessions.isEmpty else {
            throw AppError.dataUnavailable
        }

        var rows = ["timestamp"]
        rows.append(contentsOf: sessions.map { dateFormatter.string(from: $0.timestamp) })
        let payload = rows.joined(separator: "\n")

        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("LanePulseSessions.csv")
        do {
            try payload.write(to: destinationURL, atomically: true, encoding: .utf8)
            logger.log(level: .info, message: "Exported \(sessions.count) sessions to \(destinationURL.path)")
            return destinationURL
        } catch {
            logger.log(level: .error, message: "Failed to export sessions: \(error.localizedDescription)")
            throw AppError.exportFailed(reason: error.localizedDescription)
        }
    }
}
