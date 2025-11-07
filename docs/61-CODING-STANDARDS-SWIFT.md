---
    title: "Coding Standards (Swift)"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# Coding Standards (Swift/SwiftUI)

- Architektur: klare Layer (BLE, Analytics, Data, UI)
- Swift Concurrency gezielt, UI @MainActor, BLE auf Background
- Fehlerbehandlung: Result/throws; keine stillen Fails
- Test-Doubles für BLE; Protokolle statt konkreter Typen
