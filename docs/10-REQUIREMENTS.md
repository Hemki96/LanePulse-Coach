---
    title: "Funktionale Anforderungen"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# Funktionale Anforderungen (MVP)

## Live-Board
- Bis zu 8 Athlet:innen parallel
- Kachel-Layout (responsive: 2×2, 3×3, 4×2)
- Live-Anzeige: HR, Zone, Trend, Status, optional %HFmax, Timer

## Konfiguration
- Kennzahlen je Kachel ein-/ausblendbar
- Zonenmodell pro Athlet konfigurierbar (HFmax, Karvonen optional)
- Schwellen für Aktiv/Pause justierbar

## Mappings & Sessions
- Persistentes Mapping Sensor-ID ↔ Athlet (lokal)
- Session-Start, -Stop, Notizen, Intervallmarker

## Erkennung & Analytik
- Auto Aktiv/Pause (HR-Dynamik, Hysterese)
- Recovery-Metrik (Slope 60 s Pause)
- Zeit in Zone, Durchschnitt/Max HR

## Exporte
- CSV & JSON lokal (On My iPad/LanePulse Coach)

## Ansichten
- Coach-Ansicht: Steuerung, Detailpane je Athlet
- Athleten-Ansicht: Großkacheln (HR/Zone/Name), AirPlay/HDMI-Ausgabe
