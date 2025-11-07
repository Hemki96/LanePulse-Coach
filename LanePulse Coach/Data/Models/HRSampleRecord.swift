//
//  HRSampleRecord.swift
//  LanePulse Coach
//
//  CoreData managed object representing a heart-rate sample.
//

import Foundation
import CoreData

@objc(HRSampleRecord)
public final class HRSampleRecord: NSManagedObject { }

extension HRSampleRecord: Identifiable { }

extension HRSampleRecord {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<HRSampleRecord> {
        NSFetchRequest<HRSampleRecord>(entityName: "HRSampleRecord")
    }
}

extension HRSampleRecord {
    @NSManaged public var id: UUID
    @NSManaged public var sessionId: UUID
    @NSManaged public var athleteId: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var heartRate: Int16
}
