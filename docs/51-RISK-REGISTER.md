---
    title: "Risiko-Register"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.2.0"
    updated: "2025-11-08"
---

# Risiko-Register (Auszug)

| Risiko | Auswirkung | Gegenmaßnahme | Status |
|--------|------------|---------------|--------|
| BLE im Wasser | Dropouts & Messfehler | Robuste Reconnect-Logik, UI-Status "stale", Feldtests pro Woche | Aktiv (laufende Beobachtung) |
| Drittanbieter-Sensoren | API/SDK-Unsicherheit | Fokus auf Polar/Garmin, Kompatibilitätstests gemäß [Testmatrix](testing/test-matrix.md) | Aktiv |
| Hardware-Varianten iPad | Unterschiedliche Performance, Displaygrößen | [Testmatrix](testing/test-matrix.md) pflegen, Snapshot-Vergleiche | Mitigation läuft |
| QA-Nachweise | Fehlende Dokumentation | QA-Berichte unter [testing/reports](testing/reports/README.md) pflegen, CI-Artefakte archivieren | Aktiv |

## Anmerkungen
- Testmatrix erstellt (Stand siehe Link oben); Abdeckung für iPad mini offen → Ticket QA-17.
- CI/CD-Workflows in Planung (siehe [62-CI-CD.md](62-CI-CD.md)); Abhängigkeit zu Signatur-Zertifikaten.
