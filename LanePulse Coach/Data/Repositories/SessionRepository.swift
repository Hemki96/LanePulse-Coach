//
//  SessionRepository.swift
//  LanePulse Coach
//
//  Manages CoreData-backed session persistence.
//

import Foundation
import CoreData

struct SessionInput {
    let id: UUID
    let startDate: Date
    let laneGroup: String?
    let coachNotes: String?

    init(id: UUID = UUID(),
         startDate: Date = Date(),
         laneGroup: String? = nil,
         coachNotes: String? = nil) {
        self.id = id
        self.startDate = startDate
        self.laneGroup = laneGroup
        self.coachNotes = coachNotes
    }
}

protocol SessionRepositoryProtocol {
    @discardableResult
    func createSession(_ input: SessionInput) throws -> SessionRecord
    func deleteSessions(_ sessions: [SessionRecord]) throws
    func fetchAllSessions() throws -> [SessionRecord]
    func fetchSession(id: UUID) throws -> SessionRecord?
}

final class SessionRepository: SessionRepositoryProtocol {
    private let context: NSManagedObjectContext
    private let logger: Logging

    init(context: NSManagedObjectContext, logger: Logging) {
        self.context = context
        self.logger = logger
    }

    @discardableResult
    func createSession(_ input: SessionInput) throws -> SessionRecord {
        let record = SessionRecord(context: context)
        record.id = input.id
        record.startDate = input.startDate
        record.laneGroup = input.laneGroup
        record.coachNotes = input.coachNotes
        try saveContext()
        logger.log(level: .info, message: "Persisted session \(input.id.uuidString)")
        return record
    }

    func deleteSessions(_ sessions: [SessionRecord]) throws {
        sessions.forEach(context.delete)
        try saveContext()
        logger.log(level: .info, message: "Deleted \(sessions.count) sessions")
    }

    func fetchAllSessions() throws -> [SessionRecord] {
        let request: NSFetchRequest<SessionRecord> = SessionRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionRecord.startDate, ascending: false)]
        return try context.fetch(request)
    }

    func fetchSession(id: UUID) throws -> SessionRecord? {
        let request: NSFetchRequest<SessionRecord> = SessionRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
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
