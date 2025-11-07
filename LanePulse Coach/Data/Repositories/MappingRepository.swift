//
//  MappingRepository.swift
//  LanePulse Coach
//
//  Handles CRUD operations for MappingRecord entities.
//

import Foundation
import CoreData

struct MappingInput {
    let id: UUID
    let athleteId: UUID
    let sensorId: UUID
    let since: Date
    let nickname: String?

    init(id: UUID = UUID(),
         athleteId: UUID,
         sensorId: UUID,
         since: Date = Date(),
         nickname: String? = nil) {
        self.id = id
        self.athleteId = athleteId
        self.sensorId = sensorId
        self.since = since
        self.nickname = nickname
    }
}

protocol MappingRepositoryProtocol {
    @discardableResult
    func upsert(_ input: MappingInput) throws -> MappingRecord
    func deleteMappings(_ mappings: [MappingRecord]) throws
    func fetchAll() throws -> [MappingRecord]
}

final class MappingRepository: MappingRepositoryProtocol {
    private let context: NSManagedObjectContext
    private let logger: Logging

    init(context: NSManagedObjectContext, logger: Logging) {
        self.context = context
        self.logger = logger
    }

    @discardableResult
    func upsert(_ input: MappingInput) throws -> MappingRecord {
        let record = try fetchRecord(id: input.id) ?? MappingRecord(context: context)
        record.id = input.id
        record.athleteId = input.athleteId
        record.sensorId = input.sensorId
        record.since = input.since
        record.nickname = input.nickname
        try saveContext()
        logger.log(level: .info, message: "Upserted mapping \(input.id.uuidString)")
        return record
    }

    func deleteMappings(_ mappings: [MappingRecord]) throws {
        mappings.forEach(context.delete)
        try saveContext()
        logger.log(level: .info, message: "Deleted \(mappings.count) mappings")
    }

    func fetchAll() throws -> [MappingRecord] {
        let request: NSFetchRequest<MappingRecord> = MappingRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MappingRecord.since, ascending: false)]
        return try context.fetch(request)
    }

    private func fetchRecord(id: UUID) throws -> MappingRecord? {
        let request: NSFetchRequest<MappingRecord> = MappingRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func saveContext() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.log(level: .error, message: "Failed to save mapping context: \(error.localizedDescription)")
            throw error
        }
    }
}
