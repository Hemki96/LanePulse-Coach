//
//  BLEManager.swift
//  LanePulse Coach
//
//  Unified wrapper around Polar BLE SDK and CoreBluetooth with
//  connection state machine, stale detection, reconnect handling,
//  and a 1 Hz resampling pipeline.
//

import Foundation
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif

#if canImport(PolarBleSdk)
import PolarBleSdk
#if canImport(RxSwift)
import RxSwift
#endif
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

final class BLEManager: NSObject, ObservableObject, BLEManaging {
    private enum Constants {
#if canImport(CoreBluetooth)
        static let heartRateServiceUUID = CBUUID(string: "180D")
        static let heartRateMeasurementUUID = CBUUID(string: "2A37")
#endif
        static let staleEmissionThreshold = 3
        static let maxReconnectAttempts = 3
    }

    @Published private(set) var isScanning: Bool = false
    @Published private(set) var discoveredDevices: [BLEDevice] = []
    @Published private(set) var connectionState: BLEConnectionState = .idle
    @Published private(set) var lastResampledSample: ResampledHeartRateSample?

    private let logger: Logging
    private let resampler = HeartRateResampler(interval: 1.0)
    private var devicesByID: [String: BLEDevice] = [:]
    private var consecutiveStaleEmissions: Int = 0
    private var reconnectAttempts: Int = 0
    private var isPerformingReconnect: Bool = false
    private var shouldAttemptReconnection: Bool = false
    private var expectedDisconnect: Bool = false
    private var currentDevice: BLEDevice?

#if canImport(CoreBluetooth)
    private lazy var centralManager: CBCentralManager = CBCentralManager(delegate: self, queue: nil)
    private var peripheralsByID: [String: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var heartRateCharacteristic: CBCharacteristic?
#endif

#if canImport(PolarBleSdk)
    private lazy var polarApi: PolarBleApi = {
        let api = PolarBleApiDefaultImpl.polarImplementation(queue: .main, features: Set([.hr]))
        api.observer = self
        api.powerStateObserver = self
        api.deviceHrObserver = self
        return api
    }()
#if canImport(RxSwift)
    private var polarHrDisposable: Disposable?
#endif
#endif

    init(logger: Logging) {
        self.logger = logger
        super.init()
        resampler.onResampledSample = { [weak self] sample in
            self?.handleResampledSample(sample)
        }
#if canImport(CoreBluetooth)
        _ = centralManager
#endif
    }

    func startScanning() {
        guard !isScanning else { return }
        logger.log(level: .info, message: "Starting BLE scan")
        updateState(.scanning)
        isScanning = true
#if canImport(CoreBluetooth)
        guard centralManager.state == .poweredOn else {
            logger.log(level: .warning, message: "Central manager not powered on")
            updateState(.idle)
            isScanning = false
            return
        }
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
#endif
#if canImport(PolarBleSdk)
        polarApi.startAutoConnectToDevice(-55, service: .heartRate)
#endif
    }

    func stopScanning() {
        guard isScanning else { return }
        logger.log(level: .info, message: "Stopping BLE scan")
#if canImport(CoreBluetooth)
        centralManager.stopScan()
#endif
#if canImport(PolarBleSdk)
        polarApi.stopAutoConnectToDevice()
#endif
        isScanning = false
        if case .scanning = connectionState {
            updateState(.idle)
        }
    }

    func connect(to device: BLEDevice) {
        currentDevice = device
        reconnectAttempts = 0
        isPerformingReconnect = false
        shouldAttemptReconnection = true
        expectedDisconnect = false
        logger.log(level: .info, message: "Connecting to device \(device.name) [\(device.id)]")
        updateState(.connecting(device: device))
        attemptConnect(to: device)
    }

    func disconnect() {
        guard let device = currentDevice else { return }
        logger.log(level: .info, message: "Disconnecting from device \(device.name)")
        shouldAttemptReconnection = false
        expectedDisconnect = true
        resampler.stop()
        resampler.reset()
        consecutiveStaleEmissions = 0
        reconnectAttempts = 0
        isPerformingReconnect = false
#if canImport(PolarBleSdk)
        teardownPolarStream()
        polarApi.disconnectFromDevice(device.id)
#endif
        handleDisconnect(for: device, error: nil)
#if canImport(CoreBluetooth)
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        heartRateCharacteristic = nil
#endif
        currentDevice = nil
    }

    func subscribeToHeartRate() {
        guard let device = currentDevice else { return }
        logger.log(level: .info, message: "Subscribing to heart rate for device \(device.name)")
        resampler.start()
        if case .connected = connectionState {
            updateState(.streaming(device: device))
        }
#if canImport(PolarBleSdk)
#if canImport(RxSwift)
        polarHrDisposable?.dispose()
        polarHrDisposable = polarApi.startHrStreaming(device.id)
            .subscribe(onNext: { [weak self] data in
                self?.processPolarHeartRate(data, for: device)
            }, onError: { [weak self] error in
                self?.logger.log(level: .error, message: "Polar HR stream error: \(error.localizedDescription)")
            })
#else
        logger.log(level: .warning, message: "Polar SDK detected but RxSwift not available; expecting hrValueReceived callbacks once streaming is configured externally.")
#endif
#endif
#if canImport(CoreBluetooth)
        guard let peripheral = connectedPeripheral else { return }
        if let characteristic = heartRateCharacteristic {
            if !characteristic.isNotifying {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        } else {
            peripheral.discoverServices([Constants.heartRateServiceUUID])
        }
#endif
    }

    private func attemptConnect(to device: BLEDevice) {
#if canImport(PolarBleSdk)
        polarApi.connectToDevice(device.id)
#endif
#if canImport(CoreBluetooth)
        if let peripheral = peripheralsByID[device.id] {
            centralManager.connect(peripheral, options: nil)
        } else {
            logger.log(level: .warning, message: "Peripheral not cached for device \(device.id)")
        }
#endif
    }

    private func handleResampledSample(_ sample: ResampledHeartRateSample) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastResampledSample = sample
            guard let device = self.currentDevice else { return }

            if sample.isStale {
                self.consecutiveStaleEmissions += 1
                if case .streaming = self.connectionState, self.consecutiveStaleEmissions == 1 {
                    self.updateState(.stale(device: device, since: sample.timestamp))
                }
                if self.shouldAttemptReconnection,
                   self.consecutiveStaleEmissions >= Constants.staleEmissionThreshold,
                   self.reconnectAttempts < Constants.maxReconnectAttempts {
                    self.reconnectAttempts += 1
                    self.initiateReconnect(for: device)
                }
            } else {
                self.consecutiveStaleEmissions = 0
                if case .stale = self.connectionState {
                    self.updateState(.streaming(device: device))
                } else if case .connected = self.connectionState {
                    self.updateState(.streaming(device: device))
                }
            }
        }
    }

