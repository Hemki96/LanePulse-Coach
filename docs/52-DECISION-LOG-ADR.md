---
    title: "Architecture Decision Records"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# ADRs (Kurzform)

## ADR-001: iPad als Central, BLE-only
- **Kontext**: Hallenbad ohne Internet
- **Entscheidung**: iPad Central; keine Cloud
- **Konsequenzen**: Fokus auf Reconnect/Robustheit

## ADR-002: Resampling 1 Hz + EWMA
- **Kontext**: Rauschen & Jitter
- **Entscheidung**: Einheitliche 1 Hz Pipeline, EWMA α≈0,3
- **Konsequenzen**: Stabile Anzeigen, kalkulierbare Latenz

## ADR-003: CoreData (+ SQLite) Persistenz
- **Kontext**: Offline, einfache Abfragen
- **Entscheidung**: CoreData für Samples/Events
- **Konsequenzen**: Solide Apple-Stack-Integration
