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

- **Unit-Tests**: Algorithmik (EWMA, Hysterese), Parser, Exporte; Coverage-Ziel ≥ 80 % kritischer Module
- **Integration**: BLE-Mocks/Simulator + echte Polar-Sensoren; Dropout-Szenarien automatisiert (Ticket QA-19)
- **UI-Tests**: Snapshot/UITest Board & Scoreboard (nach Matrix [testing/test-matrix.md](testing/test-matrix.md)); visuelle Regression per Baseline Review
- **Lasttest**: 8 parallele Streams, Dropouts, Reconnect-Pfade; Monitoring via MetricKit-Export
- **Feldtests**: Siehe 42-FIELD-TEST-PROTOCOL-POOL; Nachverfolgung in Ticket QA-21
- **Dokumentation**: Ergebnisse als Berichte in [testing/reports](testing/reports/README.md) und Referenz in Release-Checklist
