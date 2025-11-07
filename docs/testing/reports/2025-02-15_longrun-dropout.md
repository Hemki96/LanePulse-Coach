---
    title: "QA Test Report"
    date: "2025-02-15"
    author: "QA Automation"
    scope: "Performance"
---

## Zusammenfassung
- **Testlauf:** 105-minütige Ausdauer-Session mit Dropout-Simulation
- **Build:** Coach 1.4.2 (commit 8f2c1d9)
- **Status:** Mit Abweichungen

## Testobjekte
- Gerät(e): iPad Pro 11" (4. Gen), iPadOS 17.0.3 (21A361)
- Sensoren / Firmware: Polar H10, Firmware 3.3.0
- Umgebung (Pool, Labor, etc.): Indoor-Ruderergometer, abgeschirmte BLE-Zone

## Durchlauf
| Schritt | Erwartung | Ergebnis | Notizen |
| ------- | --------- | -------- | ------- |
| 1 | Sessiondauer ≥ 90 min | ✅ | Gesamtdauer 105 min |
| 2 | Latenz stabil < 160 ms | ✅ | Durchschnitt 148 ms, Peaks 171 ms während Dropout |
| 3 | Geplanter Dropout 45-48 min, Recovery < 10 s | ⚠️ | Dropout 8 s, Reconnect nach 6 s, UI zeigte "Sensor getrennt" Hinweis |
| 4 | Datenlücken < 15 s im Export | ✅ | FIT-Datei enthält 7 s Gap, innerhalb Toleranz |

## Auffälligkeiten
- [ ] Keine Abweichungen
- [x] Abweichungen dokumentiert (siehe unten)

### Details
| ID | Beschreibung | Logs/Screenshots | Status |
| -- | ------------ | ---------------- | ------ |
| QA-18-OBS-01 | Warnbanner blieb 15 s sichtbar nach Reconnect | Video-Notiz im QA-Share | Offen |
| QA-18-OBS-02 | Latenz-Peak 171 ms | [`session_metrics.csv`](artifacts/2025-02-15_longrun-dropout/session_metrics.csv) | Beobachtung |

## Follow-up
- Verantwortliche Person: QA Automation Team
- Tickets/Referenzen: QA-18, UI-112 (bestehendes Ticket für Banner-Auto-Dismiss)
- Nächste Schritte: Banner-Auto-Dismiss prüfen, Regression nach Fix wiederholen
