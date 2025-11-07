//
//  AppContainer.swift
//  LanePulse Coach
//
//  Central dependency container for the application modules.
//

import Foundation
import CoreData

final class AppContainer: ObservableObject {
    let logger: Logging
    let persistenceController: PersistenceController
    let athleteRepository: AthleteRepositoryProtocol
    let sensorRepository: SensorRepositoryProtocol
    let mappingRepository: MappingRepositoryProtocol
    let sessionRepository: SessionRepositoryProtocol
    let hrSampleRepository: HRSampleRepositoryProtocol
    let eventRepository: EventRepositoryProtocol
    let metricConfigRepository: MetricConfigRepositoryProtocol
    let bleManager: BLEManaging
    let analyticsService: AnalyticsServicing
    let exportService: DataExporting
    let latencyMonitor: LatencyMonitoring

    init(logger: Logging,
         persistenceController: PersistenceController,
         athleteRepository: AthleteRepositoryProtocol,
         sensorRepository: SensorRepositoryProtocol,
         mappingRepository: MappingRepositoryProtocol,
         sessionRepository: SessionRepositoryProtocol,
         hrSampleRepository: HRSampleRepositoryProtocol,
         eventRepository: EventRepositoryProtocol,
         metricConfigRepository: MetricConfigRepositoryProtocol,
         bleManager: BLEManaging,
         analyticsService: AnalyticsServicing,
         exportService: DataExporting,
         latencyMonitor: LatencyMonitoring) {
        self.logger = logger
        self.persistenceController = persistenceController
        self.athleteRepository = athleteRepository
        self.sensorRepository = sensorRepository
        self.mappingRepository = mappingRepository
        self.sessionRepository = sessionRepository
        self.hrSampleRepository = hrSampleRepository
        self.eventRepository = eventRepository
        self.metricConfigRepository = metricConfigRepository
        self.bleManager = bleManager
        self.analyticsService = analyticsService
        self.exportService = exportService
        self.latencyMonitor = latencyMonitor
    }

    static func makeDefault() -> AppContainer {
        let logger = AppLogger()
        let persistenceController = PersistenceController()
        let viewContext = persistenceController.container.viewContext
        let backgroundContext = persistenceController.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext.automaticallyMergesChangesFromParent = true

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
                                            reportURL: Self.latencyReportURL())

        return AppContainer(logger: logger,
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
    }

    static func makePreview() -> AppContainer {
        let logger = AppLogger(subsystem: "com.lanepulse.coach.preview")
        let persistenceController = PersistenceController.preview
        let viewContext = persistenceController.container.viewContext
        let backgroundContext = persistenceController.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext.automaticallyMergesChangesFromParent = true

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
                                            reportURL: Self.latencyReportURL())

        return AppContainer(logger: logger,
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
    }

    static func makeUITestMultiStream() -> AppContainer {
        let logger = AppLogger(subsystem: "com.lanepulse.coach.uitest")
        let persistenceController = PersistenceController(inMemory: true)
        let viewContext = persistenceController.container.viewContext
        let backgroundContext = persistenceController.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext.automaticallyMergesChangesFromParent = true

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
                                            reportURL: Self.latencyReportURL())

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

        UITestFixtureBuilder(container: container).seedMultiStream()
        return container
    }

    private static func latencyReportURL() -> URL? {
        guard let path = ProcessInfo.processInfo.environment["LATENCY_REPORT_PATH"], !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path)
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
        metricConfig.visibleMetrics = Constants.defaultMetrics as NSArray
        metricConfig.thresholds = [
            "zone1": 0.6,
            "zone2": 0.7,
            "zone3": 0.8,
            "zone4": 0.9
        ] as NSDictionary
    }
}
