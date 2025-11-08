---
    title: "Release-Plan"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# Release-Plan (MVP → Pilot)

- **Alpha (A1):** Scan/Connect, 1–3 Sensoren, Board-Basis
- **Beta (B1):** bis 8 Sensoren, Reconnect, Aktiv/Pause, Exporte
- **Pilot (P1):** Scoreboard, Mini-Timeline, Batterieanzeige
- **Roadmap (R1):** Apple-Watch-Bridge, WHOOP (stabil), PDF-Report

## TestFlight-Beta-Programm

### Zielgruppen
- **Intern:** Engineering, QA, Produktteam (≤ 25 Slots). Fokus auf schnelle Regressionstests nach jedem Merge in `main`.
- **Extern:** 40–60 Schwimmtrainer:innen (Pilotvereine) via Public Link; Rollout in Wellen zu je 15 Personen.

### Ablauf
1. **Build Selection:** Jede Merge-Release-Version wird mit Tag `vX.Y.Z-betaN` versehen und via `release-archive.yml` erzeugt.
2. **Internal QA Gate:** Pflicht-Checkliste (Tests grün, Crashlytics leer, Known Issues dokumentiert) → Freigabe im Release-Channel.
3. **TestFlight Submission:** Upload über `fastlane pilot` oder Xcode Cloud Distribution. Metadaten (Changelog, Testnotizen) werden aus [`docs/70-CHANGELOG.md`](70-CHANGELOG.md) generiert.
4. **Feedback Loop:**
   - In-App Link zu `feedback.lanepulse.app` (Formular, sammelt Screenshot + Logs).
   - Wöchentlicher Sync (Di 09:00) zur Durchsprache; Tickets in Linear (`TEAM-QA`).
5. **Exit Criteria:** Zwei aufeinanderfolgende Builds ohne Blocker, Crash-Rate < 1 % aktiver Sessions.

### Artefakte
- **Tester-Liste:** Verwaltet im Apple Developer Portal, Export als CSV → abgelegt unter `docs/testing/reports/testflight/`.
- **Feedback-Backlog:** Zusammenfassung in Notion-Board `TestFlight Feedback`; Referenz in Sprint-Retros.
