---
    title: "Datenmodell"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.2.0"
    updated: "2025-11-08"
---

# Datenmodell (MVP)

## Entities
- **Athlete**: `id` (UUID), `name`, `hfMax` (Int16, Herzfrequenz-Maximum), `zoneModel` (JSON-kodiertes Mapping), optionale `notes`
- **Sensor**: `id` (UUID), `vendor`, `lastSeen` (Date), `firmware` (String, optional), `batteryLevel` (Double 0.0–1.0)
- **Mapping**: `id` (UUID), `athleteId`, `sensorId`, `since` (Date), optionale `nickname`
- **Session**: `id` (UUID), `startDate` (Date), optionale `laneGroup` (String) und `coachNotes`
- **HRSample**: `id` (UUID), `sessionId`, `athleteId`, `timestamp` (Date), `heartRate` (Int16, bpm), optionale Qualitätsflags
- **Event**: `id` (UUID), `sessionId`, optionale `athleteId`, `type` (enum: `active`, `pause`, `intervalMark`), `start`, `end`, optionale `metadata`
- **MetricConfig**: `id` (UUID), `coachProfileId`, `visibleMetrics` (NSArray), `thresholds` (NSDictionary)

## Beziehungen
- Ein `Athlete` kann über `Mapping` mit mehreren `Sensor`-Geräten historisch verknüpft werden.
- `HRSample` referenziert stets eine `Session`; Dropout-Samples nutzen `isStale`-Flag in der Analytics-Schicht.
- `Event`-Einträge werden von der Aktivitätslogik erzeugt und dienen Exporten und UI-Annotations.

## Exporte
- **CSV/JSON** spiegeln obige Felder wider:
  - Sensoren: `id`, `vendor`, `lastSeen`, `firmware`, `batteryLevel`
  - Sessions: `id`, `startDate`, `laneGroup`, `coachNotes`
  - Samples: `sessionId`, `athleteId`, `timestamp`, `heartRate`
  - Events: `sessionId`, `athleteId`, `type`, `start`, `end`, `metadata`

## Offene Punkte
- Serialisierung von `zoneModel`-Profilen (aktueller Stand: JSON-String) in API-konforme Struktur überführen.
- Qualitätsflags (`isStale`) für Exporte standardisieren (true/false vs. numerische Codes).
