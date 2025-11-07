---
    title: "Algorithmik Aktiv/Pause"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.2.0"
    updated: "2025-11-08"
---

# Algorithmik: Aktivitäts-/Pausenerkennung

## Vorverarbeitung
- **Sampling:** Resample aller Sensor-Streams auf 1 Hz (Lücken werden als `isStale` markiert).
- **Glättung:** Exponentieller gleitender Mittelwert mit α = 0,3 über `HeartRatePreprocessor`.
- **Trend:** Lineare Regression über die letzten 10 s → ΔHR/Δt in **bpm pro Sekunde**.
- **Baseline-Ermittlung:** Während Status *Pause* wird ein 30 s gleitender Mittelwert gebildet. Fallback: `0,55 × hfMax` (mindestens 95 bpm).

## Entscheidungskriterien

| Parameter | Wert | Beschreibung |
|-----------|------|--------------|
| `deltaOn` | +12 bpm | Aktivierungsschwelle oberhalb Baseline |
| `deltaOff` | +6 bpm | Rückschaltschwelle in Richtung Pause |
| `minActiveDuration` | 8 s | Aktivzustand wird erst nach stabiler Überschreitung angenommen |
| `minPauseDuration` | 10 s | Pause wird erst nach stabiler Unterschreitung bzw. Trend erkannt |
| `activeZoneThreshold` | Zone 2 | Mindestens Zone 2 (≥60 % hfMax) genügt für Aktiv |
| `recoveryTrendThreshold` | −0,15 bpm/s | Entspricht −9 bpm/min als klares Erholsignal |
| `recoverySlopeWindow` | 60 s | Zeitraum für Auswertung der Recovery-Kurve |

**Aktiv:**
- Wenn `smoothedBpm ≥ baseline + deltaOn` **oder** Zone ≥ 2.
- Bedingung muss 8 s am Stück gelten.

**Pause:**
- Wenn `smoothedBpm ≤ baseline + deltaOff` **oder** Trend ≤ −0,15 bpm/s.
- Bedingung muss 10 s am Stück gelten.

Die Hysterese aus `deltaOn > deltaOff` verhindert Flattern im Grenzbereich.

## Recovery
- Während *Pause* werden bis zu 60 s Samples gesammelt.
- Der lineare Fit liefert eine Steigung in **bpm/min**. Negative Werte zeigen Erholung; Werte ≥ 0 werden ausgeblendet.
- UI zeigt Ampel-Status: < −12 bpm/min → grün, −12…−5 → gelb, > −5 → grau.

## Dropouts & Stale Samples
- Bis zu 3 s fehlende Daten markieren den Stream als `stale`. Anzeige hält letzte valide Werte grau.
- Ab 3 s startet der Auto-Reconnect mit UI-Hinweis (Toast + gelbes Banner).

## Offene Aufgaben
- Grenzen für Recovery-Ampel (−12/−5) in Exporten dokumentieren.
- Option zur Trainer-konfigurierbaren Baseline (manuell überschreiben) prüfen.
