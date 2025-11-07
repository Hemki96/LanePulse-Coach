//
//  PersistenceController.swift
//  LanePulse Coach
//
//  Created to provide CoreData + SQLite stack configuration.
//

import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let managedObjectModel = Self.buildModel()
        container = NSPersistentContainer(name: "LanePulseCoach", managedObjectModel: managedObjectModel)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        } else {
            let storeURL = Self.defaultStoreURL()
            let description = NSPersistentStoreDescription(url: storeURL)
            description.type = NSSQLiteStoreType
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { description, error in
            if let error {
                fatalError("Unresolved error loading store \(description): \(error)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let sessionEntity = NSEntityDescription()
        sessionEntity.name = "SessionRecord"
        sessionEntity.managedObjectClassName = NSStringFromClass(SessionRecord.self)

        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        timestampAttribute.isOptional = false
        timestampAttribute.defaultValue = Date()

        sessionEntity.properties = [timestampAttribute]
        model.entities = [sessionEntity]
        return model
    }

    private static func defaultStoreURL() -> URL {
        let storeName = "LanePulseCoach.sqlite"
#if os(macOS)
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.appendingPathComponent(storeName)
#else
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return url.appendingPathComponent(storeName)
#endif
    }
}

extension PersistenceController {
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        for offset in 0..<5 {
            let record = SessionRecord(context: context)
            record.timestamp = Calendar.current.date(byAdding: .minute, value: -offset * 5, to: Date()) ?? Date()
        }
        try? context.save()
        return controller
    }()
}
