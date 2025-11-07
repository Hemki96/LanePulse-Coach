//
//  BLEController.swift
//  LanePulse Coach
//
//  Coordinates BLE state transitions while delegating
//  platform-specific work to injected adapters and
//  heart-rate stream coordination services.
//

import Foundation
#if canImport(Combine)
import Combine
#endif

struct BLEDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let rssi: Int?

    init(id: String, name: String, rssi: Int?) {
        self.id = id
        self.name = name
        self.rssi = rssi
    }
}

enum BLEConnectionState: Equatable {
    case idle
    case scanning
    case connecting(device: BLEDevice)
    case connected(device: BLEDevice)
    case streaming(device: BLEDevice)
    case stale(device: BLEDevice, since: Date)
    case reconnecting(device: BLEDevice, attempt: Int)
    case disconnected(device: BLEDevice?, error: Error?)

    static func == (lhs: BLEConnectionState, rhs: BLEConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.scanning, .scanning):
            return true
        case let (.connecting(lhsDevice), .connecting(rhsDevice)):
            return lhsDevice == rhsDevice
        case let (.connected(lhsDevice), .connected(rhsDevice)):
            return lhsDevice == rhsDevice
        case let (.streaming(lhsDevice), .streaming(rhsDevice)):
            return lhsDevice == rhsDevice
        case let (.stale(lhsDevice, lhsDate), .stale(rhsDevice, rhsDate)):
            return lhsDevice == rhsDevice && lhsDate == rhsDate
        case let (.reconnecting(lhsDevice, lhsAttempt), .reconnecting(rhsDevice, rhsAttempt)):
            return lhsDevice == rhsDevice && lhsAttempt == rhsAttempt
        case let (.disconnected(lhsDevice, lhsError), .disconnected(rhsDevice, rhsError)):
            return lhsDevice == rhsDevice && errorsEqual(lhsError, rhsError)
        default:
            return false
        }
    }

    private static func errorsEqual(_ lhs: Error?, _ rhs: Error?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            let lhsError = lhs as NSError
            let rhsError = rhs as NSError
            return lhsError.domain == rhsError.domain && lhsError.code == rhsError.code
        default:
            return false
        }
    }
}

protocol BLEManaging: AnyObject {
    var isScanning: Bool { get }
    var discoveredDevices: [BLEDevice] { get }
    var connectionState: BLEConnectionState { get }
    var lastResampledSample: ResampledHeartRateSample? { get }

    func startScanning()
    func stopScanning()
    func connect(to device: BLEDevice)
    func disconnect()
    func subscribeToHeartRate()
}

protocol BLEHardwareAdapter: AnyObject {
    var delegate: BLEHardwareAdapterDelegate? { get set }

    func startScanning()
    func stopScanning()
    func connect(to device: BLEDevice)
    func disconnect(from device: BLEDevice?)
    func subscribeToHeartRate(for device: BLEDevice)
    func cancelHeartRateStreaming(for device: BLEDevice)
}

protocol BLEHardwareAdapterDelegate: AnyObject {
    func hardwareAdapter(_ adapter: BLEHardwareAdapter, didDiscover device: BLEDevice)
    func hardwareAdapter(_ adapter: BLEHardwareAdapter, didStartConnecting device: BLEDevice)
    func hardwareAdapter(_ adapter: BLEHardwareAdapter, didConnect device: BLEDevice)
    func hardwareAdapter(_ adapter: BLEHardwareAdapter, didFailToConnect device: BLEDevice, error: Error?)
    func hardwareAdapter(_ adapter: BLEHardwareAdapter, didDisconnect device: BLEDevice, error: Error?)
    func hardwareAdapter(_ adapter: BLEHardwareAdapter, didReceiveHeartRate sample: HeartRateSample, from device: BLEDevice)
}

final class BLEController: NSObject, ObservableObject, BLEManaging {
    private enum Constants {
        static let staleEmissionThreshold = 3
        static let maxReconnectAttempts = 3
        static let reconnectDelay: TimeInterval = 1.0
    }

    @Published private(set) var isScanning: Bool = false
    @Published private(set) var discoveredDevices: [BLEDevice] = []
    @Published private(set) var connectionState: BLEConnectionState = .idle
    @Published private(set) var lastResampledSample: ResampledHeartRateSample?

