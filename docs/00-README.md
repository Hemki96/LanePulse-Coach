---
    title: "Dokumentenübersicht"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.2.0"
    updated: "2025-11-08"
---

# LanePulse Coach – Dokumentenübersicht

Willkommen im **/docs**-Ordner. Diese Sammlung beschreibt Vision, Architektur, Anforderungen und Qualitätssicherung der iPad-App **LanePulse Coach** für Live-Pulsmonitoring im Schwimmtraining.

## Wie lesen?
- **Schnellstart:** 01-VISION → 02-PRODUCT-BRIEF → 10-REQUIREMENTS → 20-ARCHITECTURE-OVERVIEW
- **Technik-Details:** 21-BLE-CONNECTIVITY → 22-DATA-MODEL → 23-ALGORITHMS-ACTIVITY-PAUSE
- **Qualität:** 24-PERFORMANCE-BUDGET → 40-TEST-STRATEGY → 41-TEST-CASES → 42-FIELD-TEST-PROTOCOL-POOL

## Neu hinzugefügt
- Projektweite Einstiegsanleitung: [README.md](../README.md)
- Aktualisiertes Datenmodell (siehe [22-DATA-MODEL.md](22-DATA-MODEL.md))
- Konkrete Aktiv/Pause-Parameter ([23-ALGORITHMS-ACTIVITY-PAUSE.md](23-ALGORITHMS-ACTIVITY-PAUSE.md))
- ADR-Verzeichnis unter [decisions/](decisions/) mit Log in [52-DECISION-LOG-ADR.md](52-DECISION-LOG-ADR.md)
- QA-Artefakte: [Testmatrix](testing/test-matrix.md) & [Berichtsvorlage](testing/reports/README.md)

## Status (MVP)
- Scope: Offline, BLE-Only, bis 8 Athlet:innen, Latenz ≤ 1 s
- CI/CD-Setup dokumentiert (siehe [62-CI-CD.md](62-CI-CD.md)), Implementierung geplant
- Risiko-Register aktualisiert, offene QA-Lücken in Ticket-Backlog (QA-17, QA-18)

## Nächste Schritte
- ADR-004 (Export & Datenschutz) finalisieren
- Fastlane-Automatisierung & GitHub-Actions (`ci-pr.yml`) implementieren
- Feldtest-Plan (42) terminieren und ersten QA-Bericht im `testing/reports/`-Ordner ablegen
