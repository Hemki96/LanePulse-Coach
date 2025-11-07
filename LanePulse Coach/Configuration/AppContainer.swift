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
    let sessionRepository: SessionRepositoryProtocol
    let bleManager: BLEManaging
    let analyticsService: AnalyticsServicing
    let exportService: DataExporting

    init(logger: Logging,
         persistenceController: PersistenceController,
         sessionRepository: SessionRepositoryProtocol,
         bleManager: BLEManaging,
         analyticsService: AnalyticsServicing,
         exportService: DataExporting) {
        self.logger = logger
        self.persistenceController = persistenceController
        self.sessionRepository = sessionRepository
        self.bleManager = bleManager
        self.analyticsService = analyticsService
        self.exportService = exportService
    }

    static func makeDefault() -> AppContainer {
        let logger = AppLogger()
        let persistenceController = PersistenceController()
        let repository = SessionRepository(context: persistenceController.container.viewContext, logger: logger)
        let bleManager = BLEManager(logger: logger)
        let analytics = AnalyticsService(logger: logger)
        let export = DataExportService(repository: repository, logger: logger)

        return AppContainer(logger: logger,
                            persistenceController: persistenceController,
                            sessionRepository: repository,
                            bleManager: bleManager,
                            analyticsService: analytics,
                            exportService: export)
    }

    static func makePreview() -> AppContainer {
        let logger = AppLogger(subsystem: "com.lanepulse.coach.preview")
        let persistenceController = PersistenceController.preview
        let repository = SessionRepository(context: persistenceController.container.viewContext, logger: logger)
        let bleManager = BLEManager(logger: logger)
        let analytics = AnalyticsService(logger: logger)
        let export = DataExportService(repository: repository, logger: logger)

        return AppContainer(logger: logger,
                            persistenceController: persistenceController,
                            sessionRepository: repository,
                            bleManager: bleManager,
                            analyticsService: analytics,
                            exportService: export)
    }
}
