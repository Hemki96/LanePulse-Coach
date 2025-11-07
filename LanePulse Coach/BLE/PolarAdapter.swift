//
//  PolarAdapter.swift
//  LanePulse Coach
//
//  Wraps the Polar BLE SDK to conform to BLEHardwareAdapter,
//  isolating SDK-specific behaviors from BLEController.
//

import Foundation
#if canImport(PolarBleSdk)
import PolarBleSdk
#if canImport(RxSwift)
import RxSwift
#endif
#endif

#if canImport(PolarBleSdk)
final class PolarAdapter: NSObject, BLEHardwareAdapter {
    weak var delegate: BLEHardwareAdapterDelegate?

    private let logger: Logging
    private lazy var api: PolarBleApi = {
        let api = PolarBleApiDefaultImpl.polarImplementation(queue: .main, features: Set([.hr]))
        api.observer = self
        api.powerStateObserver = self
        api.deviceHrObserver = self
        return api
    }()
    private var activeDeviceId: String?
    private var activeDevice: BLEDevice?
    #if canImport(RxSwift)
    private var hrDisposable: Disposable?
    #endif

    init(logger: Logging) {
        self.logger = logger
        super.init()
        // Delay Polar SDK bootstrapping until needed to keep launch work minimal.
    }

    func startScanning() {
        api.startAutoConnectToDevice(-55, service: .heartRate)
    }

    func stopScanning() {
        api.stopAutoConnectToDevice()
    }

    func connect(to device: BLEDevice) {
        activeDeviceId = device.id
        activeDevice = device
        api.connectToDevice(device.id)
    }

    func disconnect(from device: BLEDevice?) {
        let identifier = device?.id ?? activeDeviceId
        guard let identifier else { return }
        if let device { activeDevice = device }
        cancelHeartRateStreaming(for: activeDevice ?? BLEDevice(id: identifier, name: device?.name ?? identifier, rssi: device?.rssi))
        api.disconnectFromDevice(identifier)
    }

    func subscribeToHeartRate(for device: BLEDevice) {
        activeDeviceId = device.id
        activeDevice = device
        #if canImport(RxSwift)
        hrDisposable?.dispose()
        hrDisposable = api.startHrStreaming(device.id)
            .subscribe(onNext: { [weak self] data in
                self?.forwardHeartRate(data, for: device)
            }, onError: { [weak self] error in
                self?.logger.log(level: .error, message: "Polar HR stream error: \(error.localizedDescription)")
            })
        #else
        logger.log(level: .warning, message: "Polar SDK detected but RxSwift unavailable; expect hrValueReceived callbacks.")
        #endif
    }

    func cancelHeartRateStreaming(for device: BLEDevice) {
        #if canImport(RxSwift)
        hrDisposable?.dispose()
        hrDisposable = nil
        #endif
    }

    private func device(from info: PolarDeviceInfo) -> BLEDevice {
        BLEDevice(id: info.deviceId, name: info.name, rssi: info.rssi)
    }

    private func forwardHeartRate(_ data: PolarHrData, for device: BLEDevice) {
        guard let sample = data.samples.first else { return }
        let hrSample = HeartRateSample(timestamp: Date(), bpm: Int(sample.hr), isStale: false)
        delegate?.hardwareAdapter(self, didReceiveHeartRate: hrSample, from: device)
    }
}

extension PolarAdapter: PolarBleApiObserver {
    func deviceConnecting(_ polarDeviceInfo: PolarDeviceInfo) {
        let device = device(from: polarDeviceInfo)
        activeDeviceId = device.id
        activeDevice = device
        delegate?.hardwareAdapter(self, didStartConnecting: device)
    }

    func deviceConnected(_ polarDeviceInfo: PolarDeviceInfo) {
        let device = device(from: polarDeviceInfo)
        activeDeviceId = device.id
        activeDevice = device
        delegate?.hardwareAdapter(self, didConnect: device)
    }

    func deviceDisconnected(_ polarDeviceInfo: PolarDeviceInfo) {
        let device = device(from: polarDeviceInfo)
        if activeDeviceId == device.id {
            activeDeviceId = nil
            activeDevice = nil
        }
        delegate?.hardwareAdapter(self, didDisconnect: device, error: nil)
    }

    func deviceDiscovered(_ polarDeviceInfo: PolarDeviceInfo) {
        let device = device(from: polarDeviceInfo)
        delegate?.hardwareAdapter(self, didDiscover: device)
    }
}

extension PolarAdapter: PolarBleApiPowerStateObserver {
    func blePowerOn() {
        logger.log(level: .debug, message: "Polar SDK BLE power on")
    }

    func blePowerOff() {
        logger.log(level: .warning, message: "Polar SDK BLE power off")
    }
}

extension PolarAdapter: PolarBleApiDeviceHrObserver {
    func hrValueReceived(_ identifier: String, data: PolarHrData) {
        guard let activeDeviceId, activeDeviceId == identifier else { return }
        let device = activeDevice ?? BLEDevice(id: identifier, name: "Polar Sensor", rssi: nil)
        forwardHeartRate(data, for: device)
    }
}
#endif
