//
//  EventRepository.swift
//  LanePulse Coach
//
//  Handles CRUD operations for EventRecord entities.
//

import Foundation
import CoreData

struct EventInput {
    let id: UUID
    let sessionId: UUID
    let athleteId: UUID?
    let type: String
    let start: Date
    let end: Date?
    let metadata: Data?

    init(id: UUID = UUID(),
         sessionId: UUID,
         athleteId: UUID? = nil,
         type: String,
         start: Date,
         end: Date? = nil,
         metadata: Data? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.athleteId = athleteId
        self.type = type
        self.start = start
        self.end = end
        self.metadata = metadata
    }
}

protocol EventRepositoryProtocol {
    @discardableResult
    func upsert(_ input: EventInput) throws -> EventRecord
    func deleteEvents(_ events: [EventRecord]) throws
    func fetchEvents(sessionId: UUID) throws -> [EventRecord]
    func fetchAll() throws -> [EventRecord]
}

final class EventRepository: EventRepositoryProtocol {
    private let context: NSManagedObjectContext
    private let logger: Logging

    init(context: NSManagedObjectContext, logger: Logging) {
        self.context = context
        self.logger = logger
    }

    @discardableResult
    func upsert(_ input: EventInput) throws -> EventRecord {
        let record = try fetchRecord(id: input.id) ?? EventRecord(context: context)
        record.id = input.id
        record.sessionId = input.sessionId
        record.athleteId = input.athleteId
        record.type = input.type
        record.start = input.start
        record.end = input.end
        record.metadata = input.metadata
        try saveContext()
        logger.log(level: .info, message: "Upserted event \(input.id.uuidString)")
        return record
    }

    func deleteEvents(_ events: [EventRecord]) throws {
        events.forEach(context.delete)
        try saveContext()
        logger.log(level: .info, message: "Deleted \(events.count) events")
    }

    func fetchEvents(sessionId: UUID) throws -> [EventRecord] {
        let request: NSFetchRequest<EventRecord> = EventRecord.fetchRequest()
        request.predicate = NSPredicate(format: "sessionId == %@", sessionId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EventRecord.start, ascending: true)]
        return try context.fetch(request)
    }

    func fetchAll() throws -> [EventRecord] {
        let request: NSFetchRequest<EventRecord> = EventRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EventRecord.start, ascending: true)]
        return try context.fetch(request)
    }

    private func fetchRecord(id: UUID) throws -> EventRecord? {
        let request: NSFetchRequest<EventRecord> = EventRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func saveContext() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.log(level: .error, message: "Failed to save event context: \(error.localizedDescription)")
            throw error
        }
    }
}
