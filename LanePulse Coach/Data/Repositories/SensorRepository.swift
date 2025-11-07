//
//  SensorRepository.swift
//  LanePulse Coach
//
//  Handles CRUD operations for SensorRecord entities.
//

import Foundation
import CoreData

struct SensorInput {
    let id: UUID
    let vendor: String
    let lastSeen: Date?
    let firmware: String?
    let batteryLevel: Double

    init(id: UUID,
         vendor: String,
         lastSeen: Date? = nil,
         firmware: String? = nil,
         batteryLevel: Double = 0.0) {
        self.id = id
        self.vendor = vendor
        self.lastSeen = lastSeen
        self.firmware = firmware
        self.batteryLevel = batteryLevel
    }
}

protocol SensorRepositoryProtocol {
    @discardableResult
    func upsert(_ input: SensorInput) throws -> SensorRecord
    func fetchAll() throws -> [SensorRecord]
}

final class SensorRepository: SensorRepositoryProtocol {
    private let context: NSManagedObjectContext
    private let logger: Logging

    init(context: NSManagedObjectContext, logger: Logging) {
        self.context = context
        self.logger = logger
    }

    @discardableResult
    func upsert(_ input: SensorInput) throws -> SensorRecord {
        let record = try fetchRecord(id: input.id) ?? SensorRecord(context: context)
        record.id = input.id
        record.vendor = input.vendor
        record.lastSeen = input.lastSeen
        record.firmware = input.firmware
        record.batteryLevel = input.batteryLevel
        try saveContext()
        logger.log(level: .info, message: "Upserted sensor \(input.id.uuidString)")
        return record
    }

    func fetchAll() throws -> [SensorRecord] {
        let request: NSFetchRequest<SensorRecord> = SensorRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SensorRecord.vendor, ascending: true)]
        return try context.fetch(request)
    }

    private func fetchRecord(id: UUID) throws -> SensorRecord? {
        let request: NSFetchRequest<SensorRecord> = SensorRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func saveContext() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.log(level: .error, message: "Failed to save sensor context: \(error.localizedDescription)")
            throw error
        }
    }
}
