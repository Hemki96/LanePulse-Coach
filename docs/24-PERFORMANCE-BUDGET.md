---
    title: "Performance-Budgets"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# Performance-Budgets

- **End-to-End-Latenz:** ≤ 1 s (Median)
- **UI-Frame-Zeit:** ≤ 16 ms (60 FPS Ziel)
- **Persistenz:** Batch alle 5 s; max. 200 ms/Batch
- **Speicher:** Ring-Buffer je Athlet (≥ 120 s), Gesamtnutzung < 200 MB
- **Reconnect-Zeit:** ≤ 8 s (P95)
