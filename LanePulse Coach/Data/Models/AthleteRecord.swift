//
//  AthleteRecord.swift
//  LanePulse Coach
//
//  CoreData managed object describing an athlete profile.
//

import Foundation
import CoreData

@objc(AthleteRecord)
public final class AthleteRecord: NSManagedObject { }

extension AthleteRecord: Identifiable { }

extension AthleteRecord {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<AthleteRecord> {
        NSFetchRequest<AthleteRecord>(entityName: "AthleteRecord")
    }
}

extension AthleteRecord {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var hfMax: Int16
    @NSManaged public var zoneModel: String?
    @NSManaged public var notes: String?
}
