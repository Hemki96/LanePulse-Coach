---
    title: "Testfälle (Auszug)"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# Testfälle (Auszug)

- **TC-01**: 1 Sensor, stabil, Latenz messen (≤1 s)
- **TC-02**: 3 Sensoren, Dropouts ≤3 s → stale korrekt, kein Reconnect
- **TC-03**: 3 Sensoren, Dropouts >3 s → Auto-Reconnect ≤8 s (P95)
- **TC-04**: Aktiv/Pause Sequenz → korrekte Segmentierung
- **TC-05**: Export CSV/JSON → Schema & Werte korrekt