    private let logger: Logging
    private let streamCoordinator: HeartRateStreamCoordinating
    private var adapters: [BLEHardwareAdapter]
    private var devicesByID: [String: BLEDevice] = [:]
    private var adapterForDeviceID: [String: BLEHardwareAdapter] = [:]
    private var reconnectAttempts: Int = 0
    private var isPerformingReconnect: Bool = false
    private var shouldMaintainStreaming: Bool = false
    private var expectedDisconnect: Bool = false
    private var currentDevice: BLEDevice?
    private weak var activeAdapter: BLEHardwareAdapter?

    init(logger: Logging,
         adapters: [BLEHardwareAdapter],
         streamCoordinator: HeartRateStreamCoordinating) {
        self.logger = logger
        self.adapters = adapters
        self.streamCoordinator = streamCoordinator
        super.init()
        adapters.forEach { $0.delegate = self }
        streamCoordinator.delegate = self
    }

    convenience init(logger: Logging,
                     adapters: [BLEHardwareAdapter]) {
        let coordinator = HeartRateStreamCoordinator(resampler: HeartRateResampler(interval: 1.0))
        self.init(logger: logger, adapters: adapters, streamCoordinator: coordinator)
    }

    func startScanning() {
        guard !isScanning else { return }
        logger.log(level: .info, message: "Starting BLE scan")
        updateState(.scanning)
        isScanning = true
        adapters.forEach { $0.startScanning() }
    }

    func stopScanning() {
        guard isScanning else { return }
        logger.log(level: .info, message: "Stopping BLE scan")
        adapters.forEach { $0.stopScanning() }
        isScanning = false
        if case .scanning = connectionState {
            updateState(.idle)
        }
    }

    func connect(to device: BLEDevice) {
        let adapter = adapterForDeviceID[device.id] ?? adapters.first
        currentDevice = device
        activeAdapter = adapter
        reconnectAttempts = 0
        isPerformingReconnect = false
        shouldMaintainStreaming = true
        expectedDisconnect = false
        guard let adapter else {
            logger.log(level: .error, message: "No adapter available to connect to device \(device.id)")
            shouldMaintainStreaming = false
            currentDevice = nil
            updateState(.disconnected(device: device, error: nil))
            return
        }
        logger.log(level: .info, message: "Connecting to device \(device.name) [\(device.id)]")
        updateState(.connecting(device: device))
        adapter.connect(to: device)
    }

    func disconnect() {
        guard let device = currentDevice else { return }
        logger.log(level: .info, message: "Disconnecting from device \(device.name)")
        shouldMaintainStreaming = false
        expectedDisconnect = true
        streamCoordinator.stop()
        streamCoordinator.reset()
        reconnectAttempts = 0
        isPerformingReconnect = false
        if let adapter = activeAdapter {
            adapter.cancelHeartRateStreaming(for: device)
            adapter.disconnect(from: device)
        }
        currentDevice = nil
        activeAdapter = nil
    }

    func subscribeToHeartRate() {
        guard let device = currentDevice, let adapter = activeAdapter else { return }
        shouldMaintainStreaming = true
        streamCoordinator.start()
        if case .connected = connectionState {
            updateState(.streaming(device: device))
        }
        adapter.subscribeToHeartRate(for: device)
    }

    private func initiateReconnect(for device: BLEDevice) {
        guard !isPerformingReconnect, let adapter = activeAdapter else { return }
        logger.log(level: .warning, message: "Attempting reconnect #\(reconnectAttempts) for device \(device.name)")
        isPerformingReconnect = true
        updateState(.reconnecting(device: device, attempt: reconnectAttempts))
        streamCoordinator.stop()
        adapter.cancelHeartRateStreaming(for: device)
        adapter.disconnect(from: device)
    }

    private func handleDisconnect(from adapter: BLEHardwareAdapter, device: BLEDevice, error: Error?) {
        streamCoordinator.stop()
        streamCoordinator.reset()
        updateState(.disconnected(device: device, error: error))
        isPerformingReconnect = false
        if shouldMaintainStreaming,
           !expectedDisconnect,
           reconnectAttempts < Constants.maxReconnectAttempts {
            logger.log(level: .info, message: "Scheduling reconnect for \(device.name)")
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.reconnectDelay) { [weak self, weak adapter] in
                guard let self, let adapter else { return }
                guard self.shouldMaintainStreaming else { return }
                self.logger.log(level: .info, message: "Reconnecting to device \(device.name)")
                adapter.connect(to: device)
            }
        } else {
            shouldMaintainStreaming = false
            currentDevice = nil
            activeAdapter = nil
            expectedDisconnect = false
        }
    }

    private func updateState(_ newState: BLEConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.connectionState = newState
            self.logger.log(level: .debug, message: "BLE state transitioned to \(newState)")
        }
    }

    private func updateDiscoveredDevices(with device: BLEDevice, via adapter: BLEHardwareAdapter) {
        devicesByID[device.id] = device
        adapterForDeviceID[device.id] = adapter
        let sorted = devicesByID.values.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        DispatchQueue.main.async { [weak self] in
            self?.discoveredDevices = sorted
        }
    }
}

