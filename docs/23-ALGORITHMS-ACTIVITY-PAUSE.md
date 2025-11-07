---
    title: "Algorithmik Aktiv/Pause"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.1.0"
    updated: "2025-11-07"
    ---

# Algorithmik: Aktivitäts-/Pausenerkennung

## Vorverarbeitung
- Resample auf 1 Hz
- Glättung: **EWMA** (α ≈ 0,3)
- Trend: ΔHR/Δt (z. B. über 5–10 s)

## Entscheidung
- **Aktiv**, wenn HR ≥ (Baseline + Δ_on) **oder** Zone ≥ Z2 **für ≥ 8 s**
- **Pause**, wenn HR ≤ (Baseline + Δ_off) **oder** ΔHR ≤ −X/10 s **für ≥ 10 s**
- **Hysterese:** Δ_on > Δ_off (z. B. +12 vs. +6 bpm)

## Recovery
- Slope der ersten 60 s Pause (bpm/min)

## Dropouts
- ≤ 3 s → Status „stale“ (gelb), Anzeige hält letzten Wert grau
- > 3 s → stiller Auto-Reconnect
