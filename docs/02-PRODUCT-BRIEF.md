---
    title: "Product Brief"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# Product Brief

## Zielgruppe
- Schwimmtrainer:innen (Hallenbad, Vereins- & Leistungsgruppen), 2–8 Athlet:innen gleichzeitig.

## Kernversprechen
- Live-Puls & Verlauf mehrerer Athlet:innen **mit ≤ 1 s Latenz**, **offline**, **BLE-only**.

## Hauptfeatures (MVP)
- Kachel-Board (2–8 Kacheln), konfigurierbare Metriken, Farb-Zonen
- Dauerhaftes Mapping Sensor↔Athlet
- Aktivitäts-/Pausenerkennung (HR-basiert, Hysterese)
- Auto-Reconnect & Dropout-Robustheit
- Exporte: CSV & JSON

## Abgrenzung
- Primär **Polar Verity Sense** (Polar BLE SDK) + generischer GATT Heart Rate Service (0x180D)
- WHOOP/Apple Watch: Roadmap (siehe 50-RELEASE-PLAN)

## Erfolgskriterien
- Anzeige-Latenz ≤ 1 s (Median)
- Reconnect ≤ 8 s (P95) nach Dropout
- Auto-Erkennung Aktiv/Pause ≥ 90 % korrekt (definierte Szenarien)