    private func initiateReconnect(for device: BLEDevice) {
        guard !isPerformingReconnect else { return }
        logger.log(level: .warning, message: "Attempting reconnect #\(reconnectAttempts) for device \(device.name)")
        isPerformingReconnect = true
        updateState(.reconnecting(device: device, attempt: reconnectAttempts))
#if canImport(PolarBleSdk)
        teardownPolarStream()
        polarApi.disconnectFromDevice(device.id)
#endif
#if canImport(CoreBluetooth)
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        } else {
            attemptConnect(to: device)
        }
#else
        attemptConnect(to: device)
#endif
    }

    private func handleDisconnect(for device: BLEDevice, error: Error?) {
        updateState(.disconnected(device: device, error: error))
#if canImport(PolarBleSdk)
        teardownPolarStream()
#endif
        if shouldAttemptReconnection,
           !expectedDisconnect,
           reconnectAttempts < Constants.maxReconnectAttempts {
            logger.log(level: .info, message: "Scheduling reconnect for \(device.name)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self else { return }
                guard self.shouldAttemptReconnection else { return }
                self.attemptConnect(to: device)
            }
        } else {
            shouldAttemptReconnection = false
            currentDevice = nil
        }
    }

#if canImport(PolarBleSdk)
    private func teardownPolarStream() {
#if canImport(RxSwift)
        polarHrDisposable?.dispose()
        polarHrDisposable = nil
#endif
    }
#endif

    private func updateState(_ newState: BLEConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.connectionState = newState
            self.logger.log(level: .debug, message: "BLE state transitioned to \(newState)")
        }
    }

    private func updateDiscoveredDevices(with device: BLEDevice) {
        devicesByID[device.id] = device
        let sorted = devicesByID.values.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        DispatchQueue.main.async { [weak self] in
            self?.discoveredDevices = sorted
        }
    }

#if canImport(CoreBluetooth)
    private func coreBluetoothDevice(from peripheral: CBPeripheral, rssi: NSNumber?) -> BLEDevice {
        let name = peripheral.name ?? "Polar Sensor"
        let value = rssi?.intValue
        return BLEDevice(id: peripheral.identifier.uuidString, name: name, rssi: value)
    }

    private func parseHeartRate(from data: Data) -> Int? {
        guard !data.isEmpty else { return nil }
        let flags = data[0]
        let isSixteenBit = (flags & 0x01) != 0
        if isSixteenBit {
            guard data.count >= 3 else { return nil }
            let value = UInt16(data[1]) | UInt16(data[2]) << 8
            return Int(value)
        } else {
            guard data.count >= 2 else { return nil }
            return Int(data[1])
        }
    }
#endif

#if canImport(PolarBleSdk)
    private func processPolarHeartRate(_ data: PolarHrData, for device: BLEDevice) {
        guard let sample = data.samples.first else { return }
        let hrSample = HeartRateSample(timestamp: Date(), bpm: Int(sample.hr), isStale: false)
        resampler.receive(hrSample)
        updateState(.streaming(device: device))
    }
