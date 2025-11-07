//
//  PersistenceController.swift
//  LanePulse Coach
//
//  Provides the CoreData + SQLite stack configuration and runtime model.
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

        let athleteEntity = NSEntityDescription()
        athleteEntity.name = "AthleteRecord"
        athleteEntity.managedObjectClassName = NSStringFromClass(AthleteRecord.self)
        athleteEntity.properties = [
            Self.attribute(name: "id", type: .UUIDAttributeType),
            Self.attribute(name: "name", type: .stringAttributeType),
            Self.attribute(name: "hfMax", type: .integer16AttributeType),
            Self.attribute(name: "zoneModel", type: .stringAttributeType, isOptional: true),
            Self.attribute(name: "notes", type: .stringAttributeType, isOptional: true)
        ]

        let sensorEntity = NSEntityDescription()
        sensorEntity.name = "SensorRecord"
        sensorEntity.managedObjectClassName = NSStringFromClass(SensorRecord.self)
        let batteryAttribute = Self.attribute(name: "batteryLevel", type: .doubleAttributeType)
        batteryAttribute.defaultValue = 0.0
        sensorEntity.properties = [
            Self.attribute(name: "id", type: .UUIDAttributeType),
            Self.attribute(name: "vendor", type: .stringAttributeType),
            Self.attribute(name: "lastSeen", type: .dateAttributeType, isOptional: true),
            Self.attribute(name: "firmware", type: .stringAttributeType, isOptional: true),
            batteryAttribute
        ]

        let mappingEntity = NSEntityDescription()
        mappingEntity.name = "MappingRecord"
        mappingEntity.managedObjectClassName = NSStringFromClass(MappingRecord.self)
        mappingEntity.properties = [
            Self.attribute(name: "id", type: .UUIDAttributeType),
            Self.attribute(name: "athleteId", type: .UUIDAttributeType),
            Self.attribute(name: "sensorId", type: .UUIDAttributeType),
            Self.attribute(name: "since", type: .dateAttributeType),
            Self.attribute(name: "nickname", type: .stringAttributeType, isOptional: true)
        ]

        let sessionEntity = NSEntityDescription()
        sessionEntity.name = "SessionRecord"
        sessionEntity.managedObjectClassName = NSStringFromClass(SessionRecord.self)
        sessionEntity.properties = [
            Self.attribute(name: "id", type: .UUIDAttributeType),
            Self.attribute(name: "startDate", type: .dateAttributeType),
            Self.attribute(name: "laneGroup", type: .stringAttributeType, isOptional: true),
            Self.attribute(name: "coachNotes", type: .stringAttributeType, isOptional: true)
        ]

        let hrSampleEntity = NSEntityDescription()
        hrSampleEntity.name = "HRSampleRecord"
        hrSampleEntity.managedObjectClassName = NSStringFromClass(HRSampleRecord.self)
        hrSampleEntity.properties = [
            Self.attribute(name: "id", type: .UUIDAttributeType),
            Self.attribute(name: "sessionId", type: .UUIDAttributeType),
            Self.attribute(name: "athleteId", type: .UUIDAttributeType),
            Self.attribute(name: "timestamp", type: .dateAttributeType),
            Self.attribute(name: "heartRate", type: .integer16AttributeType)
        ]

        let eventEntity = NSEntityDescription()
        eventEntity.name = "EventRecord"
        eventEntity.managedObjectClassName = NSStringFromClass(EventRecord.self)
        let metadataAttribute = Self.attribute(name: "metadata", type: .binaryDataAttributeType, isOptional: true)
        metadataAttribute.allowsExternalBinaryDataStorage = true
        eventEntity.properties = [
            Self.attribute(name: "id", type: .UUIDAttributeType),
            Self.attribute(name: "sessionId", type: .UUIDAttributeType),
            Self.attribute(name: "athleteId", type: .UUIDAttributeType, isOptional: true),
            Self.attribute(name: "type", type: .stringAttributeType),
            Self.attribute(name: "start", type: .dateAttributeType),
            Self.attribute(name: "end", type: .dateAttributeType, isOptional: true),
            metadataAttribute
        ]

        let metricConfigEntity = NSEntityDescription()
        metricConfigEntity.name = "MetricConfigRecord"
        metricConfigEntity.managedObjectClassName = NSStringFromClass(MetricConfigRecord.self)
        let visibleMetricsAttribute = Self.transformableAttribute(name: "visibleMetrics", className: NSStringFromClass(NSArray.self))
        visibleMetricsAttribute.isOptional = false
        let thresholdsAttribute = Self.transformableAttribute(name: "thresholds", className: NSStringFromClass(NSDictionary.self))
        thresholdsAttribute.isOptional = false
        metricConfigEntity.properties = [
            Self.attribute(name: "id", type: .UUIDAttributeType),
            Self.attribute(name: "coachProfileId", type: .UUIDAttributeType),
            visibleMetricsAttribute,
            thresholdsAttribute
        ]

        model.entities = [
            athleteEntity,
            sensorEntity,
            mappingEntity,
            sessionEntity,
            hrSampleEntity,
            eventEntity,
            metricConfigEntity
        ]
        return model
    }

    private static func attribute(name: String, type: NSAttributeType, isOptional: Bool = false) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        attribute.isIndexed = (type == .UUIDAttributeType)
        return attribute
    }

    private static func transformableAttribute(name: String, className: String) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .transformableAttributeType
        attribute.attributeValueClassName = className
        attribute.valueTransformerName = NSValueTransformerName.secureUnarchiveFromDataTransformerName
        return attribute
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
            record.id = UUID()
            record.startDate = Calendar.current.date(byAdding: .minute, value: -offset * 5, to: Date()) ?? Date()
            record.laneGroup = "Lane \(offset + 1)"
            record.coachNotes = "Preview session #\(offset + 1)"
        }
        try? context.save()
        return controller
    }()
}
