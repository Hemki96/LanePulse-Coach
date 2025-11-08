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
                // Attempt recovery instead of crashing on launch.
                // 1) Try to remove the persistent store file and retry once (for SQLite stores).
                // 2) If that fails, fall back to an in-memory store to keep the app usable.
                let url = description.url
                if description.type == NSSQLiteStoreType, let url {
                    // Remove store files (sqlite + -shm/-wal) and retry
                    let fm = FileManager.default
                    let basePath = url.path
                    let shm = URL(fileURLWithPath: basePath + "-shm")
                    let wal = URL(fileURLWithPath: basePath + "-wal")
                    try? fm.removeItem(at: url)
                    try? fm.removeItem(at: shm)
                    try? fm.removeItem(at: wal)

                    let retryDescription = NSPersistentStoreDescription(url: url)
                    retryDescription.type = NSSQLiteStoreType
                    self.container.persistentStoreDescriptions = [retryDescription]

                    var retryError: Error?
                    self.container.loadPersistentStores { _, e in retryError = e }
                    if let retryError {
                        // Fall back to in-memory
                        let memoryDescription = NSPersistentStoreDescription()
                        memoryDescription.type = NSInMemoryStoreType
                        self.container.persistentStoreDescriptions = [memoryDescription]
                        var memError: Error?
                        self.container.loadPersistentStores { _, e in memError = e }
                        if let memError {
                            // As a last resort, log and proceed; the app will have no persistent storage.
                            print("[Persistence] Failed to recover persistent store: \(retryError); fallback failed: \(memError)")
                        } else {
                            print("[Persistence] Recovered by falling back to in-memory store.")
                        }
                    } else {
                        print("[Persistence] Store corruption suspected. Recreated SQLite store.")
                    }
                } else {
                    // Non-SQLite store or no URL: fall back to in-memory.
                    let memoryDescription = NSPersistentStoreDescription()
                    memoryDescription.type = NSInMemoryStoreType
                    self.container.persistentStoreDescriptions = [memoryDescription]
                    var memError: Error?
                    self.container.loadPersistentStores { _, e in memError = e }
                    if let memError {
                        print("[Persistence] Failed to load in-memory store: \(memError)")
                    } else {
                        print("[Persistence] Using in-memory store due to load error: \(error)")
                    }
                }
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
        do {
            guard let idProp = athleteEntity.propertiesByName["id"] else { preconditionFailure("AthleteRecord.id property missing") }
            let idElement = NSFetchIndexElementDescription(property: idProp, collationType: .binary)
            let index = NSFetchIndexDescription(name: "AthleteRecord_id_index", elements: [idElement])
            athleteEntity.indexes = [index]
        }

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
        do {
            guard let idProp = sensorEntity.propertiesByName["id"] else { preconditionFailure("SensorRecord.id property missing") }
            let idElement = NSFetchIndexElementDescription(property: idProp, collationType: .binary)
            let index = NSFetchIndexDescription(name: "SensorRecord_id_index", elements: [idElement])
            sensorEntity.indexes = [index]
        }

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
        do {
            guard let idProp = mappingEntity.propertiesByName["id"],
                  let athleteIdProp = mappingEntity.propertiesByName["athleteId"],
                  let sensorIdProp = mappingEntity.propertiesByName["sensorId"] else { preconditionFailure("MappingRecord index properties missing") }
            let idElement = NSFetchIndexElementDescription(property: idProp, collationType: .binary)
            let athleteIdElement = NSFetchIndexElementDescription(property: athleteIdProp, collationType: .binary)
            let sensorIdElement = NSFetchIndexElementDescription(property: sensorIdProp, collationType: .binary)
            let index = NSFetchIndexDescription(name: "MappingRecord_ids_index", elements: [idElement, athleteIdElement, sensorIdElement])
            mappingEntity.indexes = [index]
        }

        let sessionEntity = NSEntityDescription()
        sessionEntity.name = "SessionRecord"
        sessionEntity.managedObjectClassName = NSStringFromClass(SessionRecord.self)
        sessionEntity.properties = [
            Self.attribute(name: "id", type: .UUIDAttributeType),
            Self.attribute(name: "startDate", type: .dateAttributeType),
            Self.attribute(name: "laneGroup", type: .stringAttributeType, isOptional: true),
            Self.attribute(name: "coachNotes", type: .stringAttributeType, isOptional: true)
        ]
        do {
            guard let idProp = sessionEntity.propertiesByName["id"] else { preconditionFailure("SessionRecord.id property missing") }
            let idElement = NSFetchIndexElementDescription(property: idProp, collationType: .binary)
            let index = NSFetchIndexDescription(name: "SessionRecord_id_index", elements: [idElement])
            sessionEntity.indexes = [index]
        }

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
        do {
            guard let idProp = hrSampleEntity.propertiesByName["id"],
                  let sessionIdProp = hrSampleEntity.propertiesByName["sessionId"],
                  let athleteIdProp = hrSampleEntity.propertiesByName["athleteId"],
                  let timestampProp = hrSampleEntity.propertiesByName["timestamp"] else { preconditionFailure("HRSampleRecord index properties missing") }
            let idElement = NSFetchIndexElementDescription(property: idProp, collationType: .binary)
            let sessionIdElement = NSFetchIndexElementDescription(property: sessionIdProp, collationType: .binary)
            let athleteIdElement = NSFetchIndexElementDescription(property: athleteIdProp, collationType: .binary)
            let timestampElement = NSFetchIndexElementDescription(property: timestampProp, collationType: .binary)
            let index = NSFetchIndexDescription(name: "HRSampleRecord_compound_index", elements: [idElement, sessionIdElement, athleteIdElement, timestampElement])
            hrSampleEntity.indexes = [index]
        }

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
        do {
            guard let idProp = eventEntity.propertiesByName["id"],
                  let sessionIdProp = eventEntity.propertiesByName["sessionId"],
                  let athleteIdProp = eventEntity.propertiesByName["athleteId"],
                  let typeProp = eventEntity.propertiesByName["type"],
                  let startProp = eventEntity.propertiesByName["start"] else { preconditionFailure("EventRecord index properties missing") }
            let idElement = NSFetchIndexElementDescription(property: idProp, collationType: .binary)
            let sessionIdElement = NSFetchIndexElementDescription(property: sessionIdProp, collationType: .binary)
            let athleteIdElement = NSFetchIndexElementDescription(property: athleteIdProp, collationType: .binary)
            let typeElement = NSFetchIndexElementDescription(property: typeProp, collationType: .binary)
            let startElement = NSFetchIndexElementDescription(property: startProp, collationType: .binary)
            let index = NSFetchIndexDescription(name: "EventRecord_compound_index", elements: [idElement, sessionIdElement, athleteIdElement, typeElement, startElement])
            eventEntity.indexes = [index]
        }

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
        do {
            guard let idProp = metricConfigEntity.propertiesByName["id"],
                  let coachProfileIdProp = metricConfigEntity.propertiesByName["coachProfileId"] else { preconditionFailure("MetricConfigRecord index properties missing") }
            let idElement = NSFetchIndexElementDescription(property: idProp, collationType: .binary)
            let coachProfileIdElement = NSFetchIndexElementDescription(property: coachProfileIdProp, collationType: .binary)
            let index = NSFetchIndexDescription(name: "MetricConfigRecord_ids_index", elements: [idElement, coachProfileIdElement])
            metricConfigEntity.indexes = [index]
        }

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
        return attribute
    }

    private static func transformableAttribute(name: String, className: String) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .transformableAttributeType
        attribute.attributeValueClassName = className
        attribute.valueTransformerName = NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue
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
            record.setValue(UUID(), forKey: "id")
            record.setValue(Calendar.current.date(byAdding: .minute, value: -offset * 5, to: Date()) ?? Date(), forKey: "startDate")
            record.setValue("Lane \(offset + 1)", forKey: "laneGroup")
            record.setValue("Preview session #\(offset + 1)", forKey: "coachNotes")
        }
        try? context.save()
        return controller
    }()
}

