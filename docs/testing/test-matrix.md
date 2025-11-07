---
title: "Testmatrix"
owner: "QA Team"
status: "Approved"
version: "1.0.0"
updated: "2025-02-14"
approved:
  date: "2025-02-14"
  by:
    - "Amelia Vogt (QA Lead)"
    - "Christian Hemker (Product Owner)"
---

# Testmatrix LanePulse Coach

## Geräte & Betriebssysteme
| Priorität | Gerät | iPadOS | Begründung |
|-----------|-------|--------|-----------|
| P0 | iPad Pro 11" (4. Gen) | 17.0, 17.1 | Referenzgerät im Training, Zielplattform für Demo |
| P0 | iPad (10. Gen) | 17.0 | Günstigste Geräteklasse, größter Pool |
| P1 | iPad Air (5. Gen) | 17.1 | Alternative Hardware im Verein |
| P2 | iPad mini (6. Gen) | 17.1 | Randfall, kleinere UI |

## Sensoren & Firmwarestände
| Priorität | Sensor | Firmware | Notizen |
|-----------|--------|----------|---------|
| P0 | Polar H10 | ≥ 3.2.0 | Referenzsensor, komplette Funktionalität |
| P1 | Garmin HRM-Pro Plus | ≥ 2.5 | Getestet für Interoperabilität, nur Herzfrequenz |
| P2 | Suunto Smart Sensor | ≥ 1.2 | Nur wenn verfügbar, Fokus auf Kompatibilität |
| P2 | Garmin HRM-Dual | ≥ 3.4 | Backup-Sensor für Vereinsbestand |

## Testarten vs. Geräteabdeckung
| Testart | Pflichtgeräte | Zusatzgeräte |
|---------|---------------|--------------|
| Unit-/Integrationstests (Simulator) | iPad Pro 11" (Simulator) | - |
| BLE-Regression (real) | iPad Pro 11" + Polar H10 | iPad (10. Gen) |
| UI-Regression (Snapshot) | iPad Pro 11" (Simulator) | iPad Air |
| Feldtest Pool | iPad (10. Gen) + Polar H10 (x4) | Garmin HRM-Pro |
| Langzeittest | iPad Pro 11" + Polar H10 | iPad mini (6. Gen) |

## Status-Tracking
- Abgedeckte Kombinationen werden in [`docs/testing/reports`](reports/README.md) mit Checklisten dokumentiert.
- Offene Lücken (Ticket-Backlog):
  - [ ] iPad mini (6. Gen) + Garmin HRM-Pro Plus (Firmware 2.5) → Ticket QA-17
  - [ ] Ausdauer-Session > 90 min mit Dropout-Simulation → Ticket QA-18

## Wartung
- Matrix vierteljährlich überprüfen (QA-Meeting).
- Neue Sensoren/Firmware über Produktmanagement priorisieren.
