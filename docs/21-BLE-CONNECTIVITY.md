---
    title: "BLE/Polar-Konnektivität"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# BLE-Konnektivität & Polar SDK

- **Profile:** GATT Heart Rate Service (0x180D), Char 0x2A37
- **Polar Verity Sense:** Nutzung Polar BLE SDK für stabile Multi-Streams, optional Acc-Daten
- **iPad als Central:** Parallele Verbindungen (Ziel: 8)
- **Zustandsautomat:** scanning → connecting → streaming → stale → reconnecting
- **Reconnect:** Exponentielles Backoff (1–2–4–8 s), Priorisierung aktiver Sessions
- **Zeitbasis:** Resampling auf 1 Hz; fehlende Samples als „stale“ markieren (≤3 s)
