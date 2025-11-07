# ADR-002: 1 Hz Resampling mit EWMA-Glättung

## Kontext
Mehrere Sensorhersteller liefern Herzfrequenzdaten mit unterschiedlicher Samplingrate und jitternden Intervallen. Die UI benötigt konsistente 1 Hz Updates, und die Aktiv-/Pause-Logik muss mit rauscharmen Signalen arbeiten.

## Entscheidung
Alle eingehenden Samples werden auf 1 Hz resampled. Für jedes Athlet:innen-Signal kommt eine EWMA-Glättung mit α = 0,3 zum Einsatz; Trends werden über 10 s berechnet.

## Alternativen
- **Moving Average über festes Fenster:** führt zu höherer Latenz und kantigen Übergängen.
- **Kalman-Filter:** genauer, aber deutlich komplexer und schwer zu tunen für MVP.
- **Keine Glättung:** UI würde stark fluktuieren, erschwert Coaching-Entscheidungen.

## Konsequenzen
- Gleichmäßige Updates ermöglichen klare Animationen und Interpolationen.
- α = 0,3 balanciert Reaktionsgeschwindigkeit und Stabilität; kann je Sensor kalibriert werden.
- Trendfenster 10 s speist Aktivitätslogik und Recovery-Slope konsistent.

## Status
Approved
