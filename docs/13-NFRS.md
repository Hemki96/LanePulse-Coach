---
title: "Nicht-funktionale Anforderungen"
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

# Nicht-funktionale Anforderungen

- **Latenz:** ≤ 1 s (Median) vom Sample bis UI-Update, ≤ 2 s P95 unter Last
- **Reconnect:** ≤ 8 s (P95) nach Dropout, automatische Hintergrundsuche aktiv
- **Offline:** 100 % funktionsfähig ohne Internet inklusive Exportwarteschlange
- **Robustheit:** Störungsarme Anzeige trotz kurzzeitiger Dropouts bis 3 s (mit Buffering)
- **Usability:** Session-Start in < 30 s; Mapping < 10 s/Athlet inklusive Favoriten
- **Barrierefreiheit:** Hohe Kontraste, große Typo im Scoreboard; VoiceOver für KPI-Kacheln
- **Datenschutz:** Lokale Speicherung verschlüsselt (Keychain + FileProtectionComplete)
