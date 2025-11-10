# App Store Guideline Audit

This report reviews the LanePulse Coach project against the major App Store guideline chapters (Safety, Performance, Business, Design, and Legal) and highlights edge-case handling, monetisation, sign-in, and API usage considerations.

## Summary

| Chapter | Status | Evidence | Follow-up actions |
| --- | --- | --- | --- |
| Safety | ✅ Core features respect user consent, recover from data faults, and avoid crashes. | Persistence store recovery, guarded notification registration, and Bluetooth gating show defensive design.【F:LanePulse Coach/Data/Persistence/PersistenceController.swift†L32-L85】【F:LanePulse Coach/Application/PushNotificationManager.swift†L38-L121】【F:LanePulse Coach/Configuration/AppContainerFactory.swift†L34-L119】 | Document emergency contact expectations and complete on-device verification with real BLE hardware. |
| Performance | ✅ Background work, export, and UI selection logic manage resources carefully. | Background tasks reschedule conservatively, exports batch work, and UI prevents empty selections.【F:LanePulse Coach/Application/BackgroundTaskCoordinator.swift†L56-L177】【F:LanePulse Coach/Export/DataExportService.swift†L86-L200】【F:LanePulse Coach/UI/ContentView.swift†L61-L102】 | Profile BLE streaming on device to confirm latency thresholds and queue sizing. |
| Business | ⚠️ No monetisation or account flow is present; support and export tooling exist. | App launches straight into content with data export tools and support contacts, but contains no StoreKit or sign-in implementation.【F:LanePulse Coach/LanePulse_CoachApp.swift†L9-L31】【F:LanePulse Coach/Export/DataExportService.swift†L107-L200】【F:LanePulse Coach/UI/ContentView.swift†L217-L310】【0fe60c†L1-L2】【8714be†L1-L2】 | Decide whether monetisation or account creation is required; if so, integrate Sign in with Apple / StoreKit with full compliance assets. |
| Design | ✅ Adaptive layouts, accessibility affordances, and informative placeholders follow HIG guidance. | Tab structure, accessibility labels, and support tips demonstrate inclusive design.【F:LanePulse Coach/UI/ContentView.swift†L27-L206】【F:LanePulse Coach/UI/ContentView.swift†L255-L286】 | Validate large Dynamic Type snapshots and RTL layouts in Xcode previews or on-device. |
| Legal | ⚠️ Core privacy strings and contact info exist, but privacy policy surfacing is pending. | Bluetooth usage strings localised, notification handling logs responsibly, support section lists contact channels.【F:LanePulse Coach/Base.lproj/InfoPlist.strings†L1-L5】【F:LanePulse Coach/Application/PushNotificationManager.swift†L38-L146】【F:LanePulse Coach/UI/ContentView.swift†L289-L310】 | Publish privacy policy/terms links inside the app and ensure DataExportService aligns with data-retention commitments. |

## Detailed Findings

### Safety
- **Data integrity** – The Core Data stack retries corrupted stores, cleans up SQLite sidecars, and falls back to an in-memory store so the app does not crash on launch if persistence fails.【F:LanePulse Coach/Data/Persistence/PersistenceController.swift†L32-L85】
- **Permission discipline** – Push notifications request authorization only when needed and react to denial without spamming the user, satisfying guideline expectations for respectful prompts.【F:LanePulse Coach/Application/PushNotificationManager.swift†L46-L95】
- **Hardware access** – Bluetooth adapters are registered only when the Info.plist contains mandatory usage descriptions, preventing accidental submission with missing strings. The adapter also checks for valid UUIDs before connecting to peripherals.【F:LanePulse Coach/Configuration/AppContainerFactory.swift†L34-L119】【F:LanePulse Coach/BLE/CoreBluetoothAdapter.swift†L34-L90】
- **Crash avoidance** – Remote notifications, background tasks, and export pipelines all wrap operations in `do/catch` or guard clauses to avoid fatal errors when services are unavailable.【F:LanePulse Coach/Application/BackgroundTaskCoordinator.swift†L77-L159】【F:LanePulse Coach/Export/DataExportService.swift†L107-L135】

### Performance
- **Background execution** – Scheduled refresh and processing tasks resubmit themselves, respect power/network constraints, and log failures, aligning with guideline 2.5 about efficient background usage.【F:LanePulse Coach/Application/BackgroundTaskCoordinator.swift†L63-L178】
- **Data export efficiency** – Export flows batch records, stream to disk, and clean temporary directories, which keeps memory use predictable during long-running exports.【F:LanePulse Coach/Export/DataExportService.swift†L107-L200】
- **UI responsiveness** – The split-view keeps a valid session selected and gracefully shows a placeholder when none exists, preventing empty screens or crashes when collections change.【F:LanePulse Coach/UI/ContentView.swift†L61-L102】
- **Latency monitoring** – The container wires a latency monitor with configurable thresholds so device-level performance regressions can be reported without custom diagnostics packages.【F:LanePulse Coach/Configuration/AppContainerFactory.swift†L45-L66】

