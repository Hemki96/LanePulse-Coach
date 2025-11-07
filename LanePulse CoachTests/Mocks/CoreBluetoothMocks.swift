import Foundation
import CoreBluetooth

/// Represents a characteristic that can be read from or written to by the mock.
public final class MockCharacteristic {
    public let uuid: CBUUID
    public private(set) var value: Data?

    public init(uuid: CBUUID, value: Data? = nil) {
        self.uuid = uuid
        self.value = value
    }

    public func updateValue(_ newValue: Data?) {
        value = newValue
    }
}

/// Represents a BLE service with associated characteristics.
public struct MockService {
    public let uuid: CBUUID
    public var characteristics: [MockCharacteristic]

    public init(uuid: CBUUID, characteristics: [MockCharacteristic]) {
        self.uuid = uuid
        self.characteristics = characteristics
    }
}

/// Defines the minimal interface that production code must use for a peripheral abstraction.
public protocol PeripheralLike: AnyObject {
    var identifier: UUID { get }
    var name: String? { get }
    var delegate: PeripheralDelegateLike? { get set }

    func discoverServices(_ serviceUUIDs: [CBUUID]?)
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: MockService)
    func setNotifyValue(_ enabled: Bool, for characteristic: MockCharacteristic)
}

/// Delegate abstraction to decouple production code from `CBPeripheralDelegate` at compile time.
public protocol PeripheralDelegateLike: AnyObject {
    func peripheral(_ peripheral: PeripheralLike, didDiscover services: [MockService])
    func peripheral(_ peripheral: PeripheralLike, didDiscoverCharacteristicsFor service: MockService)
    func peripheral(_ peripheral: PeripheralLike, didUpdateValueFor characteristic: MockCharacteristic, error: Error?)
    func peripheral(_ peripheral: PeripheralLike, didUpdateNotificationStateFor characteristic: MockCharacteristic, error: Error?)
}

enum MockBluetoothError: Error {
    case characteristicNotFound
    case serviceNotFound
}

/// Simulates a BLE peripheral and lets tests orchestrate connection and notification lifecycles.
public final class MockPeripheral: PeripheralLike {
    public let identifier: UUID
    public let name: String?
    public weak var delegate: PeripheralDelegateLike?

    private var services: [MockService]
    private var isConnected = false

    public init(identifier: UUID = UUID(), name: String?, services: [MockService]) {
        self.identifier = identifier
        self.name = name
        self.services = services
    }

    public func simulateConnect() {
        isConnected = true
        delegate?.peripheral(self, didDiscover: services)
        services.forEach { service in
            delegate?.peripheral(self, didDiscoverCharacteristicsFor: service)
        }
    }

    public func simulateDisconnect(error: Error? = nil) {
        isConnected = false
        services.flatMap { $0.characteristics }.forEach { characteristic in
            delegate?.peripheral(self, didUpdateNotificationStateFor: characteristic, error: error)
        }
    }

    public func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        guard isConnected else { return }
        if let serviceUUIDs {
            let filtered = services.filter { serviceUUIDs.contains($0.uuid) }
            delegate?.peripheral(self, didDiscover: filtered)
        } else {
            delegate?.peripheral(self, didDiscover: services)
        }
    }

    public func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: MockService) {
        guard isConnected else { return }
        let filtered: [MockCharacteristic]
        if let characteristicUUIDs {
            filtered = service.characteristics.filter { characteristicUUIDs.contains($0.uuid) }
        } else {
            filtered = service.characteristics
        }
        delegate?.peripheral(self, didDiscoverCharacteristicsFor: MockService(uuid: service.uuid, characteristics: filtered))
    }

    public func setNotifyValue(_ enabled: Bool, for characteristic: MockCharacteristic) {
        guard isConnected else { return }
        if enabled {
            delegate?.peripheral(self, didUpdateNotificationStateFor: characteristic, error: nil)
        } else {
            delegate?.peripheral(self, didUpdateNotificationStateFor: characteristic, error: MockBluetoothError.characteristicNotFound)
        }
    }

    public func pushValue(_ data: Data, for characteristicUUID: CBUUID) throws {
        guard isConnected else { throw MockBluetoothError.serviceNotFound }
        guard let serviceIndex = services.firstIndex(where: { mockService in
            mockService.characteristics.contains { $0.uuid == characteristicUUID }
        }) else {
            throw MockBluetoothError.serviceNotFound
        }

        guard let characteristicIndex = services[serviceIndex].characteristics.firstIndex(where: { $0.uuid == characteristicUUID }) else {
            throw MockBluetoothError.characteristicNotFound
        }

        services[serviceIndex].characteristics[characteristicIndex].updateValue(data)
        delegate?.peripheral(self, didUpdateValueFor: services[serviceIndex].characteristics[characteristicIndex], error: nil)
    }
}

/// Utility for assembling services for the mock peripheral in a declarative fashion.
public enum MockServiceBuilder {
    public static func makeService(uuid: CBUUID, characteristics: [MockCharacteristic]) -> MockService {
        MockService(uuid: uuid, characteristics: characteristics)
    }
}
