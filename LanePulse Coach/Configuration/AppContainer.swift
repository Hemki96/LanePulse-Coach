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
         exportService: DataExporting) {
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
                            exportService: export)
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
                            exportService: export)
    }
}
