# BLE-Integrations- und Simulations-Tests

## 1. Testziele

| Ziel | Beschreibung |
| --- | --- |
| Verbindungsaufbau | Sicherstellen, dass das Scannen nach Trainingsgeräten, das Auswählen eines Peripheriegeräts und der anschließende Verbindungsaufbau deterministisch ablaufen. |
| Datenstrom | Prüfen, dass eingehende Trainingsdaten (Herzfrequenz, Leistung, Kadenz) mit korrekter Frequenz verarbeitet werden. |
| Reconnect | Wiederaufnahme einer Session nach temporärem Verbindungsverlust, inklusive Resubscribe der benötigten Characteristic-Notifications. |
| Fehlerhandling | Benutzerfeedback und interne Zustände bei Zeitüberschreitungen, ungültigen Datenpaketen oder BLE-Stack-Fehlern. |

## 2. Testfälle

| ID | Kontext | Schritte | Erwartung |
| --- | --- | --- | --- |
| BLE-CON-001 | Kalter Start | App starten, Scan triggern, simuliertes Peripheriegerät auswählen. | Verbindung wird hergestellt, UI zeigt den Status "Verbunden". |
| BLE-STREAM-002 | Laufende Session | Nach dem Verbinden Push von Herzfrequenz-/Leistungswerten über den Mock. | Werte werden mit korrektem Zeitstempel im Session-Log gespeichert. |
| BLE-RECON-003 | Verlust der Verbindung | Während Datenstrom aktiv ist, `simulateDisconnect()` auslösen, nach 5 s `simulateConnect()` erneut aufrufen. | Session wird fortgesetzt, keine Duplikate oder Datenlücken >10 s. |
| BLE-ERR-004 | Fehlerhafte Characteristic | `pushValue` mit ungültigem Frame (CRC-Fehler) senden. | Fehlerzustand wird geloggt, UI zeigt Hinweis und verwirft Frame. |

## 3. Mock- und Simulationsschicht

Die Datei [`LanePulse CoachTests/Mocks/CoreBluetoothMocks.swift`](../../LanePulse%20CoachTests/Mocks/CoreBluetoothMocks.swift) stellt eine abstrahierte BLE-Peripherie bereit:

- `MockPeripheral` emuliert Verbindungszustände und publiziert Services sowie Characteristic-Updates.
- `MockCharacteristic` kapselt einzelne Characteristic-Werte und erlaubt Tests, gezielt neue Datenframes zu liefern.
- `PeripheralLike`/`PeripheralDelegateLike` bilden eine Adapter-Schicht, sodass produktiver Code testbar bleibt, ohne `CoreBluetooth` direkt zu patchen.

Tests können Services deklarativ mit `MockServiceBuilder` erstellen und anschließend `simulateConnect()`, `setNotifyValue(_:for:)` sowie `pushValue(_:for:)` nutzen, um Sessions deterministisch zu steuern.

## 4. UITest-Harness

Im Target `LanePulse CoachUITests` befindet sich der Test [`BLESimulationUITests`](../../LanePulse%20CoachUITests/BLESimulationUITests.swift). Dieser startet einen BLE-Simulator über `UITestBLEHarness` und führt eine Warmup-Session mit simulierten Herzfrequenz-Frames durch.

- Der Harness implementiert `PeripheralDelegateLike`, verdrahtet Notification-Subscriptions und sammelt empfangene Werte.
- Mit `pushValue` lassen sich deterministisch Sequenzen von Frames testen.
- Erweiterbar um weitere Szenarien (Reconnect, Fehlerframes) durch zusätzliche Testmethoden.

## 5. Testausführung

### 5.1 Automatisierte Tests (Simulator)

1. `xcodebuild test -scheme "LanePulse Coach" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing "LanePulse CoachUITests/BLESimulationUITests"`
2. Optional: Zusätzliche Unit-Tests in `LanePulse CoachTests` für Parser und Datenvalidierung ausführen.

### 5.2 Reale Geräte

| Schritt | Details |
| --- | --- |
| Testumgebung | Interne Testlab-Geräte (iPhone + BLE-Trainingsgerät), stabile Stromversorgung, Logging über Xcode Organizer. |
| Vorbereitung | App mit Logging-Build installieren, BLE-Geräte auf Werkseinstellungen zurücksetzen, Firmware-Version dokumentieren. |
| Durchlauf | Testfälle BLE-CON-001 bis BLE-ERR-004 vollständig am Gerät nachstellen. Jede Session protokolliert Start-/Endzeit und relevante Ereignisse. |
| Logging | Konsolen-Logs + in-App-Diagnostik exportieren (`ExportLogs`-Funktion). |
| Abbruchkriterien | Mehr als 3 fehlgeschlagene Reconnects nacheinander, reproduzierbarer Crash, oder Temperaturwarnungen des Geräts. |

### 5.3 Nachbereitung

- Ergebnisse im QA-Template unter `docs/testing/reports` dokumentieren.
- Bei Fehlern Ticket inklusive Log-Export und Firmwarestand erstellen.

## 6. Erweiterungen & Wartung

- Der Mock unterstützt weitere Characteristics, indem zusätzliche `MockCharacteristic`-Instanzen registriert werden.
- Für Integration mit echten `CBPeripheral`-Instanzen kann ein Adapter erstellt werden, der `PeripheralLike` implementiert und die Produktivklasse wrappt.
- Reconnect-Tests sollten zusätzlich Netzwerk-/Bluetooth-Interferenzen simulieren (z. B. Faraday Bag, Störsender im Testlab).

