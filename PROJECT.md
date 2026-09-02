# Project: RosettaHealth iOS Architecture, Refactoring, Zero-Cloud Compliance, and Testing

## Architecture
RosettaHealth is a privacy-first, on-device iOS medical document transcode and health data aggregation platform.
- **Core Engine (`RosettaHealthCore`)**:
  - `RosettaTranscoder`: SAX-based HL7 CDA XML parser converting clinical documents into HL7 FHIR R4 / International Patient Summary (IPS) bundles.
  - `HealthKitBridge`: Maps FHIR Observations to Apple HealthKit Quantity/Category samples, protected by a physiological validation gate (`isValidPhysiologically`).
  - `ClinicalDecisionSupport`: Local CDS evaluating clinical rules, cardiovascular risk factors, and vital trends.
  - `KeychainManager`: Secure hardware-backed storage for user fiscal code and security keys (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
- **Application Layer (`RosettaHealthApp`)**:
  - `AppViewModel`: `@Observable` orchestrator handling file ingestion, background sync, firewall routing, and state publishing to SwiftUI views.
  - `VaultModelActor` & `VaultDocument`: SwiftData persistence layer storing family/non-owner clinical records and full PDF archives locally.
  - `BackgroundTaskManager` & `SpotlightManager`: Background refresh, Spotlight indexing, and LocalAuthentication biometric access.
- **Extensions & Cross-Platform**:
  - `ShareExtension`: Receives external medical PDFs/CDAs via iOS Share Sheet, applying hardware encryption before saving to App Group container `group.dev.alexmaina.rosettahealth`.
  - `RosettaWidget` & `RosettaWatch`: Glanceable metric display and watchOS synchronization via App Group UserDefaults / WatchConnectivity.
- **Privacy Boundary (Zero-Cloud / GDPR Art. 9)**:
  - 100% on-device processing. Zero `URLSession`, `Alamofire`, `Network.framework`, telemetry, or cloud databases. SwiftData explicitly configured with `cloudKitDatabase: .none`.

```
[External CDA / PDF] ──> [ShareExtension] ──(App Group IPC)──> [AppViewModel]
                                                                      │
                                                          [RosettaTranscoder (SAX Parser)]
                                                                      │
                                                             [FHIR R4 / IPS Bundle]
                                                                      │
                                                           [Patient Firewall Check]
                                                          /                        \
                                        (Fiscal Code Match)            (Different Fiscal Code)
                                                │                                  │
                                    [HealthKit Validation Gate]          [SwiftData Vault (Family)]
                                                │                                  │
                                        [HealthKit Store]                  [VaultModelActor]
                                                \                                  /
                                                 \                                /
                                                  ▼                              ▼
                                                [AppViewModel & SwiftUI Reactive UI]
```

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | CDA XML Transcoder | SAX parser for HL7 CDA Release 2.0 to FHIR R4 Bundle | M1 | Transcoder Engine |
| 2 | Numeric & String Value Fallbacks | Comma-decimal (`94,5`) & inequality string fallback (`< 0.05`) | M1 | Transcoder Engine |
| 3 | Document ID & Metadata Extraction | Capture `documentId` from CDA header into `FHIRBundle.id` | M1 | Transcoder Engine |
| 4 | Narrative Section Text Preservation | Attach `accumulatedNarrativeText` to `FHIRComposition.text` | M1 | Transcoder Engine |
| 5 | Physiological Validation Gate | Block poisoned/extreme quantities (`isValidPhysiologically`) | M1 | HealthKit Bridge |
| 6 | HealthKit Bridge Singleton & Unit Safety | `HealthKitBridge.shared` and correct mass/concentration unit mappings | M1 | HealthKit Bridge |
| 7 | Core Unit Test Suite Fixes | Fix failing tests in `RosettaTranscoderTests2`, `ValidationGateTests`, `FSEEdgeCasesTests` | M1 | Test Suite |
| 8 | Availability Tag Normalization | Replace `@available(iOS 26.0, *)` with `@available(iOS 17.0, *)` across all files | M2 | App & Extensions |
| 9 | ViewModel State Reactivity | Add `@Observable` to `AppViewModel` & `BiometricAuthManager`, harmonize parameter labels | M2 | App Layer |
| 10 | SwiftData Actor Concurrency Safety | Remove `@Model` cross-actor leaks in `ClinicalDashboardView`, use DTOs/Actors | M2 | SwiftData Vault |
| 11 | Syntax & Scope Error Fixes | Fix `OnboardingView`, `FamilyVaultView`, `BackgroundTaskManager`, `LiquidGlass` | M2 | App Layer |
| 12 | App Group & Watch IPC Key Sync | Align UserDefaults keys (`latestMetricValue`, `widget_metricValue`, etc.) | M2 | IPC & Watch |
| 13 | Zero-Cloud & CloudKit Disable | Hardcode `cloudKitDatabase: .none` in SwiftData configuration | M3 | Security & GDPR |
| 14 | PII Redaction in Logging | Redact patient names in OSLog messages in `AppViewModel` | M3 | Security & GDPR |
| 15 | E2E Integration Test Suite | Comprehensive integration tests verifying CDA -> Transcoder -> Firewall -> Vault/HealthKit -> ViewModel | M4 | E2E Testing Track |
| 16 | Verification & Forensic Integrity Audit | Reviewers, Challengers, and Forensic Auditor verification pass | M5 | Verification |
| 17 | Script Cleanup & Final Documentation | Remove temporary analysis scripts and generate `teamwork_analysis_report.md` | M5 | Reporting |

## Defect Inventory & Root Causes
| ID | Defect | File & Line | Root Cause | Impact | Status |
|---|---|---|---|---|---|
| D1 | Duplicate declaration | `RosettaTranscoder.swift:27-28` | Duplicate `private var currentRangeUnit` | Compiler error | RESOLVED |
| D2 | Undeclared `documentId` | `RosettaTranscoder.swift:112-114` | Variable used on line 113 without class declaration | Compiler error | RESOLVED |
| D3 | Comma & inequality drop | `RosettaTranscoder.swift:157-165` | `Double(valStr)` fails for `"94,5"` and `"< 0.05"`, PQ skips `else if` | Measurement data loss | RESOLVED |
| D4 | Hardcoded UUID in Bundle | `RosettaTranscoder.swift:90-95` | `FHIRBundle(id: UUID().uuidString)` ignores extracted `documentId` | Metadata loss, test fail | RESOLVED |
| D5 | Dropped narrative text | `RosettaTranscoder.swift:73-79` | `FHIRComposition` initialized with `text: nil` | Diagnostic summary loss | RESOLVED |
| D6 | Validation gate dead code | `HealthKitBridge.swift:155, 169-238` | `isValidPhysiologically` defined but never invoked | Poisoned data enters HealthKit | RESOLVED |
| D7 | Missing singleton property | `HealthKitBridge.swift:4-5` | Missing `public static let shared = HealthKitBridge()` | `ObservationRowView` compile fail | RESOLVED |
| D8 | HealthKit Unit Crash | `ClinicalDecisionSupport.swift:44` vs `HealthKitBridge.swift:28` | Dietary cholesterol saved as `mg`, queried as `mg/dL` | `NSInvalidArgumentException` crash | RESOLVED |
| D9 | Ephemeral sync identifier | `HealthKitBridge.swift:217-218` | `FSE-\(obs.id)` where `obs.id = UUID()` on each transcode | Duplicate samples on re-sync | RESOLVED |
| D10 | Fantasy iOS 26 Availability | 12 files across App/Extensions | `@available(iOS 26.0, *)` and `if #available(iOS 26.0, *)` | Compilation failures or suppressed blocks | RESOLVED |
| D11 | Missing `@Observable` | `AppViewModel.swift:13`, `BiometricAuthManager.swift:8` | Missing `@Observable` macro | SwiftUI views do not re-render on state changes | RESOLVED |
| D12 | Parameter label mismatch | `AppViewModel.swift:61,78,203,237` vs `ContentView.swift:76,293,325` | `modelContext` vs `modelContainer` discrepancies, undeclared `modelContext` | Compiler errors in `AppViewModel` | RESOLVED |
| D13 | SwiftData cross-actor leak | `ClinicalDashboardView.swift:31-38` | `@Model` array `patientDocuments` accessed inside `Task.detached` | Data races, SwiftData crashes | RESOLVED |
| D14 | Syntax error in `OnboardingView` | `OnboardingView.swift:188-198` | Extra closing brace `}` prematurely terminates `Form` | Compiler error | RESOLVED |
| D15 | Undefined error state variables | `FamilyVaultView.swift:226-227` | `activeError` and `showError` referenced in `PDFViewerWrapper` | Compiler error | RESOLVED |
| D16 | Undefined background variables | `BackgroundTaskManager.swift:60,68` | `modelContext` and `containerToUse` referenced but undeclared | Compiler error | RESOLVED |
| D17 | Non-existent `LiquidGlass` API | `LiquidGlass.swift:7` | Call to `glassEffect(.regular.interactive(), ...)` | Compiler error | RESOLVED |
| D18 | Premature file removal in IPC | `AppViewModel.swift:97-154` | `defer { try? FileManager.default.removeItem(at: file) }` runs before failure check | Data loss on parse failure | RESOLVED |
| D19 | Watch UserDefaults mismatch | `AppViewModel.swift:338-340` vs `WatchDashboardView.swift:8-15` | String vs Double type and key discrepancies | Empty Apple Watch dashboard | RESOLVED |
| D20 | CloudKit Data Leak Risk | `MainAppView.swift:18-19` | Dynamic `isCloudSyncEnabled` enabling CloudKit database | Risk of GDPR Article 9 leak | RESOLVED |
| D21 | Unredacted PII in OSLog | `AppViewModel.swift:233` | Patient name logged without `.private` privacy mask | Privacy violation in system logs | RESOLVED |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Core Transcoder & HealthKit Bridge Refactoring | Fix all Transcoder parsing data loss, document ID extraction, narrative retention, HealthKit validation gate, singleton, unit safety, and core tests | none | DONE |
| M2 | App Architecture, Concurrency & UI Reactivity | Normalize iOS availability, add `@Observable`, fix SwiftData actor boundaries, parameter mismatches, syntax errors, and Watch IPC sync | M1 | DONE |
| M3 | Zero-Cloud & GDPR Isolation Hardening | Hardcode `cloudKitDatabase: .none`, redact PII in OSLog, and certify zero network SDKs | M2 | DONE |
| M4 | E2E Integration Testing Track | Implement comprehensive integration test suite (40 XCTest cases) covering CDA -> Transcoder -> Firewall -> Vault/HealthKit -> ViewModel | M1, M2, M3 | DONE |
| M5 | Verification, Forensic Audit & Reporting | Reviewer, Challenger, and Forensic Auditor verification, cleanup temp scripts, and generate `teamwork_analysis_report.md` | M4 | DONE |

## Code Layout
- `Sources/RosettaHealthCore/`: Core transcode, HealthKit, CDS, and Keychain engine
  - `RosettaTranscoder.swift`: Owned by M1 Worker
  - `HealthKitBridge.swift`: Owned by M1 Worker
  - `ClinicalDecisionSupport.swift`: Owned by M1 Worker
  - `FHIRModels.swift`: Owned by M1 Worker
- `Sources/RosettaHealthApp/`: Application, ViewModels, Views, Vault
  - `AppViewModel.swift`: Owned by M2/M3 Worker
  - `MainAppView.swift`, `RosettaHealthApp.swift`: Owned by M2/M3 Worker
  - `LiquidGlass.swift`, `OnboardingView.swift`: Owned by M2 Worker
  - `Vault/VaultDocument.swift`, `Vault/VaultModelActor.swift`, `Vault/ClinicalDashboardView.swift`, `Vault/FamilyVaultView.swift`: Owned by M2 Worker
  - `BackgroundTaskManager.swift`, `SpotlightManager.swift`, `BiometricAuthManager.swift`, `ObservationRowView.swift`, `ContentView.swift`: Owned by M2 Worker
- `Sources/ShareExtension/`, `Sources/RosettaWidget/`, `Sources/RosettaWatch/`:
  - `ShareViewController.swift`, `RosettaWidget.swift`, `WatchDashboardView.swift`: Owned by M2 Worker
- `Tests/`: Unit and Integration test targets
  - `Tests/RosettaHealthCoreTests/`: 10 test files (40 test cases across Tiers 1-4, E2E lifecycle, and unit tests)

## Interface Contracts
### Transcoder ↔ HealthKit / App Layer
- `RosettaTranscoder.transcode(cdaData: Data) -> FHIRBundle?`
  - Returns valid `FHIRBundle` with `id` populated from CDA `documentId` (or fallback UUID).
  - Preserves all quantitative observations (handling commas `94,5` and inequalities `< 0.05`), reference ranges, and narrative text.
- `HealthKitBridge.ingestQuantities(fhirBundle: FHIRBundle) async -> Int`
  - Enforces physiological validation gate `isValidPhysiologically` before creating and persisting `HKQuantitySample`.
  - Generates deterministic `HKMetadataKeySyncIdentifier` based on document/sample stable hash (`"FSE-\(fhirBundle.id)-\(coding.code)-\(obs.effectiveDateTime)"`).
- `AppViewModel` ↔ SwiftData / View
  - `AppViewModel` conforms to `@Observable` and is isolated to `@MainActor`.
  - Accepts `ModelContainer` / `ModelContext` cleanly without type ambiguity or undeclared variable references.
  - Inter-actor SwiftData updates handled safely via `VaultModelActor` or Sendable `DocumentDTO` projections.
