---
    title: "CI/CD"
    owner: "Christian Hemker"
    status: "Draft"
    version: "0.2.0"
    updated: "2025-11-08"
---

# CI/CD Workflow

## Übersicht
| Phase | Tooling | Trigger |
|-------|---------|---------|
| Lint & Unit-Tests | `xcodebuild test`, SwiftLint | Pull Request (GitHub Actions) |
| UI-Snapshot Smoke | `xcodebuild test` (UITests, Fastlane Snapshot) | Nachtlauf (main) |
| Build & Sign | `xcodebuild archive`, `xcodebuild -exportArchive` | Merge nach `main` |
| Distribution | TestFlight (manuell über Transporter) | On Demand |

## GitHub Actions Pipelines
1. **`ci-pr.yml`** (neu anzulegen)
   - Läuft auf `pull_request`.
   - Schritte: `actions/checkout`, Cache von `DerivedData`, `brew install swiftlint` (Runner), `swiftlint --strict`, `xcodebuild test` im Simulator (iPad Pro 11" iOS 17).
   - Artefakte: Test-Logs (`xcresult`), SwiftLint-Report (`lint.json`).

2. **`ci-nightly.yml`**
   - Läuft täglich 02:00 UTC auf Branch `main`.
   - Führt `fastlane snapshot` für Kernbildschirme aus, um visuelle Regressionen zu erkennen.
   - Lädt Screenshots + `xcresult` als Artefakte hoch.

3. **`release-archive.yml`**
   - Trigger: `workflow_dispatch` + `push` auf Tags `v*`.
   - Archiviert Release-Build mit `xcodebuild archive`, exportiert `.ipa`, signiert mit Distributionsprofil.
   - Übergibt Artefakte an Release-Managers; Upload nach TestFlight erfolgt aktuell manuell via Transporter.

## Verantwortlichkeiten
- **Engineering:** Pflegt Pipelines, reagiert auf Fehlermeldungen innerhalb von 1 Arbeitstag.
- **QA:** Bewertet Snapshot-Artefakte, dokumentiert Ergebnisse in [`docs/testing/reports/`](testing/reports/README.md).
- **Produkt:** Gibt Go/No-Go für TestFlight-Builds und pflegt Changelog (siehe [70-CHANGELOG.md](70-CHANGELOG.md)).

## Nächste Schritte
- Secrets für Signierung (`APP_STORE_CONNECT_KEY`, `MATCH_PASSWORD`) im GitHub-Repository hinterlegen.
- Fastlane-Lane `beta` schreiben, um Transporter-Upload zu automatisieren.
- Erfolgskriterien (Testabdeckung, Lint-Fehler) als Status-Checks in Branch Protection hinterlegen.
