import XCTest
import CoreBluetooth
@testable import LanePulse_Coach

/// Exercises the BLE simulation layer to verify that connection workflows remain stable.
final class BLESimulationUITests: XCTestCase {
    func testSimulatedWarmupSession() throws {
        let heartRateUUID = CBUUID(string: "2A37")
        let powerUUID = CBUUID(string: "2A63")
        let peripheral = MockPeripheral(
            name: "Simulated Trainer",
            services: [
                MockServiceBuilder.makeService(
                    uuid: CBUUID(string: "180D"),
                    characteristics: [
                        MockCharacteristic(uuid: heartRateUUID),
                        MockCharacteristic(uuid: powerUUID)
                    ]
                )
            ]
        )

        let harness = UITestBLEHarness(peripheral: peripheral)
        harness.connect()

        let warmupSamples: [UInt8] = [110, 112, 115, 118]
        try warmupSamples.forEach { sample in
            try peripheral.pushValue(Data([sample]), for: heartRateUUID)
        }

        XCTAssertEqual(harness.receivedHeartRate.count, warmupSamples.count)
    }
}

/// Glue layer that mimics the app's BLE session orchestration without launching the full UI.
final class UITestBLEHarness: PeripheralDelegateLike {
    private let peripheral: MockPeripheral
    private(set) var receivedHeartRate: [UInt8] = []

    init(peripheral: MockPeripheral) {
        self.peripheral = peripheral
        self.peripheral.delegate = self
    }

    func connect() {
        peripheral.simulateConnect()
    }

    func peripheral(_ peripheral: PeripheralLike, didDiscover services: [MockService]) {
        // In UI tests we can inspect discovered services if needed.
    }

    func peripheral(_ peripheral: PeripheralLike, didDiscoverCharacteristicsFor service: MockService) {
        service.characteristics.forEach { characteristic in
            if characteristic.uuid == CBUUID(string: "2A37") {
                self.peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: PeripheralLike, didUpdateValueFor characteristic: MockCharacteristic, error: Error?) {
        guard error == nil, let value = characteristic.value?.first else { return }
        receivedHeartRate.append(value)
    }

    func peripheral(_ peripheral: PeripheralLike, didUpdateNotificationStateFor characteristic: MockCharacteristic, error: Error?) {
        // Hooks for reconnect logic assertions.
    }
}
