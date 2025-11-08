---
title: "Teststrategie"
owner: "Christian Hemker"
status: "Approved"
version: "1.0.0"
updated: "2025-02-14"
approved:
  date: "2025-02-14"
  by:
    - "Christian Hemker (Product Owner)"
    - "Amelia Vogt (QA Lead)"
---

# Teststrategie

- **Unit-Tests**: Algorithmik (EWMA, Hysterese), Parser, Exporte. Jede neue Core-Logic-Funktion erhält mindestens einen Positiv- und Negativfall. Coverage-Ziel ≥ 80 % für kritische Module; `xccov view` wird in CI ausgewertet und als Trend im QA-Dashboard dokumentiert.
- **UI-Tests**: XCTestCase + SwiftUI Testing Library auf Smoke-Screens (Onboarding, Board, Scoreboard) inkl. Accessibility-Asserts. Ausführung in Simulator Farm (iPad Pro 11" iOS 17) je Pull Request.
- **Snapshot-Tests**: Basierend auf `XCTest` + `iOSSnapshotTestCase`. Nightly Runs generieren Baselines für Dark/Light-Mode und Deutsch/Englisch; Abweichungen werden im QA-Channel geteilt und müssen vom Design bestätigt werden.
- **Integration**: BLE-Mocks/Simulator + echte Polar-Sensoren; Dropout-Szenarien automatisiert (Ticket QA-19)
- **Lasttest**: 8 parallele Streams, Dropouts, Reconnect-Pfade; Monitoring via MetricKit-Export
- **Feldtests**: Siehe 42-FIELD-TEST-PROTOCOL-POOL; Nachverfolgung in Ticket QA-21
- **Dokumentation**: Ergebnisse als Berichte in [testing/reports](testing/reports/README.md) und Referenz in Release-Checklist