### Business
- **Monetisation** – There is currently no StoreKit integration; the code search confirms no in-app purchase APIs, so monetisation relies on other channels for now.【0fe60c†L1-L2】
- **Account requirements** – No sign-in or credential flow exists, so Sign in with Apple is not required yet, but it must be added if future versions introduce account creation.【8714be†L1-L2】
- **Data handling for coaches** – CSV/JSON exports and share coordination provide value for teams and comply with guideline requirements for data access when using device hardware.【F:LanePulse Coach/Export/DataExportService.swift†L107-L200】
- **Support visibility** – The Settings tab exposes contact details and feedback messaging, helping satisfy guideline 5.1.1 for customer support reachability.【F:LanePulse Coach/UI/ContentView.swift†L217-L310】

### Design
- **Tab hierarchy** – The main interface uses a two-tab structure with clear labels and SF Symbols, aligning with platform conventions.【F:LanePulse Coach/UI/ContentView.swift†L27-L43】
- **Empty states** – A dedicated placeholder educates users when no session is selected, avoiding confusing blank screens.【F:LanePulse Coach/UI/ContentView.swift†L95-L169】
- **Accessibility** – Buttons include localized accessibility labels/values, and dedicated guidance explains VoiceOver, AssistiveTouch, and Dynamic Type behaviour.【F:LanePulse Coach/UI/ContentView.swift†L107-L206】【F:LanePulse Coach/UI/ContentView.swift†L255-L286】
- **Support & localisation** – German copy and localized strings show readiness for multi-language use; continue validating RTL layouts if targeted markets require it.【F:LanePulse Coach/UI/ContentView.swift†L217-L310】

### Legal & Privacy
- **Usage descriptions** – Required Bluetooth privacy strings are localized and embedded, preventing rejection under guideline 5.1.1.【F:LanePulse Coach/Base.lproj/InfoPlist.strings†L1-L5】
- **Notification policy** – Push token handling and logging avoid transmitting the token until backend code is added, reducing privacy exposure.【F:LanePulse Coach/Application/PushNotificationManager.swift†L66-L145】
- **Export compliance** – Exported files are stored under `temporaryDirectory`, keeping personal data on-device until the user shares it, which aligns with data minimisation best practices.【F:LanePulse Coach/Export/DataExportService.swift†L107-L149】
- **Contact details** – Support information is visible, but the app still needs in-app links to the privacy policy and terms of service to meet guideline 5.1.1/5.1.2 obligations.【F:LanePulse Coach/UI/ContentView.swift†L289-L310】

### Edge Case Coverage & Recommendations
- **Persistence corruption** – Already mitigated by fallback logic; test on-device by corrupting the SQLite store to ensure recovery messaging behaves as expected.【F:LanePulse Coach/Data/Persistence/PersistenceController.swift†L32-L85】
- **Notification denials** – The notification manager logs denials without retrying, which matches best practices; confirm UI surfaces alternative reminders when permissions are off.【F:LanePulse Coach/Application/PushNotificationManager.swift†L46-L95】
- **Bluetooth availability** – The CoreBluetooth adapter delays scanning until powered on and handles unauthorized/unsupported states, preventing unnecessary permission prompts or crashes.【F:LanePulse Coach/BLE/CoreBluetoothAdapter.swift†L30-L134】
- **Placeholder/preview audit** – No `TODO` or beta placeholder strings remain; all preview data is gated behind UITest configuration flags.【F:LanePulse Coach/Configuration/AppContainerFactory.swift†L87-L118】
- **Next steps** – Ship with real device testing notes, add privacy policy links, and decide on monetisation/account strategy before submission.

### Public API Usage Verification
The codebase only imports public Apple frameworks (SwiftUI, CoreData, BackgroundTasks, CoreBluetooth, UserNotifications, UIKit). No private selectors or `dlopen` calls were found during inspection, and optional third-party support (`PolarBleSdk`) is wrapped behind compile-time checks.【F:LanePulse Coach/BLE/CoreBluetoothAdapter.swift†L9-L200】【F:LanePulse Coach/Application/BackgroundTaskCoordinator.swift†L8-L178】【F:LanePulse Coach/Application/PushNotificationManager.swift†L8-L146】

