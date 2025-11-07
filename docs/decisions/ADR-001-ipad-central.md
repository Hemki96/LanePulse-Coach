# ADR-001: iPad als BLE-Central ohne Cloud-Anbindung

## Kontext
Training findet in Hallenbädern mit instabilem oder fehlendem WLAN statt. Die Trainer:innen benötigen Live-Daten ohne Abhängigkeit von Backend-Services. Ein einzelnes iPad soll Sensoren koppeln, Daten visualisieren und lokal persistieren.

## Entscheidung
Das iPad agiert als einziger BLE-Central und verbindet sich direkt mit allen Herzfrequenzsensoren. Es gibt keine Cloud-Synchronisation im MVP; Persistenz erfolgt ausschließlich lokal über Core Data.

## Alternativen
- **Cloud-gestütztes Backend:** hätte Live-Sync ermöglicht, scheitert jedoch an Netzabdeckung und erhöhtem Betriebsaufwand.
- **Dedizierter Gateway (Raspberry Pi + Router):** mehr Setup-Aufwand, zusätzliche Fehlerquellen im feuchten Umfeld.
- **Verteilte App (iPad + Apple Watch):** höhere Komplexität bei Pairing, zusätzliche Devices nötig.

## Konsequenzen
- Fokus auf robuste Reconnect-Strategien und klare UI-Status für Verbindungsabbrüche.
- Exporte erfolgen manuell (CSV/JSON) und werden per AirDrop/Cloud geteilt.
- Zukünftige Cloud-Sync-Funktionen benötigen Migration der Datenhaltung.

## Status
Approved
