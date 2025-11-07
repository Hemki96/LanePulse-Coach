//
//  SessionRecord.swift
//  LanePulse Coach
//
//  Created by SwiftCodex on 2024-07-??.
//

import Foundation
import CoreData

@objc(SessionRecord)
public final class SessionRecord: NSManagedObject {
    @NSManaged public var timestamp: Date
}

extension SessionRecord: Identifiable { }

extension SessionRecord {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<SessionRecord> {
        NSFetchRequest<SessionRecord>(entityName: "SessionRecord")
    }
}
