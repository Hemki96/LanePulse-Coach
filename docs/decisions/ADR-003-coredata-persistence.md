# ADR-003: Core Data (SQLite) als Persistenzschicht

## Kontext
Die App muss auch ohne Internet funktionieren, Sessions lokal speichern und Exporte anbieten. iPadOS bietet mit Core Data und SQLite einen integrierten Stack mit guter Tooling-Unterstützung.

## Entscheidung
Persistenz und Caching der Trainingsdaten erfolgen über Core Data mit SQLite-Store. Modelle werden über Codegen verwaltet, Repositories kapseln den Zugriff.

## Alternativen
- **Realm:** einfaches Schema, aber zusätzliche Abhängigkeit und Lizenzfragen.
- **GRDB/Raw SQLite:** maximale Kontrolle, jedoch höherer Implementierungsaufwand.
- **CloudKit:** scheitert am Offline-Fokus und Rollen-/Zugriffskonzept.

## Konsequenzen
- Nutzen der Apple-Ökosystem-Features (NSFetchedResultsController, BackgroundTasks).
- Schema-Änderungen erfolgen über Lightweight-Migrationen.
- Für spätere Cloud-Syncs muss ein Abgleich-/Conflict-Handling ergänzt werden.

## Status
Approved
