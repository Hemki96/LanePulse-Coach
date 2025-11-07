//
//  EventRecord.swift
//  LanePulse Coach
//
//  CoreData managed object representing a coaching event.
//

import Foundation
import CoreData

@objc(EventRecord)
public final class EventRecord: NSManagedObject { }

extension EventRecord: Identifiable { }

extension EventRecord {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<EventRecord> {
        NSFetchRequest<EventRecord>(entityName: "EventRecord")
    }
}

extension EventRecord {
    @NSManaged public var id: UUID
    @NSManaged public var sessionId: UUID
    @NSManaged public var athleteId: UUID?
    @NSManaged public var type: String
    @NSManaged public var start: Date
    @NSManaged public var end: Date?
    @NSManaged public var metadata: Data?
}
