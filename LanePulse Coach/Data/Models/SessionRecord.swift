//
//  SessionRecord.swift
//  LanePulse Coach
//
//  Defines the CoreData managed object representing a training session.
//

import Foundation
import CoreData

@objc(SessionRecord)
public final class SessionRecord: NSManagedObject { }

extension SessionRecord: Identifiable { }

extension SessionRecord {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<SessionRecord> {
        NSFetchRequest<SessionRecord>(entityName: "SessionRecord")
    }
}

extension SessionRecord {
    @NSManaged public var id: UUID
    @NSManaged public var startDate: Date
    @NSManaged public var laneGroup: String?
    @NSManaged public var coachNotes: String?
}
