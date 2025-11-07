import XCTest
@testable import LanePulse_Coach

final class BLEControllerTests: XCTestCase {
    private var logger: CapturingLogger!
    private var adapter: MockAdapter!
    private var coordinator: MockHeartRateStreamCoordinator!
    private var controller: BLEController!

    override func setUp() {
        super.setUp()
        logger = CapturingLogger()
        adapter = MockAdapter()
        coordinator = MockHeartRateStreamCoordinator()
        controller = BLEController(logger: logger,
                                   adapters: [adapter],
                                   streamCoordinator: coordinator)
    }

    override func tearDown() {
        controller = nil
        coordinator = nil
        adapter = nil
        logger = nil
        super.tearDown()
    }

    func testConnectingAndStreamingTransitionsState() {
        let device = BLEDevice(id: "device-1", name: "Polar H10", rssi: -45)

        controller.connect(to: device)
        adapter.simulateConnect(device)
        waitForMainQueue()

        XCTAssertEqual(controller.connectionState, .streaming(device: device))
        XCTAssertTrue(coordinator.startCalled)
        XCTAssertEqual(adapter.subscribeCallCount, 1)

        coordinator.simulateEmission(isStale: false, bpm: 72.0)
        waitForMainQueue()

        XCTAssertEqual(controller.lastResampledSample?.bpm, 72.0)
        XCTAssertEqual(controller.connectionState, .streaming(device: device))
    }

    func testReconnectsAfterConsecutiveStaleEmissions() {
        let device = BLEDevice(id: "device-2", name: "Polar H10", rssi: -48)

        controller.connect(to: device)
        adapter.simulateConnect(device)
        waitForMainQueue()

        for _ in 0..<3 {
            coordinator.simulateEmission(isStale: true, bpm: nil)
        }
        waitForMainQueue()

        XCTAssertEqual(adapter.cancelStreamCallCount, 1)
        XCTAssertEqual(adapter.disconnectCallCount, 1)
        XCTAssertEqual(controller.connectionState, .reconnecting(device: device, attempt: 1))

        adapter.simulateDisconnect(device)
        waitForMainQueue()

        let expectation = XCTestExpectation(description: "Reconnect attempted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if self.adapter.connectCalls.count > 1 {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.5)
    }

    func testManualDisconnectCancelsReconnects() {
        let device = BLEDevice(id: "device-3", name: "Polar H10", rssi: -50)

        controller.connect(to: device)
        adapter.simulateConnect(device)
        waitForMainQueue()

        controller.disconnect()
        XCTAssertEqual(adapter.disconnectCallCount, 1)

        adapter.simulateDisconnect(device)
        waitForMainQueue()

        let expectation = XCTestExpectation(description: "No reconnect scheduled")
        expectation.isInverted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if self.adapter.connectCalls.count > 1 {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.5)
        XCTAssertEqual(controller.connectionState, .disconnected(device: device, error: nil))
    }

    // MARK: - Helpers

    private func waitForMainQueue(file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTestExpectation(description: "Wait for main queue")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }
}

private final class CapturingLogger: Logging {
    struct Entry { let level: LogLevel; let message: String }
    private(set) var entries: [Entry] = []

    func log(level: LogLevel, message: String, metadata: [String: String]?) {
        entries.append(.init(level: level, message: message))
    }
}

private final class MockAdapter: BLEHardwareAdapter {
    weak var delegate: BLEHardwareAdapterDelegate?

    private(set) var startScanCallCount = 0
    private(set) var stopScanCallCount = 0
    private(set) var connectCalls: [BLEDevice] = []
    private(set) var disconnectCallCount = 0
    private(set) var subscribeCallCount = 0
    private(set) var cancelStreamCallCount = 0

    func startScanning() {
        startScanCallCount += 1
    }

    func stopScanning() {
        stopScanCallCount += 1
    }

    func connect(to device: BLEDevice) {
        connectCalls.append(device)
    }

    func disconnect(from device: BLEDevice?) {
        disconnectCallCount += 1
    }

    func subscribeToHeartRate(for device: BLEDevice) {
        subscribeCallCount += 1
    }

    func cancelHeartRateStreaming(for device: BLEDevice) {
        cancelStreamCallCount += 1
    }

    func simulateDiscover(_ device: BLEDevice) {
        delegate?.hardwareAdapter(self, didDiscover: device)
    }

    func simulateConnect(_ device: BLEDevice) {
        delegate?.hardwareAdapter(self, didConnect: device)
    }

    func simulateDisconnect(_ device: BLEDevice, error: Error? = nil) {
        delegate?.hardwareAdapter(self, didDisconnect: device, error: error)
    }
}

private final class MockHeartRateStreamCoordinator: HeartRateStreamCoordinating {
    weak var delegate: HeartRateStreamCoordinatorDelegate?
    private(set) var lastSample: ResampledHeartRateSample?
    private(set) var startCalled = false
    private(set) var stopCalled = false
    private(set) var resetCalled = false
    private var consecutiveStaleCount = 0

    func start() {
        startCalled = true
    }

    func stop() {
        stopCalled = true
    }

    func reset() {
        resetCalled = true
        consecutiveStaleCount = 0
        lastSample = nil
    }

    func handleIncomingSample(_ sample: HeartRateSample) {
        // In tests we control emissions directly.
    }

    func simulateEmission(isStale: Bool, bpm: Double?) {
        let sample = ResampledHeartRateSample(timestamp: Date(), bpm: bpm, isStale: isStale)
        lastSample = sample
        if isStale {
            consecutiveStaleCount += 1
        } else {
            consecutiveStaleCount = 0
        }
        delegate?.heartRateStreamCoordinator(self,
                                             didEmit: sample,
                                             consecutiveStaleCount: consecutiveStaleCount)
    }
}
