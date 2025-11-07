//
//  MappingRecord.swift
//  LanePulse Coach
//
//  CoreData managed object linking athletes to sensors.
//

import Foundation
import CoreData

@objc(MappingRecord)
public final class MappingRecord: NSManagedObject { }

extension MappingRecord: Identifiable { }

extension MappingRecord {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<MappingRecord> {
        NSFetchRequest<MappingRecord>(entityName: "MappingRecord")
    }
}

extension MappingRecord {
    @NSManaged public var id: UUID
    @NSManaged public var athleteId: UUID
    @NSManaged public var sensorId: UUID
    @NSManaged public var since: Date
    @NSManaged public var nickname: String?
}
