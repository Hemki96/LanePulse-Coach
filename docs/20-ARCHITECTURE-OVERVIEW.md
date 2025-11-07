---
    title: "Architekturüberblick"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# Architekturüberblick

## Komponenten
- **BLE-Layer (CoreBluetooth + Polar SDK)**: Scannen, Verbinden, Subscriben, Reconnect
- **Analytics-Engine**: Zonen, Aktiv/Pause, Recovery, Trend
- **Data-Layer (CoreData/SQLite)**: HRSamples (1 Hz), Events, Sessions, Mappings
- **UI (SwiftUI)**: Board, Detailpane, Einstellungen, Scoreboard
- **Export**: CSV/JSON-Writer

## Ablauf (vereinfacht)
Scan → Connect → Stream (HR@1Hz) → Vorverarbeitung → UI-Update → Persistenz (Batch) → Export
