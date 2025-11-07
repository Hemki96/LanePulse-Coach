//
//  AthleteRepository.swift
//  LanePulse Coach
//
//  Handles CRUD operations for AthleteRecord entities.
//

import Foundation
import CoreData

struct AthleteInput {
    let id: UUID
    let name: String
    let hfMax: Int
    let zoneModel: String?
    let notes: String?

    init(id: UUID = UUID(),
         name: String,
         hfMax: Int,
         zoneModel: String? = nil,
         notes: String? = nil) {
        self.id = id
        self.name = name
        self.hfMax = hfMax
        self.zoneModel = zoneModel
        self.notes = notes
    }
}

protocol AthleteRepositoryProtocol {
    @discardableResult
    func upsert(_ input: AthleteInput) throws -> AthleteRecord
    func fetchAll() throws -> [AthleteRecord]
}

final class AthleteRepository: AthleteRepositoryProtocol {
    private let context: NSManagedObjectContext
    private let logger: Logging

    init(context: NSManagedObjectContext, logger: Logging) {
        self.context = context
        self.logger = logger
    }

    @discardableResult
    func upsert(_ input: AthleteInput) throws -> AthleteRecord {
        let record = try fetchRecord(id: input.id) ?? AthleteRecord(context: context)
        record.id = input.id
        record.name = input.name
        record.hfMax = Int16(input.hfMax)
        record.zoneModel = input.zoneModel
        record.notes = input.notes
        try saveContext()
        logger.log(level: .info, message: "Upserted athlete \(input.id.uuidString)")
        return record
    }

    func fetchAll() throws -> [AthleteRecord] {
        let request: NSFetchRequest<AthleteRecord> = AthleteRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AthleteRecord.name, ascending: true)]
        return try context.fetch(request)
    }

    private func fetchRecord(id: UUID) throws -> AthleteRecord? {
        let request: NSFetchRequest<AthleteRecord> = AthleteRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func saveContext() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.log(level: .error, message: "Failed to save athlete context: \(error.localizedDescription)")
            throw error
        }
    }
}
