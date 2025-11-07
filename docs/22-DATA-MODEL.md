---
    title: "Datenmodell"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# Datenmodell (vereinfacht)

## Entities
- **Athlete**: id, name, hfmax, zoneModel, notes
- **Sensor**: id (UUID), vendor, lastSeen, firmware, battery?
- **Mapping**: athleteId, sensorId, since, nickname
- **Session**: id, date, laneGroup?, coachNotes
- **HRSample**: sessionId, athleteId, t (epoch ms), hr
- **Event**: sessionId, athleteId, type (active|pause|intervalMark), tStart, tEnd, meta
- **MetricConfig**: coachProfileId, visibleMetrics[], thresholds

## Exporte
- **CSV/JSON** mit Schemabeschreibung (Felder wie oben)
