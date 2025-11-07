//
//  SessionRepository.swift
//  LanePulse Coach
//
//  Created to manage CoreData-backed session persistence.
//

import Foundation
import CoreData

protocol SessionRepositoryProtocol {
    func createSession(at date: Date) throws
    func deleteSessions(_ sessions: [SessionRecord]) throws
    func fetchAllSessions() throws -> [SessionRecord]
}

final class SessionRepository: SessionRepositoryProtocol {
    private let context: NSManagedObjectContext
    private let logger: Logging

    init(context: NSManagedObjectContext, logger: Logging) {
        self.context = context
        self.logger = logger
    }

    func createSession(at date: Date = Date()) throws {
        let record = SessionRecord(context: context)
        record.timestamp = date
        try saveContext()
        logger.log(level: .info, message: "Persisted session at \(date)")
    }

    func deleteSessions(_ sessions: [SessionRecord]) throws {
        sessions.forEach(context.delete)
        try saveContext()
        logger.log(level: .info, message: "Deleted \(sessions.count) sessions")
    }

    func fetchAllSessions() throws -> [SessionRecord] {
        let request: NSFetchRequest<SessionRecord> = SessionRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionRecord.timestamp, ascending: false)]
        return try context.fetch(request)
    }

    private func saveContext() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.log(level: .error, message: "Failed to save context: \(error.localizedDescription)")
            throw error
        }
    }
}
