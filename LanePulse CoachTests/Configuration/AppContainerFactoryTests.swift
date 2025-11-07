import XCTest
import CoreData
@testable import LanePulse_Coach

final class AppContainerFactoryTests: XCTestCase {
    func testBuildsDefaultConfiguration() throws {
        let builder = DefaultAppConfiguration()
        let configuration = builder.make()
        let container = AppContainerFactory().make(configuration: configuration)

        XCTAssertTrue((container.logger as AnyObject) === (configuration.logger as AnyObject))
        XCTAssertTrue(container.bleManager is BLEController)
        XCTAssertTrue(container.analyticsService is AnalyticsService)
        XCTAssertTrue(container.exportService is DataExportService)
        XCTAssertTrue(container.latencyMonitor is LatencyMonitor)
        XCTAssertTrue(container.athleteRepository is AthleteRepository)
        XCTAssertTrue(container.sensorRepository is SensorRepository)
        XCTAssertTrue(container.mappingRepository is MappingRepository)
        XCTAssertTrue(container.sessionRepository is SessionRepository)
        XCTAssertTrue(container.hrSampleRepository is HRSampleRepository)
        XCTAssertTrue(container.eventRepository is EventRepository)
        XCTAssertTrue(container.metricConfigRepository is MetricConfigRepository)

        let description = try XCTUnwrap(container.persistenceController.container.persistentStoreDescriptions.first)
        XCTAssertEqual(description.type, NSSQLiteStoreType)
    }

    func testPreviewConfigurationUsesInMemoryStore() throws {
        let builder = PreviewConfiguration()
        let configuration = builder.make()
        let container = AppContainerFactory().make(configuration: configuration)

        let description = try XCTUnwrap(container.persistenceController.container.persistentStoreDescriptions.first)
        XCTAssertEqual(description.type, NSInMemoryStoreType)

        let context = container.persistenceController.container.viewContext
        let request: NSFetchRequest<SessionRecord> = SessionRecord.fetchRequest()
        let sessions = try context.fetch(request)
        XCTAssertFalse(sessions.isEmpty)
    }

    func testUITestConfigurationSeedsFixturesWhenEnabled() throws {
        let builder = UITestConfiguration(seedFixtures: true)
        let configuration = builder.make()
        let container = AppContainerFactory().make(configuration: configuration)

        let context = container.persistenceController.container.viewContext
        let athleteRequest: NSFetchRequest<AthleteRecord> = AthleteRecord.fetchRequest()
        let athletes = try context.fetch(athleteRequest)
        XCTAssertEqual(athletes.count, 4)
    }

    func testUITestConfigurationDoesNotSeedFixturesWhenDisabled() throws {
        let builder = UITestConfiguration(seedFixtures: false)
        let configuration = builder.make()
        let container = AppContainerFactory().make(configuration: configuration)

        let context = container.persistenceController.container.viewContext
        let athleteRequest: NSFetchRequest<AthleteRecord> = AthleteRecord.fetchRequest()
        let athletes = try context.fetch(athleteRequest)
        XCTAssertTrue(athletes.isEmpty)
    }
}