extension BLEController: BLEHardwareAdapterDelegate {
    func hardwareAdapter(_ adapter: BLEHardwareAdapter, didDiscover device: BLEDevice) {
        updateDiscoveredDevices(with: device, via: adapter)
    }

    func hardwareAdapter(_ adapter: BLEHardwareAdapter, didStartConnecting device: BLEDevice) {
        currentDevice = device
        activeAdapter = adapter
        updateState(.connecting(device: device))
    }

    func hardwareAdapter(_ adapter: BLEHardwareAdapter, didConnect device: BLEDevice) {
        currentDevice = device
        activeAdapter = adapter
        reconnectAttempts = 0
        isPerformingReconnect = false
        expectedDisconnect = false
        streamCoordinator.reset()
        updateState(.connected(device: device))
        if shouldMaintainStreaming {
            subscribeToHeartRate()
        }
    }

    func hardwareAdapter(_ adapter: BLEHardwareAdapter, didFailToConnect device: BLEDevice, error: Error?) {
        logger.log(level: .error, message: "Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        reconnectAttempts += 1
        handleDisconnect(from: adapter, device: device, error: error)
    }

    func hardwareAdapter(_ adapter: BLEHardwareAdapter, didDisconnect device: BLEDevice, error: Error?) {
        logger.log(level: .warning, message: "Disconnected from \(device.name)")
        if expectedDisconnect {
            expectedDisconnect = false
            shouldMaintainStreaming = false
            currentDevice = nil
            activeAdapter = nil
            updateState(.disconnected(device: device, error: error))
        } else {
            handleDisconnect(from: adapter, device: device, error: error)
        }
    }

    func hardwareAdapter(_ adapter: BLEHardwareAdapter, didReceiveHeartRate sample: HeartRateSample, from device: BLEDevice) {
        guard currentDevice == device else { return }
        streamCoordinator.handleIncomingSample(sample)
    }
}

extension BLEController: HeartRateStreamCoordinatorDelegate {
    func heartRateStreamCoordinator(_ coordinator: HeartRateStreamCoordinating,
                                    didEmit sample: ResampledHeartRateSample,
                                    consecutiveStaleCount: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.lastResampledSample = sample
        }
        guard let device = currentDevice else { return }
        if sample.isStale {
            if consecutiveStaleCount == 1, case .streaming = connectionState {
                updateState(.stale(device: device, since: sample.timestamp))
            }
            if shouldMaintainStreaming,
               consecutiveStaleCount >= Constants.staleEmissionThreshold,
               reconnectAttempts < Constants.maxReconnectAttempts {
                reconnectAttempts += 1
                initiateReconnect(for: device)
            }
        } else {
            if case .stale = connectionState {
                updateState(.streaming(device: device))
            } else if case .connected = connectionState {
                updateState(.streaming(device: device))
            }
            if consecutiveStaleCount == 0 {
                reconnectAttempts = 0
            }
        }
    }
}

extension BLEConnectionState: CustomStringConvertible {
    var description: String {
        switch self {
        case .idle:
            return "idle"
        case .scanning:
            return "scanning"
        case .connecting(let device):
            return "connecting(\(device.name))"
        case .connected(let device):
            return "connected(\(device.name))"
        case .streaming(let device):
            return "streaming(\(device.name))"
        case .stale(let device, let since):
            return "stale(\(device.name)) since \(since)"
        case .reconnecting(let device, let attempt):
            return "reconnecting(\(device.name)) attempt \(attempt)"
        case .disconnected(let device, let error):
            let name = device?.name ?? "unknown"
            let description = error?.localizedDescription ?? "none"
            return "disconnected(\(name)) error: \(description)"
        }
    }
}
