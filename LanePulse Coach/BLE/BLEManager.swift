//
//  BLEManager.swift
//  LanePulse Coach
//
//  Basic Bluetooth Low Energy management layer.
//

import Foundation
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif

protocol BLEManaging: AnyObject {
    var isScanning: Bool { get }
    func startScanning()
    func stopScanning()
}

final class BLEManager: NSObject, ObservableObject, BLEManaging {
#if canImport(CoreBluetooth)
    private lazy var centralManager: CBCentralManager = CBCentralManager(delegate: self, queue: nil)
#endif
    @Published private(set) var isScanning: Bool = false
    private let logger: Logging

    init(logger: Logging) {
        self.logger = logger
        super.init()
#if canImport(CoreBluetooth)
        _ = centralManager
#endif
    }

    func startScanning() {
#if canImport(CoreBluetooth)
        guard centralManager.state == .poweredOn else {
            logger.log(level: .warning, message: "Central manager not ready to scan.")
            return
        }
        logger.log(level: .info, message: "Starting BLE scan")
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        isScanning = true
#else
        logger.log(level: .warning, message: "CoreBluetooth not available on this platform.")
#endif
    }

    func stopScanning() {
#if canImport(CoreBluetooth)
        guard isScanning else { return }
        centralManager.stopScan()
        isScanning = false
        logger.log(level: .info, message: "Stopped BLE scan")
#endif
    }
}

#if canImport(CoreBluetooth)
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            logger.log(level: .debug, message: "BLE powered on")
        case .poweredOff:
            logger.log(level: .warning, message: "BLE powered off")
        case .resetting:
            logger.log(level: .warning, message: "BLE resetting")
        case .unauthorized:
            logger.log(level: .error, message: "BLE unauthorized")
        case .unsupported:
            logger.log(level: .error, message: "BLE unsupported on this device")
        case .unknown:
            logger.log(level: .warning, message: "BLE state unknown")
        @unknown default:
            logger.log(level: .warning, message: "BLE state default")
        }
    }
}
#endif
