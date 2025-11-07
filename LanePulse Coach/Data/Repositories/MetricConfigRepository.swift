//
//  MetricConfigRepository.swift
//  LanePulse Coach
//
//  Handles CRUD operations for MetricConfigRecord entities.
//

import Foundation
import CoreData

struct MetricConfigInput {
    let id: UUID
    let coachProfileId: UUID
    let visibleMetrics: [String]
    let thresholds: [String: Double]

    init(id: UUID = UUID(),
         coachProfileId: UUID,
         visibleMetrics: [String],
         thresholds: [String: Double] = [:]) {
        self.id = id
        self.coachProfileId = coachProfileId
        self.visibleMetrics = visibleMetrics
        self.thresholds = thresholds
    }
}

protocol MetricConfigRepositoryProtocol {
    @discardableResult
    func upsert(_ input: MetricConfigInput) throws -> MetricConfigRecord
    func fetchConfigs(for coachProfileId: UUID) throws -> [MetricConfigRecord]
    func fetchAll() throws -> [MetricConfigRecord]
}

final class MetricConfigRepository: MetricConfigRepositoryProtocol {
    private let context: NSManagedObjectContext
    private let logger: Logging

    init(context: NSManagedObjectContext, logger: Logging) {
        self.context = context
        self.logger = logger
    }

    @discardableResult
    func upsert(_ input: MetricConfigInput) throws -> MetricConfigRecord {
        let record = try fetchRecord(id: input.id) ?? MetricConfigRecord(context: context)
        record.id = input.id
        record.coachProfileId = input.coachProfileId
        record.visibleMetrics = input.visibleMetrics
        record.thresholds = input.thresholds
        try saveContext()
        logger.log(level: .info, message: "Upserted metric config \(input.id.uuidString)")
        return record
    }

    func fetchConfigs(for coachProfileId: UUID) throws -> [MetricConfigRecord] {
        let request: NSFetchRequest<MetricConfigRecord> = MetricConfigRecord.fetchRequest()
        request.predicate = NSPredicate(format: "coachProfileId == %@", coachProfileId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MetricConfigRecord.id, ascending: true)]
        return try context.fetch(request)
    }

    func fetchAll() throws -> [MetricConfigRecord] {
        let request: NSFetchRequest<MetricConfigRecord> = MetricConfigRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MetricConfigRecord.coachProfileId, ascending: true)]
        return try context.fetch(request)
    }

    private func fetchRecord(id: UUID) throws -> MetricConfigRecord? {
        let request: NSFetchRequest<MetricConfigRecord> = MetricConfigRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func saveContext() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.log(level: .error, message: "Failed to save metric config context: \(error.localizedDescription)")
            throw error
        }
    }
}
