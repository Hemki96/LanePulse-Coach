//
//  MetricConfigRecord.swift
//  LanePulse Coach
//
//  CoreData managed object describing metric configuration per coach profile.
//

import Foundation
import CoreData

@objc(MetricConfigRecord)
public final class MetricConfigRecord: NSManagedObject { }

extension MetricConfigRecord: Identifiable { }

extension MetricConfigRecord {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<MetricConfigRecord> {
        NSFetchRequest<MetricConfigRecord>(entityName: "MetricConfigRecord")
    }
}

extension MetricConfigRecord {
    @NSManaged public var id: UUID
    @NSManaged public var coachProfileId: UUID
    @NSManaged public var visibleMetrics: [String]
    @NSManaged public var thresholds: [String: Double]
}
