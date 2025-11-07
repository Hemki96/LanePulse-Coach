---
title: "Funktionale Anforderungen"
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

# Funktionale Anforderungen (MVP)

## Live-Board
- Bis zu 8 Athlet:innen parallel (automatische Layout-Umschaltung)
- Kachel-Layout (responsive: 2×2, 3×3, 4×2) inklusive AirPlay-Spiegelung
- Live-Anzeige: HR, Zone, Trend, Status, optional %HFmax, Timer

## Konfiguration
- Kennzahlen je Kachel ein-/ausblendbar (Persistenz pro Athlet:in)
- Zonenmodell pro Athlet konfigurierbar (HFmax, Karvonen optional)
- Schwellen für Aktiv/Pause justierbar, inklusive Schnellwahl-Profilen

## Mappings & Sessions
- Persistentes Mapping Sensor-ID ↔ Athlet (lokal mit Validierung)
- Session-Start, -Stop, Notizen, Intervallmarker
- Session-Log mit Exporthistorie und Wiederaufnahme zuletzt genutzter Profile

## Erkennung & Analytik
- Auto Aktiv/Pause (HR-Dynamik, Hysterese)
- Recovery-Metrik (Slope 60 s Pause)
- Zeit in Zone, Durchschnitt/Max HR sowie Intervallzusammenfassung

## Exporte
- CSV & JSON lokal (On My iPad/LanePulse Coach)
- Automatischer Export an Freigabeziele nach Session-Ende (optional)

## Ansichten
- Coach-Ansicht: Steuerung, Detailpane je Athlet inklusive Alarmhinweisen
- Athleten-Ansicht: Großkacheln (HR/Zone/Name), AirPlay/HDMI-Ausgabe
