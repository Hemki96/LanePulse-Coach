//
//  SensorRecord.swift
//  LanePulse Coach
//
//  CoreData managed object describing a heart-rate sensor.
//

import Foundation
import CoreData

@objc(SensorRecord)
public final class SensorRecord: NSManagedObject { }

extension SensorRecord: Identifiable { }

extension SensorRecord {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<SensorRecord> {
        NSFetchRequest<SensorRecord>(entityName: "SensorRecord")
    }
}

extension SensorRecord {
    @NSManaged public var id: UUID
    @NSManaged public var vendor: String
    @NSManaged public var lastSeen: Date?
    @NSManaged public var firmware: String?
    @NSManaged public var batteryLevel: Double
}
