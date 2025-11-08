---
title: "Crash Logging & Monitoring"
owner: "Amelia Vogt"
status: "Draft"
version: "0.1.0"
updated: "2025-02-15"
---

# Crash Logging & Monitoring

## Ziele
- Laufzeitfehler früh erkennen und nach Schwere priorisieren.
- Regressionsanalyse für Beta- und Pilotphasen unterstützen.
- Datenschutz (DSGVO) einhalten: keine personenbezogenen Daten ohne Opt-in.

## Tooling
| Phase | Tool | Zweck |
|-------|------|-------|
| Development | Xcode Organizer (Crashes & Energy Reports) | Sofortiges Debugging lokaler Builds |
| Beta/Pilot | Firebase Crashlytics | Near-Real-Time Crash-Reports, Aggregation, Alerts |
| Production | App Store Connect Metrics | Ergänzende Stabilitäts-KPIs & Trendanalyse |

## Implementierungsschritte
1. **Firebase Setup**
   - Projekt `lanepulse-coach` in Firebase Console anlegen; iOS-App mit Bundle-ID `com.lanepulse.coach` registrieren.
   - `GoogleService-Info.plist` über Encrypted Repo (`config/secrets/`) verteilen; Xcode Configurations `Debug`/`Release` binden.
   - Swift Package `FirebaseCrashlytics` in Xcode hinzufügen; Initialisierung in `LanePulse_CoachApp.swift` unter Feature-Flag `AppConfiguration.shared.enableCrashlytics`.
2. **Crash Reporting Hooks**
   - `CrashReporter` Service in `LanePulse Coach/Utilities/Monitoring/` platzieren; Wrapper um `Crashlytics.crashlytics()`.
   - Uncaught Errors via `NSSetUncaughtExceptionHandler` + `Task { await CrashReporter.record(error:) }` erfassen.
   - Benutzerdefinierte Keys: Session-ID, BLE-Sensoranzahl, Bildschirmkontext (keine personenbezogenen Daten).
3. **Log-Forwarding**
   - Konsolidierte Logs über `os_log` Kategorien (`analytics`, `ble`, `ui`).
   - In Beta-Builds optionaler Upload von Log-Dateien via Feedback-Formular (siehe [TestFlight-Beta-Programm](50-RELEASE-PLAN.md#testflight-beta-programm)).
4. **Alerting**
   - Crashlytics Alert mit Threshold ≥ 3 Crashes / Stunde oder `fatal` Issues.
   - PagerDuty Integration für P1 Incidents.

## Betrieb & Reporting
- **Monitoring:** QA wertet Crashlytics Dashboard täglich während Beta aus; in Produktion wöchentlich.
- **Reports:** Monatliches PDF (Export aus Crashlytics) unter `docs/testing/reports/crashlytics/` archivieren.
- **Retrospektive:** Jede Release-Retros enthält Abschnitt "Stabilität" mit Top 3 Issues + Status.

## Datenschutz & Opt-in
- Datenschutzhinweis in Onboarding-Screen aktualisieren (Verweis auf Crashlytics & Opt-out über Einstellungen).
- Opt-out respektiert `AnalyticsSettings.isCrashReportingEnabled`; Feature-Flag zwingend vor Senden prüfen.
