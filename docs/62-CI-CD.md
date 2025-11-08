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
| Lint & Format | SwiftLint (`--strict`), SwiftFormat (`--lint`), `xcodebuild analyze` | Pull Request (GitHub Actions) |
| Unit/UI Tests & Coverage | `xcodebuild test`, `xccov view` Export | Pull Request + Nightly |
| UI-Snapshot Smoke | `xcodebuild test` (UITests, Fastlane Snapshot) | Nachtlauf (main) |
| Build & Sign | `xcodebuild archive`, `xcodebuild -exportArchive` | Merge nach `main` |
| Distribution | TestFlight (Transporter/fastlane pilot) | On Demand |

> **Provider-Setup:** Primär läuft der Flow auf GitHub Actions. Xcode Cloud dient als Fallback für signierte Builds bei Apple-zertifizierten Runnern. Bitrise wird evaluativ für Hardware-nahe Tests mit echten Sensoren (BLE-Testlab) genutzt.

## GitHub Actions Pipelines
1. **`ci-pr.yml`** (neu anzulegen)
   - Läuft auf `pull_request`.
   - Schritte: `actions/checkout`, Cache von `DerivedData`, Setup von SwiftLint & SwiftFormat, `swiftlint --strict`, `swiftformat --lint .`, `xcodebuild analyze`, `xcodebuild test` im Simulator (iPad Pro 11" iOS 17).
   - Artefakte: Test-Logs (`xcresult`), SwiftLint-Report (`lint.json`), SwiftFormat-Report (`formatting.json`), Coverage (`coverage.xccovreport`).
   - Coverage-Gate: Workflow schlägt fehl, wenn kritische Module < 80 % Linie (aus `xccov view --only-targets`).

2. **`ci-nightly.yml`**
   - Läuft täglich 02:00 UTC auf Branch `main`.
   - Führt `fastlane snapshot` für Kernbildschirme aus, um visuelle Regressionen zu erkennen; erzeugt zusätzlich `swiftlint --strict` und `swiftformat --lint` Reports zur Trendbeobachtung.
   - Lädt Screenshots + `xcresult` + Coverage-CSV in Artefakte hoch; Ergebnisse werden im QA-Notion verlinkt.

3. **`release-archive.yml`**
   - Trigger: `workflow_dispatch` + `push` auf Tags `v*`.
   - Archiviert Release-Build mit `xcodebuild archive`, exportiert `.ipa`, signiert mit Distributionsprofil.
   - Optionaler Upload nach TestFlight via `fastlane pilot` oder Xcode Cloud Distribution, abhängig vom jeweiligen Release-Verantwortlichen.

## Verantwortlichkeiten
- **Engineering:** Pflegt Pipelines, reagiert auf Fehlermeldungen innerhalb von 1 Arbeitstag.
- **QA:** Bewertet Snapshot-Artefakte, dokumentiert Ergebnisse in [`docs/testing/reports/`](testing/reports/README.md).
- **Produkt:** Gibt Go/No-Go für TestFlight-Builds und pflegt Changelog (siehe [70-CHANGELOG.md](70-CHANGELOG.md)).

## Nächste Schritte
- Secrets für Signierung (`APP_STORE_CONNECT_KEY`, `MATCH_PASSWORD`) im GitHub-Repository hinterlegen.
- Fastlane-Lane `beta` schreiben, um Transporter-Upload zu automatisieren; Alternativ `xcode-cloud` Workflow mit automatischer TestFlight-Distribution konfigurieren.
- Erfolgskriterien (Testabdeckung, Lint-Fehler, Static-Analyzer Findings) als Status-Checks in Branch Protection hinterlegen.
- Bitrise Workflow (Optional) aufsetzen für Integrationstests mit physischem BLE-Hub, Trigger über Nightly oder manuell.
