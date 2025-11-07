---
    title: "QA Test Report"
    date: "2025-02-15"
    author: "QA Automation"
    scope: "Field"
---

## Zusammenfassung
- **Testlauf:** BLE-Interoperabilität iPad mini (6. Gen) mit Garmin HRM-Pro Plus (FW 2.5)
- **Build:** Coach 1.4.2 (commit 8f2c1d9)
- **Status:** Bestanden

## Testobjekte
- Gerät(e): iPad mini (6. Gen), iPadOS 17.1 (21B74)
- Sensoren / Firmware: Garmin HRM-Pro Plus, Firmware 2.50
- Umgebung (Pool, Labor, etc.): Indoor-Laufbandlabor, 22°C, 45% r. F.

## Durchlauf
| Schritt | Erwartung | Ergebnis | Notizen |
| ------- | --------- | -------- | ------- |
| 1 | Sensor-Kopplung innerhalb von 30s | ✅ | Initiale Kopplung nach 18s, Anzeige in Coach-App |
| 2 | Herzfrequenz-Stream stabil (>98% Samples) | ✅ | 99.8% Sample-Abdeckung laut CSV-Analyse |
| 3 | Live-Latenz < 160 ms | ✅ | Durchschnitt 150 ms (siehe Anhang) |
| 4 | Session-Export als FIT-Datei | ✅ | Export erfolgreich, FIT unter QA-Share abgelegt |

## Auffälligkeiten
- [x] Keine Abweichungen
- [ ] Abweichungen dokumentiert (siehe unten)

### Details
| ID | Beschreibung | Logs/Screenshots | Status |
| -- | ------------ | ---------------- | ------ |
| QA-17-OBS-01 | BLE-Metriken | [`ble_metrics.csv`](artifacts/2025-02-15_ipad-mini-garmin/ble_metrics.csv) | Abgeschlossen |

## Follow-up
- Verantwortliche Person: QA Automation Team
- Tickets/Referenzen: QA-17
- Nächste Schritte: Kombination in Regression-Suite aufnehmen, nächster Review 2025-Q2
