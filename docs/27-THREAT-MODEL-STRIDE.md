---
    title: "Threat Model (STRIDE)"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# Threat Model (STRIDE)

- **Spoofing:** Fremde BLE-Geräte → Whitelist & Mapping-Lock
- **Tampering:** Keine externen Schreibpfade; lokale Integritätsprüfung
- **Repudiation:** Lokale Logs minimal; keine personenbezogenen Logs
- **Information Disclosure:** Scoreboard nur mit anonymen Aliasen (optional)
- **Denial of Service:** Scan-Rate begrenzen; Verbindungs-Limits
- **Elevation of Privilege:** Nur eine Trainerrolle lokal, Geräte-PIN/MDM nutzen
