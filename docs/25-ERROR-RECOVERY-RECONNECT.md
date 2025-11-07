---
    title: "Fehlerbehandlung & Reconnect"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# Fehlerbehandlung & Reconnect

- Zustandsautomat mit Telemetrie (optional, lokal)
- Exponentielles Backoff; Limit + Jitter
- UI-Indikatoren: verbunden (grün), stale (gelb), reconnect (grau)
- Battery-Warnungen (<20 %) sofern verfügbar
- Duplicate-Sensor-Schutz (Whitelist + Mapping-Lock)
