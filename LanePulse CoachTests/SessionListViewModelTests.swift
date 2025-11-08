@testable import LanePulse_Coach
import XCTest
import CoreData
import Combine

final class SessionListViewModelTests: XCTestCase {
    private var container: AppContainer!
    private var bleManager: MockBLEManager!
    private var viewModel: SessionListViewModel!
    private var cancellables: Set<AnyCancellable> = []
    private var widgetRefresher: WidgetRefresherMock!

    override func setUpWithError() throws {
        container = AppContainer.makePreview()
        bleManager = MockBLEManager()
        widgetRefresher = WidgetRefresherMock()
        viewModel = SessionListViewModel(sessionRepository: container.sessionRepository,
                                         bleManager: bleManager,
                                         analyticsService: container.analyticsService,
                                         logger: container.logger,
                                         context: container.persistenceController.container.viewContext,
                                         widgetRefresher: widgetRefresher)
    }

    override func tearDownWithError() throws {
        cancellables.removeAll()
        viewModel = nil
        bleManager = nil
        container = nil
        widgetRefresher = nil
    }

    func testInitialSnapshotContainsPreviewSessions() throws {
        XCTAssertEqual(viewModel.snapshot.items.count, 5)
        let sorted = viewModel.snapshot.items.sorted { $0.startDate > $1.startDate }
        XCTAssertEqual(viewModel.snapshot.items.map(\.sessionID), sorted.map(\.sessionID))
    }

    func testAddSessionIncreasesSnapshotCount() throws {
        let expectation = expectation(description: "snapshot updates after add")
        viewModel.$snapshot
            .dropFirst()
            .sink { snapshot in
                if snapshot.items.count == 6 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        viewModel.addSession()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertGreaterThan(widgetRefresher.reloadAllCallCount, 0)
    }

    func testDeleteSessionsRemovesItems() throws {
        let initialCount = viewModel.snapshot.items.count
        let expectation = expectation(description: "snapshot updates after delete")
        viewModel.$snapshot
            .dropFirst()
            .sink { snapshot in
                if snapshot.items.count == initialCount - 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        viewModel.deleteSessions(at: IndexSet(integer: 0))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertGreaterThan(widgetRefresher.reloadAllCallCount, 0)
    }

    func testToggleScanningUpdatesState() throws {
        XCTAssertFalse(viewModel.isScanning)
        viewModel.toggleScanning()
        XCTAssertTrue(viewModel.isScanning)
        viewModel.toggleScanning()
        XCTAssertFalse(viewModel.isScanning)
    }

    func testManagerPublishingUpdatesState() throws {
        let expectation = expectation(description: "scan status updated")
        viewModel.$isScanning
            .dropFirst()
            .sink { isScanning in
                if isScanning {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        bleManager.startScanning()

        wait(for: [expectation], timeout: 1.0)
    }
}

private final class MockBLEManager: ObservableObject, BLEManaging {
    @Published var isScanning: Bool = false
    var discoveredDevices: [BLEDevice] = []
    var connectionState: BLEConnectionState = .idle
    var lastResampledSample: ResampledHeartRateSample?

    func startScanning() {
        isScanning = true
    }

    func stopScanning() {
        isScanning = false
    }

    func connect(to device: BLEDevice) {}

    func disconnect() {}

    func subscribeToHeartRate() {}
}
