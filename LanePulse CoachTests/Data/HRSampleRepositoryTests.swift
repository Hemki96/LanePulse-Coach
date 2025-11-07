import XCTest
import CoreData
@testable import LanePulse_Coach

final class HRSampleRepositoryTests: XCTestCase {
    private var persistenceController: PersistenceController!
    private var readContext: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistenceController = PersistenceController(inMemory: true)
        readContext = persistenceController.container.viewContext
    }

    override func tearDownWithError() throws {
        persistenceController = nil
        readContext = nil
        try super.tearDownWithError()
    }

    func testBackgroundQueueFlushPersistsSamples() throws {
        let backgroundContext = persistenceController.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext.automaticallyMergesChangesFromParent = true

        let logger = TestLogger()
        let pendingStore = InMemoryPendingStore()
        let notificationCenter = NotificationCenter()
        let repository = HRSampleRepository(writeContext: backgroundContext,
                                            readContext: readContext,
                                            logger: logger,
                                            batchInterval: 0.25,
                                            maxBatchSize: 50,
                                            pendingStore: pendingStore,
                                            notificationCenter: notificationCenter,
                                            sceneDidEnterBackgroundNotification: Notification.Name("TestSceneDidEnterBackground"))

        let sessionId = UUID()
        let athleteId = UUID()
        repository.startSession(id: sessionId)

        let expectation = expectation(description: "Samples persisted")
        DispatchQueue.global(qos: .background).async {
            repository.enqueue(HRSampleInput(sessionId: sessionId,
                                             athleteId: athleteId,
                                             timestamp: Date(),
                                             heartRate: 135))
        }

        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
            self.readContext.perform {
                let request: NSFetchRequest<HRSampleRecord> = HRSampleRecord.fetchRequest()
                let count = (try? self.readContext.count(for: request)) ?? 0
                if count == 1 {
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 3.0)

        readContext.performAndWait {
            let request: NSFetchRequest<HRSampleRecord> = HRSampleRecord.fetchRequest()
            let records = try? readContext.fetch(request)
            XCTAssertEqual(records?.count, 1)
            XCTAssertEqual(records?.first?.heartRate, 135)
        }
        repository.endSession()
    }

    func testSceneDidEnterBackgroundFlushesBuffer() throws {
        let backgroundContext = persistenceController.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext.automaticallyMergesChangesFromParent = true

        let logger = TestLogger()
        let pendingStore = InMemoryPendingStore()
        let notificationCenter = NotificationCenter()
        let repository = HRSampleRepository(writeContext: backgroundContext,
                                            readContext: readContext,
                                            logger: logger,
                                            batchInterval: 10.0,
                                            maxBatchSize: 50,
                                            pendingStore: pendingStore,
                                            notificationCenter: notificationCenter,
                                            sceneDidEnterBackgroundNotification: Notification.Name("TestSceneDidEnterBackground"))

        let sessionId = UUID()
        let athleteId = UUID()
        repository.startSession(id: sessionId)

        repository.enqueue(HRSampleInput(sessionId: sessionId,
                                         athleteId: athleteId,
                                         timestamp: Date(),
                                         heartRate: 142))

        repository.sceneDidEnterBackground()

        readContext.performAndWait {
            let request: NSFetchRequest<HRSampleRecord> = HRSampleRecord.fetchRequest()
            let records = try? readContext.fetch(request)
            XCTAssertEqual(records?.count, 1)
            XCTAssertEqual(records?.first?.heartRate, 142)
        }
        XCTAssertTrue(pendingStore.snapshot.isEmpty)
        repository.endSession()
    }

    func testFlushRetriesAfterSaveFailure() throws {
        let failingContext = FailingManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        failingContext.persistentStoreCoordinator = readContext.persistentStoreCoordinator
        failingContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        failingContext.automaticallyMergesChangesFromParent = true
        failingContext.failuresRemaining = 1

        let logger = TestLogger()
        let pendingStore = InMemoryPendingStore()
        let notificationCenter = NotificationCenter()
        let repository = HRSampleRepository(writeContext: failingContext,
                                            readContext: readContext,
                                            logger: logger,
                                            batchInterval: 10.0,
                                            maxBatchSize: 10,
                                            pendingStore: pendingStore,
                                            notificationCenter: notificationCenter,
                                            sceneDidEnterBackgroundNotification: Notification.Name("TestSceneDidEnterBackground"))

        let sessionId = UUID()
        let athleteId = UUID()
        repository.startSession(id: sessionId)

        let sample = HRSampleInput(sessionId: sessionId,
                                   athleteId: athleteId,
                                   timestamp: Date(),
                                   heartRate: 150)
        repository.enqueue(sample)

        XCTAssertThrowsError(try repository.flush())
        XCTAssertEqual(pendingStore.snapshot.count, 1)

        failingContext.failuresRemaining = 0
        try repository.flush()

        readContext.performAndWait {
            let request: NSFetchRequest<HRSampleRecord> = HRSampleRecord.fetchRequest()
            let records = try? readContext.fetch(request)
            XCTAssertEqual(records?.count, 1)
            XCTAssertEqual(records?.first?.heartRate, 150)
        }
        XCTAssertTrue(pendingStore.snapshot.isEmpty)
        repository.endSession()
    }
}

private final class TestLogger: Logging {
    private(set) var entries: [(LogLevel, String)] = []

    func log(level: LogLevel, message: String, metadata: [String: String]?) {
        entries.append((level, message))
    }
}

private final class InMemoryPendingStore: PendingHRSampleStoring {
    private var storage: [HRSampleInput] = []
    private let queue = DispatchQueue(label: "com.lanepulse.coach.tests.pendingStore")

    func load() throws -> [HRSampleInput] {
        queue.sync { storage }
    }

    func store(_ samples: [HRSampleInput]) throws {
        queue.sync { storage = samples }
    }

    var snapshot: [HRSampleInput] {
        queue.sync { storage }
    }
}

private final class FailingManagedObjectContext: NSManagedObjectContext {
    var failuresRemaining: Int = 0

    override func save() throws {
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw NSError(domain: "HRSampleRepositoryTests", code: 1)
        }
        try super.save()
    }
}
