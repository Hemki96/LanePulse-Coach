//
//  CoreBluetoothAdapter.swift
//  LanePulse Coach
//
//  Wraps CoreBluetooth interactions behind the BLEHardwareAdapter
//  protocol so that BLEController can remain platform-agnostic.
//

import Foundation
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif

#if canImport(CoreBluetooth)
final class CoreBluetoothAdapter: NSObject, BLEHardwareAdapter {
    private enum Constants {
        static let heartRateServiceUUID = CBUUID(string: "180D")
        static let heartRateMeasurementUUID = CBUUID(string: "2A37")
    }

    weak var delegate: BLEHardwareAdapterDelegate?

    private let logger: Logging
    private lazy var centralManager: CBCentralManager = CBCentralManager(delegate: self, queue: nil)
    private var peripheralsByID: [String: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var heartRateCharacteristic: CBCharacteristic?
    private var isScanning: Bool = false

    init(logger: Logging) {
        self.logger = logger
        super.init()
        // Defer central manager creation until the first BLE interaction so app launch
        // does not eagerly spin up CoreBluetooth on the main thread.
    }

    func startScanning() {
        isScanning = true
        guard centralManager.state == .poweredOn else {
            logger.log(level: .warning, message: "CoreBluetooth not powered on; deferring scan")
            return
        }
        centralManager.scanForPeripherals(withServices: nil,
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }

    func connect(to device: BLEDevice) {
        if let peripheral = peripheralsByID[device.id] {
            centralManager.connect(peripheral, options: nil)
        } else if let uuid = UUID(uuidString: device.id) {
            let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            if let peripheral = peripherals.first {
                peripheralsByID[device.id] = peripheral
                centralManager.connect(peripheral, options: nil)
            } else {
                logger.log(level: .warning, message: "Peripheral not cached for device \(device.id)")
            }
        } else {
            logger.log(level: .warning, message: "Invalid UUID for device \(device.id)")
        }
    }

    func disconnect(from device: BLEDevice?) {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    func subscribeToHeartRate(for device: BLEDevice) {
        guard let peripheral = connectedPeripheral else { return }
        if let characteristic = heartRateCharacteristic {
            if !characteristic.isNotifying {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        } else {
            peripheral.discoverServices([Constants.heartRateServiceUUID])
        }
    }

    func cancelHeartRateStreaming(for device: BLEDevice) {
        guard let peripheral = connectedPeripheral,
              let characteristic = heartRateCharacteristic,
              characteristic.isNotifying else { return }
        peripheral.setNotifyValue(false, for: characteristic)
    }

    private func device(from peripheral: CBPeripheral, rssi: NSNumber?) -> BLEDevice {
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
}

extension CoreBluetoothAdapter: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            logger.log(level: .debug, message: "CoreBluetooth powered on")
            if isScanning {
                startScanning()
            }
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

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        peripheralsByID[peripheral.identifier.uuidString] = peripheral
        let device = device(from: peripheral, rssi: RSSI)
        delegate?.hardwareAdapter(self, didDiscover: device)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        heartRateCharacteristic = nil
        let device = device(from: peripheral, rssi: nil)
        delegate?.hardwareAdapter(self, didConnect: device)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let device = device(from: peripheral, rssi: nil)
        delegate?.hardwareAdapter(self, didFailToConnect: device, error: error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectedPeripheral == peripheral {
            connectedPeripheral = nil
            heartRateCharacteristic = nil
        }
        let device = device(from: peripheral, rssi: nil)
        delegate?.hardwareAdapter(self, didDisconnect: device, error: error)
    }
}

extension CoreBluetoothAdapter: CBPeripheralDelegate {
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

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
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

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            logger.log(level: .error, message: "Characteristic update error: \(error.localizedDescription)")
            return
        }
        guard characteristic.uuid == Constants.heartRateMeasurementUUID,
              let data = characteristic.value,
              let bpm = parseHeartRate(from: data) else { return }
        let sample = HeartRateSample(timestamp: Date(), bpm: bpm, isStale: false)
        let device = device(from: peripheral, rssi: nil)
        delegate?.hardwareAdapter(self, didReceiveHeartRate: sample, from: device)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            logger.log(level: .error, message: "Notification state error: \(error.localizedDescription)")
            return
        }
        guard characteristic.uuid == Constants.heartRateMeasurementUUID,
              characteristic.isNotifying else { return }
        logger.log(level: .info, message: "Subscribed to HR notifications for \(peripheral.name ?? "Peripheral")")
    }
}
#endif