#endif
}

#if canImport(CoreBluetooth)
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            logger.log(level: .debug, message: "CoreBluetooth powered on")
        case .poweredOff:
            logger.log(level: .warning, message: "CoreBluetooth powered off")
        case .resetting:
            logger.log(level: .warning, message: "CoreBluetooth resetting")
        case .unauthorized:
            logger.log(level: .error, message: "CoreBluetooth unauthorized")
        case .unsupported:
            logger.log(level: .error, message: "CoreBluetooth unsupported")
        case .unknown:
            logger.log(level: .warning, message: "CoreBluetooth state unknown")
        @unknown default:
            logger.log(level: .warning, message: "CoreBluetooth state default")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        peripheralsByID[peripheral.identifier.uuidString] = peripheral
        let device = coreBluetoothDevice(from: peripheral, rssi: RSSI)
        updateDiscoveredDevices(with: device)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        let device = coreBluetoothDevice(from: peripheral, rssi: nil)
        currentDevice = device
        logger.log(level: .info, message: "Connected to \(device.name)")
        resampler.reset()
        consecutiveStaleEmissions = 0
        updateState(.connected(device: device))
        if shouldAttemptReconnection {
            subscribeToHeartRate()
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.log(level: .error, message: "Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        if let device = currentDevice {
            handleDisconnect(for: device, error: error)
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let device = coreBluetoothDevice(from: peripheral, rssi: nil)
        connectedPeripheral = nil
        heartRateCharacteristic = nil
        logger.log(level: .warning, message: "Disconnected from \(device.name)")
        isPerformingReconnect = false
        if expectedDisconnect {
            updateState(.disconnected(device: device, error: error))
            expectedDisconnect = false
            shouldAttemptReconnection = false
            currentDevice = nil
        } else {
            handleDisconnect(for: device, error: error)
        }
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            logger.log(level: .error, message: "Service discovery error: \(error.localizedDescription)")
            return
        }
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Constants.heartRateServiceUUID {
            peripheral.discoverCharacteristics([Constants.heartRateMeasurementUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            logger.log(level: .error, message: "Characteristic discovery error: \(error.localizedDescription)")
            return
        }
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == Constants.heartRateMeasurementUUID {
            heartRateCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            logger.log(level: .error, message: "Characteristic update error: \(error.localizedDescription)")
            return
        }
        guard characteristic.uuid == Constants.heartRateMeasurementUUID,
              let data = characteristic.value,
              let bpm = parseHeartRate(from: data) else { return }
        let sample = HeartRateSample(timestamp: Date(), bpm: bpm, isStale: false)
        resampler.receive(sample)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            logger.log(level: .error, message: "Notification state error: \(error.localizedDescription)")
            return
        }
        guard characteristic.uuid == Constants.heartRateMeasurementUUID,
              characteristic.isNotifying,
              let device = currentDevice else { return }
        logger.log(level: .info, message: "Subscribed to HR notifications for \(device.name)")
        updateState(.streaming(device: device))
    }
}
#endif

#if canImport(PolarBleSdk)
extension BLEManager: PolarBleApiObserver {
    func deviceConnecting(_ polarDeviceInfo: PolarDeviceInfo) {
        let device = BLEDevice(id: polarDeviceInfo.deviceId, name: polarDeviceInfo.name, rssi: polarDeviceInfo.rssi)
        currentDevice = device
        updateState(.connecting(device: device))
    }

    func deviceConnected(_ polarDeviceInfo: PolarDeviceInfo) {
        let device = BLEDevice(id: polarDeviceInfo.deviceId, name: polarDeviceInfo.name, rssi: polarDeviceInfo.rssi)
        currentDevice = device
        resampler.reset()
        consecutiveStaleEmissions = 0
        updateState(.connected(device: device))
    }

    func deviceDisconnected(_ polarDeviceInfo: PolarDeviceInfo) {
        let device = BLEDevice(id: polarDeviceInfo.deviceId, name: polarDeviceInfo.name, rssi: polarDeviceInfo.rssi)
        isPerformingReconnect = false
        handleDisconnect(for: device, error: nil)
    }

    func deviceDiscovered(_ polarDeviceInfo: PolarDeviceInfo) {
        let device = BLEDevice(id: polarDeviceInfo.deviceId, name: polarDeviceInfo.name, rssi: polarDeviceInfo.rssi)
        updateDiscoveredDevices(with: device)
    }
}

extension BLEManager: PolarBleApiPowerStateObserver {
    func blePowerOn() {
        logger.log(level: .debug, message: "Polar SDK BLE power on")
    }

    func blePowerOff() {
        logger.log(level: .warning, message: "Polar SDK BLE power off")
    }
}

extension BLEManager: PolarBleApiDeviceHrObserver {
    func hrValueReceived(_ identifier: String, data: PolarHrData) {
        guard let device = currentDevice, device.id == identifier else { return }
        processPolarHeartRate(data, for: device)
    }
}
#endif

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

