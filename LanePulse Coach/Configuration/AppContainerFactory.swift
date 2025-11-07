//
//  AppContainerFactory.swift
//  LanePulse Coach
//
//  Builds an AppContainer instance based on a configuration descriptor.
//

import Foundation
import CoreData

struct AppContainerFactory {
    func make(configuration: AppContainer.Configuration) -> AppContainer {
        let persistenceController = makePersistenceController(for: configuration)
        let viewContext = persistenceController.container.viewContext
        let backgroundContext = persistenceController.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext.automaticallyMergesChangesFromParent = true

        let logger = configuration.logger

        let athleteRepository = AthleteRepository(context: viewContext, logger: logger)
        let sensorRepository = SensorRepository(context: viewContext, logger: logger)
        let mappingRepository = MappingRepository(context: viewContext, logger: logger)
        let sessionRepository = SessionRepository(context: viewContext, logger: logger)
        let eventRepository = EventRepository(context: viewContext, logger: logger)
        let metricConfigRepository = MetricConfigRepository(context: viewContext, logger: logger)
        let hrSampleRepository = HRSampleRepository(writeContext: backgroundContext,
                                                   readContext: viewContext,
                                                   logger: logger)

        let bleManager = BLEManager(logger: logger)
        let analytics = AnalyticsService(logger: logger)
        let export = DataExportService(athleteRepository: athleteRepository,
                                       sensorRepository: sensorRepository,
                                       mappingRepository: mappingRepository,
                                       sessionRepository: sessionRepository,
                                       hrSampleRepository: hrSampleRepository,
                                       eventRepository: eventRepository,
                                       metricConfigRepository: metricConfigRepository,
                                       logger: logger)
        let latencyMonitor = LatencyMonitor(analytics: analytics,
                                            logger: logger,
                                            thresholds: .default,
                                            reportURL: latencyReportURL())

        let container = AppContainer(logger: logger,
                                     persistenceController: persistenceController,
                                     athleteRepository: athleteRepository,
                                     sensorRepository: sensorRepository,
                                     mappingRepository: mappingRepository,
                                     sessionRepository: sessionRepository,
                                     hrSampleRepository: hrSampleRepository,
                                     eventRepository: eventRepository,
                                     metricConfigRepository: metricConfigRepository,
                                     bleManager: bleManager,
                                     analyticsService: analytics,
                                     exportService: export,
                                     latencyMonitor: latencyMonitor)

        if configuration.featureFlags.seedUITestFixtures {
            UITestFixtureBuilder(container: container).seedMultiStream()
        }

        return container
    }

    private func makePersistenceController(for configuration: AppContainer.Configuration) -> PersistenceController {
        switch configuration.persistentStoreStrategy {
        case .create:
            return PersistenceController(inMemory: configuration.storeType == .inMemory)
        case .preview:
            return .preview
        }
    }

    private func latencyReportURL() -> URL? {
        guard let path = ProcessInfo.processInfo.environment["LATENCY_REPORT_PATH"], !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }
}

extension AppContainer {
    struct Configuration {
        enum PersistentStoreStrategy {
            case create
            case preview
        }

        enum StoreType {
            case sqlite
            case inMemory
        }

        struct FeatureFlags {
            var seedUITestFixtures: Bool = false
        }

        let logger: Logging
        let persistentStoreStrategy: PersistentStoreStrategy
        let storeType: StoreType
        var featureFlags: FeatureFlags
    }
}

protocol AppConfigurationBuilding {
    func make() -> AppContainer.Configuration
}

struct DefaultAppConfiguration: AppConfigurationBuilding {
    func make() -> AppContainer.Configuration {
        AppContainer.Configuration(logger: AppLogger(),
                                   persistentStoreStrategy: .create,
                                   storeType: .sqlite,
                                   featureFlags: .init())
    }
}

struct PreviewConfiguration: AppConfigurationBuilding {
    func make() -> AppContainer.Configuration {
        AppContainer.Configuration(logger: AppLogger(subsystem: "com.lanepulse.coach.preview"),
                                   persistentStoreStrategy: .preview,
                                   storeType: .inMemory,
                                   featureFlags: .init())
    }
}

struct UITestConfiguration: AppConfigurationBuilding {
    private let seedFixtures: Bool

    init(seedFixtures: Bool = true) {
        self.seedFixtures = seedFixtures
    }

    func make() -> AppContainer.Configuration {
        AppContainer.Configuration(logger: AppLogger(subsystem: "com.lanepulse.coach.uitest"),
                                   persistentStoreStrategy: .create,
                                   storeType: .inMemory,
                                   featureFlags: .init(seedUITestFixtures: seedFixtures))
    }
}

private final class UITestFixtureBuilder {
    private enum Constants {
        static let sessionId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        static let athleteCount = 4
        static let coachProfileId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        static let defaultMetrics = ["heartRate", "averageHeartRate", "zoneFraction", "recovery"]
    }

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func seedMultiStream() {
        let context = container.persistenceController.container.viewContext
        context.performAndWait {
            removeExistingData(in: context)
            createSession(in: context)
            createAthletes(in: context)
            try? context.save()
        }
    }

    private func removeExistingData(in context: NSManagedObjectContext) {
        let entityNames = ["AthleteRecord", "SensorRecord", "MappingRecord", "SessionRecord", "HRSampleRecord", "EventRecord", "MetricConfigRecord"]
        entityNames.forEach { entityName in
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetch)
            _ = try? context.execute(batchDelete)
        }
    }

    private func createSession(in context: NSManagedObjectContext) {
        let session = SessionRecord(context: context)
        session.id = Constants.sessionId
        session.startDate = Date().addingTimeInterval(-600)
        session.laneGroup = "Lane Group A"
        session.coachNotes = "UI Test Multi-Stream Session"
    }

    private func createAthletes(in context: NSManagedObjectContext) {
        let baseTimestamp = Date().addingTimeInterval(-180)
        for index in 0..<Constants.athleteCount {
            let athleteId = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1)) ?? UUID()
            let sensorId = UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", index + 1)) ?? UUID()

            let athlete = AthleteRecord(context: context)
            athlete.id = athleteId
            athlete.name = "Athlete \(index + 1)"
            athlete.hfMax = 190 - Int16(index * 5)

            let sensor = SensorRecord(context: context)
            sensor.id = sensorId
            sensor.vendor = "Polar H10-\(index + 1)"
            sensor.lastSeen = Date()
            sensor.batteryLevel = 0.85

            let mapping = MappingRecord(context: context)
            mapping.id = UUID()
            mapping.athleteId = athleteId
            mapping.sensorId = sensorId
            mapping.since = Date().addingTimeInterval(-3600)
            mapping.nickname = "Lane \(index + 1)"

            for sampleIndex in 0..<90 {
                let sample = HRSampleRecord(context: context)
                sample.id = UUID()
                sample.sessionId = Constants.sessionId
                sample.athleteId = athleteId
                sample.timestamp = baseTimestamp.addingTimeInterval(Double(sampleIndex * 2))
                let baseValue = 120 + (index * 4)
                sample.heartRate = Int16(baseValue + (sampleIndex % 7))
            }
        }

        let metricConfig = MetricConfigRecord(context: context)
        metricConfig.id = UUID()
        metricConfig.coachProfileId = Constants.coachProfileId
        metricConfig.visibleMetrics = Constants.defaultMetrics
        metricConfig.thresholds = [
            "zone1": 0.6,
            "zone2": 0.7,
            "zone3": 0.8,
            "zone4": 0.9
        ]
    }
}
