# LanePulse Coach

LanePulse Coach ist eine iPad-App für Schwimmtrainer:innen, die Live-Herzfrequenzdaten von bis zu acht Athlet:innen sammelt, visualisiert und für spätere Analyse exportiert. Der Fokus der aktuellen MVP-Iteration liegt auf einer robusten BLE-Anbindung, Offline-Fähigkeit sowie klaren Aktiv-/Pause-Indikatoren.

## Projektüberblick
- **Plattform:** iPadOS (SwiftUI + Core Data)
- **Konnektivität:** Bluetooth Low Energy (BLE) Sensoren wie Polar H10
- **Kernfunktionen:** Live-Dashboard, Aktivitäts-/Recovery-Analyse, Export der Trainingssessions

## Repository-Struktur
```
.
├── LanePulse Coach/           # SwiftUI-App-Quellcode
├── LanePulse CoachTests/      # Unit- und Integrationstests
├── LanePulse CoachUITests/    # UI-Test-Suites
├── docs/                      # Produkt-, Architektur- und QA-Dokumentation
└── README.md                  # Dieses Dokument
```

Wichtige Einstiegspunkte:
- `LanePulse Coach/Configuration/AppContainer.swift` erstellt Abhängigkeiten und Seed-Daten.
- `LanePulse Coach/Analytics/` enthält die Aktiv-/Pause-Logik sowie Vorverarbeitung.
- `LanePulse Coach/Data/` bündelt Core-Data-Modelle, Parser und Repositories.

## Voraussetzungen
- Xcode 15.2 oder neuer
- iPadOS 17 SDK
- Ein registriertes Apple Developer Team (für Builds auf Geräte)

## Projekt bauen & starten
1. `LanePulse Coach.xcodeproj` in Xcode öffnen.
2. Ziel **LanePulse Coach** auswählen.
3. Ein iPad (Simulator oder Gerät) mit iPadOS 17 wählen.
4. Projekt mit `Cmd + R` starten.

Für UI-Tests steht das Schema **LanePulse CoachUITests** zur Verfügung. Unit- und Integrationstests laufen über `Cmd + U` oder die Kommandozeile:

```bash
xcodebuild \
  -scheme "LanePulse Coach" \
  -destination "platform=iOS Simulator,name=iPad Pro (11-inch) (4th generation)" \
  test
```

## Dokumentation
Der Ordner [`docs/`](docs/00-README.md) enthält eine kuratierte Dokumentationssammlung. Empfohlene Lesereihenfolge:
1. [Vision & Produktbrief](docs/01-VISION.md) → [02-PRODUCT-BRIEF](docs/02-PRODUCT-BRIEF.md)
2. [Anforderungen & NFRs](docs/10-REQUIREMENTS.md), [13-NFRS](docs/13-NFRS.md)
3. [Architekturüberblick](docs/20-ARCHITECTURE-OVERVIEW.md) + [Entscheidungen](docs/52-DECISION-LOG-ADR.md)
4. [Datenmodell](docs/22-DATA-MODEL.md) & [Aktivitätsalgorithmus](docs/23-ALGORITHMS-ACTIVITY-PAUSE.md)
5. [Teststrategie](docs/40-TEST-STRATEGY.md) inkl. [Testmatrix](docs/testing/test-matrix.md)

## Qualitätssicherung
- Tests: siehe [Teststrategie](docs/40-TEST-STRATEGY.md) und [Testfälle](docs/41-TEST-CASES.md)
- BLE-spezifische QA: [docs/testing/ble-integration.md](docs/testing/ble-integration.md)
- Ergebnisberichte werden unter [`docs/testing/reports/`](docs/testing/reports/README.md) archiviert.

## Beiträge
Bitte vor Pull Requests den [Contribution Guide](docs/60-CONTRIBUTING.md) und die [Swift Coding Standards](docs/61-CODING-STANDARDS-SWIFT.md) lesen. Issues und ADRs werden im `docs/`-Ordner gepflegt; neue Architekturentscheidungen folgen der [ADR-Vorlage](docs/templates/TEMPLATE-ADR.md).

