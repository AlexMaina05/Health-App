# RosettaEdge iOS Codebase — Architectural Survey, Zero-Cloud Audit & Test Suite Analysis

**Date**: 2026-09-01  
**Author**: Explorer Survey 3  
**Target Repository**: `e:/Code/Health-App`  
**Workspace Root**: `e:/Code/Health-App`  

---

## 1. Executive Summary

RosettaEdge is a native Swift iOS/watchOS application designed as an on-device bridge between the Italian Electronic Health Record (*Fascicolo Sanitario Elettronico* - FSE 2.0 / HL7 CDA R2) and Apple HealthKit / HL7 FHIR R4. The app operates under strict Zero-Cloud and GDPR (Article 9) privacy constraints, ensuring all CDA XML parsing, OCR processing, clinical decision support (CDS), and storage happen entirely on the local device SoC without external network transmission.

This survey provides:
1. **Full Architectural Mapping**: Module decomposition, directory structure, IPC data flow, and entry points.
2. **Zero-Cloud & GDPR Isolation Audit**: Repository-wide audit verifying the complete absence of networking frameworks (`URLSession`, `Alamofire`, `Network.framework`, `WebSockets`, third-party analytics/crash reporters) and identifying potential CloudKit synchronization risks and PII logging leaks.
3. **Cross-Module Communication & Defect Catalog**: Exhaustive identification of syntax, compilation, concurrency, and logic defects across `RosettaEdgeCore`, `RosettaEdgeApp`, `ShareExtension`, `RosettaWidget`, and `RosettaWatch`.
4. **Test Suite & Integration Infrastructure Readiness**: Evaluation of existing XCTest unit tests, mock datasets (`Mock_Laboratorio.xml`, `Mock_Specialistica.xml`), and blueprint for end-to-end integration tests (`Transcoder -> SwiftData / HealthKit -> ViewModel`).

---

## 2. Project Architecture & Module Mapping

### 2.1 Repository Directory Structure

```
Health-App/
├── Package.swift                    # SPM package definition (RosettaEdgeCore & Tests)
├── project.yml                      # XcodeGen project specification
├── README.md                        # Documentation and architecture guide
├── MockData/                        # Official FSE CDA XML test payloads
│   ├── Mock_Laboratorio.xml         # Quantitative laboratory report (Glucose, Cholesterol, BP, Platelets)
│   └── Mock_Specialistica.xml       # Narrative specialist report (Cardiology anamnesis & ECG)
├── Sources/
│   ├── RosettaEdgeCore/           # Core domain framework (Pure Swift / HealthKit / PDFKit / Vision)
│   │   ├── ClinicalDecisionSupport.swift   # Local clinical trend analysis & notification engine
│   │   ├── FHIRModels.swift                # FHIR R4 JSON Codable models with IPS profiles
│   │   ├── HealthKitBridge.swift           # LOINC -> HKQuantityType mapping, validation & ingestion
│   │   ├── PDFExtractor.swift              # PDF embedded attachment (Names/EmbeddedFiles) extractor
│   │   ├── ParsingAttributes.swift         # ActivityKit attributes for Live Activities
│   │   ├── RosettaError.swift              # Strongly-typed error domain with localized descriptions
│   │   ├── RosettaTranscoder.swift         # SAX XMLParser for HL7 CDA R2 -> FHIR R4 transcoding
│   │   └── VisionOCRExtractor.swift        # Apple Vision OCR fallback for raster scanned PDFs
│   ├── RosettaEdgeApp/            # Main iOS application target (SwiftUI / SwiftData)
│   │   ├── RosettaEdgeApp.swift          # Main entry point (@main App)
│   │   ├── AppViewModel.swift              # Primary application view model & pipeline coordinator
│   │   ├── AppTheme.swift                  # Color theme definitions
│   │   ├── BackgroundTaskManager.swift     # BGTaskScheduler coordination for nightly batch ingestion
│   │   ├── BiometricAuthManager.swift      # LocalAuthentication (Face ID / Touch ID) privacy screen
│   │   ├── ContentView.swift               # Primary dashboard view (HealthKit status, metrics list)
│   │   ├── KeychainManager.swift           # Hardware-isolated Keychain wrapper for Owner Tax Code
│   │   ├── LiquidGlass.swift               # Glassmorphism UI modifier
│   │   ├── MainAppView.swift               # Root navigation & ScenePhase lifecycle coordinator
│   │   ├── ObservationRowView.swift        # Observation row card with Catmull-Rom sparklines
│   │   ├── OnboardingView.swift            # First-launch onboarding & GDPR consent carousel
│   │   ├── SettingsView.swift              # Profile, theme, PRO toggle, and security preferences
│   │   ├── ShareSheet.swift                # UIActivityViewController wrapper for FHIR JSON export
│   │   ├── SpotlightManager.swift          # CoreSpotlight indexing for Vault documents
│   │   ├── VaultTip.swift                  # TipKit discovery tip
│   │   ├── Intents/
│   │   │   └── ProcessReportIntent.swift   # AppIntents action for iOS Shortcuts integration
│   │   └── Vault/                          # SwiftData Multi-Patient Family Vault
│   │       ├── AnnotatedPDFView.swift      # PDFKit vector highlight annotation renderer
│   │       ├── ClinicalDashboardView.swift # Holistic Swift Charts trend viewer per patient
│   │       ├── FamilyVaultView.swift       # Multi-user hierarchical EMR document browser
│   │       ├── VaultDocument.swift         # SwiftData persistent model (@Model)
│   │       └── VaultModelActor.swift       # SwiftData background ModelActor
│   ├── RosettaWatch/                # watchOS companion app
│   │   └── WatchDashboardView.swift        # Glanceable Gauge UI reading from shared App Group
│   ├── RosettaWidget/               # iOS WidgetKit extension
│   │   ├── RosettaParsingLiveActivity.swift # Dynamic Island & Lock Screen Live Activity
│   │   └── RosettaWidget.swift             # Lock Screen & Home Screen widget provider
│   └── ShareExtension/              # iOS Share Extension target
│       └── ShareViewController.swift       # Custom SwiftUI Share UI & IPC file writer
└── Tests/
    └── RosettaEdgeCoreTests/      # Unit test suite
        ├── ClinicalDecisionSupportTests.swift # Trend analysis verification
        ├── FSEEdgeCasesTests.swift            # XXE protection, empty/narrative parsing
        ├── RosettaTranscoderTests.swift       # Patient demographics and CDA parsing
        ├── RosettaTranscoderTests2.swift      # Dirty XML fallbacks and document ID extraction
        └── ValidationGateTests.swift          # Physiological range validation tests
```

---

### 2.2 Module Dependencies & Target Graph

```
                   ┌─────────────────────────────┐
                   │        ShareExtension       │
                   └──────────────┬──────────────┘
                                  │ (Shared App Group IPC)
                                  ▼
                   ┌─────────────────────────────┐
                   │       RosettaEdgeApp      │
                   └───────┬──────────────┬──────┘
                           │              │
       ┌───────────────────┴──┐        ┌──┴──────────────────┐
       │     RosettaWidget    │        │     RosettaWatch    │
       └──────────────────────┘        └─────────────────────┘
                           │              │
                           ▼              ▼
                   ┌─────────────────────────────┐
                   │      RosettaEdgeCore      │
                   └──────────────┬──────────────┘
                                  │
                                  ▼
                   ┌─────────────────────────────┐
                   │    RosettaEdgeCoreTests   │
                   └─────────────────────────────┘
```

- **Target Relationships**:
  - `RosettaEdgeCore` is a standalone framework linking `HealthKit`, `Vision`, `PDFKit`, `ActivityKit`, and `UIKit`.
  - `RosettaEdgeApp`, `ShareExtension`, `RosettaWidget`, and `RosettaWatch` consume `RosettaEdgeCore`.
  - Inter-process communication between `ShareExtension`, `RosettaWidget`, `RosettaWatch`, and `RosettaEdgeApp` occurs strictly via the shared Application Group container (`group.dev.alexmaina.rosettaedge`) and hardware-encrypted local file storage.

---

### 2.3 System Entry Points & Execution Lifecycle

| Target | Entry Point | Invocation Context | Primary Responsibility |
|---|---|---|---|
| **Main App** | `RosettaEdgeApp.swift:5` (`@main App`) | User launches application | Initializes `BackgroundTaskManager`, sets up SwiftData `ModelContainer`, renders `MainAppView`, activates Face ID privacy overlay on ScenePhase change. |
| **Share Extension** | `ShareViewController.swift:55` (`NSExtensionPrincipalClass`) | User taps "Share" in Safari/Files/Mail | Receives PDF `NSItemProvider`, extracts CDA XML or copies raster PDF, applies hardware encryption (`completeUntilFirstUserAuthentication`), writes to App Group container. |
| **Background Scheduler** | `BackgroundTaskManager.swift:18` (`BGTaskScheduler`) | System wake during overnight charge | Executes `dev.alexmaina.rosettaedge.processPDFs`, drains App Group pending files headless, runs Transcoder, updates HealthKit and SwiftData. |
| **App Intents / Shortcuts** | `ProcessReportIntent.swift:7` (`AppIntent`) | iOS Shortcuts / Siri automation | Headless ingestion of PDF file parameter, transcoding, and metric injection. |
| **WidgetKit Extension** | `RosettaWidget.swift:88` (`@main WidgetBundle`) | SpringBoard widget update / Live Activity | Reads cached metric from App Group `UserDefaults`, renders Lock Screen/Home Screen widgets and Dynamic Island Live Activities. |

---

## 3. Strict Zero-Cloud & GDPR Isolation Audit

### 3.1 Network Framework & SDK Audit

A comprehensive static analysis across all files in the repository was conducted:

| Network / Telemetry Technology | Detection Query | Occurrences in Code | Audit Status |
|---|---|---|---|
| `URLSession` | `import Foundation.URLSession`, `URLSession.` | 0 in executable code (only mentioned in docs/comments) | **PASSED** (100% Zero-Cloud) |
| `Alamofire` | `Alamofire` | 0 | **PASSED** |
| `Network.framework` | `import Network`, `NWPathEvaluator`, `NWConnection` | 0 | **PASSED** |
| `WebSockets` | `WebSocket`, `Starscream`, `URLSessionWebSocketTask` | 0 | **PASSED** |
| `WKWebView` | `import WebKit`, `WKWebView` | 0 | **PASSED** |
| `Firebase` / `Crashlytics` | `Firebase`, `FIRApp` | 0 | **PASSED** |
| `Sentry` / `Mixpanel` / `TelemetryDeck` | `Sentry`, `Mixpanel`, `TelemetryDeck` | 0 | **PASSED** |
| Outbound Network URLs (`http`/`https`) | `URL(string: "http...")` | 2 instances in `SettingsView.swift:139,149` (`Link` to developer website/GitHub); all other instances are standard FHIR/LOINC OID URIs (`http://loinc.org`, `http://hl7.it/sid/codiceFiscale`) | **PASSED** (Non-exfiltration) |

---

### 3.2 CloudKit Sync & Insecure Storage Backdoor Audit

**Critical Finding in `MainAppView.swift:18-19`**:
```swift
let syncEnabled = UserDefaults.standard.bool(forKey: "isCloudSyncEnabled")
let config = ModelConfiguration(cloudKitDatabase: syncEnabled ? .automatic : .none)
```
- **Analysis**:
  - `MainAppView` checks `UserDefaults` for `isCloudSyncEnabled` and conditionally sets `cloudKitDatabase: .automatic`.
  - In `SettingsView.swift:22` and `AppViewModel.swift:35`, `@AppStorage("isCloudSyncEnabled")` is declared.
  - While currently defaulting to `false`, the presence of `.automatic` CloudKit synchronization creates an architectural vulnerability where sensitive patient health documents in `VaultDocument` could be synchronized to iCloud servers if this flag is toggled.
- **GDPR Article 9 Impact**: Health data is categorized as *special category personal data*. CloudKit synchronization without explicit user end-to-end encryption configuration violates the Zero-Cloud promise.
- **Remediation**: Remove `isCloudSyncEnabled` and hardcode `ModelConfiguration(cloudKitDatabase: .none)` across all `ModelContainer` initializations.

---

### 3.3 Data Protection at Rest & Cryptography

1. **Keychain Isolation**:
   - `KeychainManager.swift:16`: Sets `kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
   - **Verification**: The user's Tax Code (*Codice Fiscale*) is hardware-locked to the Secure Enclave of the specific physical device and will never sync to other devices via iCloud Keychain.
2. **File Protection Hierarchy**:
   - `ShareViewController.swift:109,134`: Applies `FileProtectionType.completeUntilFirstUserAuthentication`.
   - `ContentView.swift:319`: Sets `FileProtectionType.complete`.
   - `ProcessReportIntent.swift:27`: Sets `FileProtectionType.completeUntilFirstUserAuthentication`.
   - `FamilyVaultView.swift:223`: Uses `[.atomic, .completeFileProtection]`.
3. **Atomic File Deletion (Zero-Retention)**:
   - `AppViewModel.swift:49-59`: `cleanupTemporaryFiles()` runs on app launch to wipe leftover PDF files in `FileManager.default.temporaryDirectory`.
   - `AppViewModel.swift:97,180`: Uses `defer { try? FileManager.default.removeItem(at: file) }` when draining App Group pending files.
   - `ContentView.swift:324`: Uses `defer { try? FileManager.default.removeItem(at: safeURL) }` immediately after processing user-selected files.

---

### 3.4 PII & Diagnostic Log Audit

**Observation in `AppViewModel.swift:233`**:
```swift
logger.notice("Referto di \(patientInfo.name) deviato verso il Family Vault (Bypass HealthKit).")
```
- **Issue**: Patient full name is interpolated directly into `OSLog` in cleartext.
- **Remediation**: Use OSLog privacy redaction:
  ```swift
  logger.notice("Referto di \(patientInfo.name, privacy: .private) deviato verso il Family Vault (Bypass HealthKit).")
  ```

---

## 4. Cross-Module Communication & Defect Catalog

### 4.1 Defects in `RosettaEdgeCore`

#### Defect CORE-01: Duplicate Property & Undeclared Variable in `RosettaTranscoder.swift`
- **Location**: `Sources/RosettaEdgeCore/RosettaTranscoder.swift:27-28, 113`
- **Observation**:
  ```swift
  27: private var currentRangeUnit: String = ""
  28: private var currentRangeUnit: String = ""
  ...
  113: documentId = attributeDict["extension"] ?? attributeDict["root"]
  ```
- **Root Cause**: `currentRangeUnit` is declared twice. `documentId` is assigned on line 113 but never declared as a member variable (`private var documentId: String?`), and is not passed to the resulting `FHIRBundle` (line 91 initializes `id: UUID().uuidString`).
- **Impact**: Swift compilation error; bundle ID does not retain the original FSE document identifier.

#### Defect CORE-02: String & Non-Numeric Value Dropping in `RosettaTranscoder.swift`
- **Location**: `Sources/RosettaEdgeCore/RosettaTranscoder.swift:158-165`
- **Observation**:
  ```swift
  if elementName == "value" {
      let type = attributeDict["xsi:type"] ?? ""
      if (type == "PQ" || type == "REAL" || type == "INT"), let valStr = attributeDict["value"], let dVal = Double(valStr) {
          let unit = attributeDict["unit"] ?? "1"
          currentObsValue = FHIRQuantity(value: dVal, unit: unit, code: unit)
      } else if type == "ST" || type == "TX" {
          currentObsValueString = attributeDict["value"]
      }
  }
  ```
- **Root Cause**: When an XML element has `xsi:type="PQ"` but the value contains non-numeric comparator characters (e.g. `value="< 0.05"` in `MockData` or specialist tests), `Double(valStr)` returns `nil`, and the fallback `else if` is skipped because `type == "PQ"`.
- **Impact**: Quantitative measurements with comparator strings (`<`, `>`, `<=`) are silently dropped rather than preserved in `valueString`.

#### Defect CORE-03: Physiological Validation Gate Not Invoked in `HealthKitBridge.swift`
- **Location**: `Sources/RosettaEdgeCore/HealthKitBridge.swift:155-167, 169-238`
- **Observation**: `HealthKitBridge` defines `isValidPhysiologically(value:for:)` on line 155, but never calls it inside `ingestQuantities(fhirBundle:)` (lines 169-238).
- **Impact**: Lethal or erroneous health values (e.g., Blood Glucose = 3000 mg/dL) are not intercepted by the validation gate, allowing data poisoning of Apple Health.

#### Defect CORE-04: Missing Singleton Property in `HealthKitBridge.swift`
- **Location**: `Sources/RosettaEdgeCore/HealthKitBridge.swift` vs `Sources/RosettaEdgeApp/ObservationRowView.swift:108`
- **Observation**: `ObservationRowView.swift:108` calls `HealthKitBridge.shared`, but `HealthKitBridge` only defines `public init()` without a `static let shared = HealthKitBridge()`.
- **Impact**: Compilation failure in UI layer.

---

### 4.2 Defects in `RosettaEdgeApp`

#### Defect APP-01: Missing `@Observable` Macro on `AppViewModel`
- **Location**: `Sources/RosettaEdgeApp/AppViewModel.swift:12-13`
- **Observation**: Line 3 imports `Observation`, but line 12 is declared as `public final class AppViewModel {` without `@Observable`.
- **Impact**: SwiftUI views (`ContentView`) observing `AppViewModel` will not trigger UI invalidation and state updates when properties (`syncedSamplesCount`, `extractedObservations`, `isProcessing`) mutate.

#### Defect APP-02: Method Signature & Parameter Inconsistencies in `AppViewModel`
- **Location**: `Sources/RosettaEdgeApp/AppViewModel.swift:61, 78, 203, 237` vs `ContentView.swift:76, 293, 298, 325, 370`
- **Observation**:
  - In `AppViewModel.swift`:
    - Line 61: `requestHealthKitAccess(modelContext: ModelContext? = nil)`
    - Line 78: `syncPendingDocuments(modelContext: ModelContext? = nil)`
    - Line 203: `processPDF(url: URL, modelContainer: Any? = nil)`
    - Line 237: `if let context = modelContext as? SwiftData.ModelContext` (undeclared variable `modelContext`).
  - In `ContentView.swift`:
    - Line 76: `viewModel.requestHealthKitAccess(modelContainer: modelContext.container)`
    - Line 293, 298: `viewModel.syncPendingDocuments(modelContainer: modelContext.container)`
    - Line 325, 370: `viewModel.processPDF(url: safeURL, modelContainer: modelContext.container)`
- **Impact**: Severe compile errors due to mismatched argument labels (`modelContainer:` vs `modelContext:`) and undefined scope variables.

#### Defect APP-03: Erroneous `@available(iOS 26.0, *)` Annotations
- **Location**: Found across 12 files:
  - `RosettaEdgeApp.swift:4`
  - `AppViewModel.swift:132, 250`
  - `BackgroundTaskManager.swift:7`
  - `BiometricAuthManager.swift:6`
  - `MainAppView.swift:5`
  - `OnboardingView.swift:3`
  - `VaultDocument.swift:7`
  - `VaultModelActor.swift:6`
  - `FamilyVaultView.swift:5, 98, 202`
  - `ClinicalDashboardView.swift:6`
  - `ShareViewController.swift:8, 17, 54`
  - `RosettaWidget.swift:72`
- **Impact**: Targets cannot compile or run on real iOS 17.0+ devices.

#### Defect APP-04: Syntax Error in `OnboardingView.swift`
- **Location**: `Sources/RosettaEdgeApp/OnboardingView.swift:189`
- **Observation**: Extra closing brace `}` on line 189 prematurely terminates `Form {`, leaving subsequent sections unparented.
- **Impact**: Swift parser syntax error preventing compilation.

#### Defect APP-05: Scope Errors in `BackgroundTaskManager.swift`
- **Location**: `Sources/RosettaEdgeApp/BackgroundTaskManager.swift:60, 68`
- **Observation**:
  ```swift
  60: var contextToUse = modelContext
  ...
  68: await viewModel.syncPendingDocuments(modelContainer: containerToUse)
  ```
- **Root Cause**: `modelContext` and `containerToUse` are undefined in `processPendingFilesHeadless`.
- **Impact**: Background scheduler task fails to compile.

#### Defect APP-06: Undeclared State Variables in `FamilyVaultView.swift`
- **Location**: `Sources/RosettaEdgeApp/Vault/FamilyVaultView.swift:226-227`
- **Observation**: `PDFViewerWrapper` attempts to assign `activeError = ...` and `showError = true` without defining `@State private var activeError: String?` or `@State private var showError: Bool = false`.
- **Impact**: Compilation failure in PDF viewer wrapper.

#### Defect APP-07: Optional Binding on Non-Optional in `ClinicalDashboardView.swift`
- **Location**: `Sources/RosettaEdgeApp/Vault/ClinicalDashboardView.swift:36`
- **Observation**: `guard let data = doc.fhirBundleJSON,` where `doc.fhirBundleJSON` is `Data` (non-optional).
- **Impact**: Compiler warning/error: *"Initializer for conditional binding must have Optional type"*.

#### Defect APP-08: Non-Existent SwiftUI API in `LiquidGlass.swift`
- **Location**: `Sources/RosettaEdgeApp/LiquidGlass.swift:7`
- **Observation**: `self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))` calls an imaginary/unsupported modifier.
- **Impact**: View modifier fails compilation on iOS 17.

---

### 4.3 Defects in `RosettaWatch` & `RosettaWidget` Communication

#### Defect IPC-01: App Group UserDefaults Key Mismatch
- **Location**:
  - `AppViewModel.swift:338-340`: Writes `"widget_metricName"`, `"widget_metricValue"` (String).
  - `ProcessReportIntent.swift:63-64`: Writes `"widget_metricName"`, `"widget_metricValue"`.
  - `RosettaWatch/WatchDashboardView.swift:8-14`: Reads `"latestMetricValue"` (Double), `"latestMetricName"` (String), `"latestMetricUnit"` (String).
- **Impact**: The Apple Watch Companion App displays `0` and `"Nessun Dato"` because keys and types do not match what `AppViewModel` publishes.

---

## 5. Test Suite & Integration Testing Infrastructure

### 5.1 Existing Unit Test Suite Breakdown

| Test File | Test Method | Purpose | Existing Defect / Blocker |
|---|---|---|---|
| `ClinicalDecisionSupportTests.swift` | `testCholesterolWorseningTrend` | Verifies >10% increase triggers `.warning` | None (Valid) |
| `ClinicalDecisionSupportTests.swift` | `testCholesterolImprovingTrend` | Verifies decreasing cholesterol returns `nil` | None (Valid) |
| `ClinicalDecisionSupportTests.swift` | `testGlucoseCriticalTrend` | Verifies >5% increase & >100 mg/dL triggers alert | None (Valid) |
| `FSEEdgeCasesTests.swift` | `testMissingClinicalDocumentHeader` | Verifies missing `<ClinicalDocument>` throws error | None (Valid) |
| `FSEEdgeCasesTests.swift` | `testNarrativeTextExtraction` | Verifies narrative-only document parsing | **Defect**: Line 33 asserts `XCTAssertEqual(bundle.entry.count, 0)`, but Transcoder always creates Composition + Patient entries (`bundle.entry.count >= 2`). |
| `FSEEdgeCasesTests.swift` | `testBillionLaughsXXEMitigation` | Verifies XML entity expansion attack protection | None (Valid) |
| `RosettaTranscoderTests.swift` | `testExtractPatientInfo` | Verifies patient CF and name extraction | None (Valid) |
| `RosettaTranscoderTests2.swift` | `testDirtyXMLValuesFallback` | Verifies string fallback for non-numeric PQ values | **Defect**: Line 25 checks `bundle.entry.first` (which is Composition, not Observation); Transcoder drops non-numeric PQ values (CORE-02). |
| `RosettaTranscoderTests2.swift` | `testDocumentIDExtraction` | Verifies `ClinicalDocument/id` extraction | **Defect**: Transcoder ignores `documentId` and generates a random UUID (CORE-01). |
| `ValidationGateTests.swift` | `testGlucosePhysiologicalLimits` | Verifies glucose = 3000 mg/dL is skipped | **Defect**: `FHIRBundleEntry` initialization syntax error; `isValidPhysiologically` is never called in `HealthKitBridge` (CORE-03). |
| `ValidationGateTests.swift` | `testGlucoseValid` | Verifies valid glucose (95 mg/dL) is accepted | **Defect**: `FHIRBundleEntry` initialization syntax error. |
| `ValidationGateTests.swift` | `testBloodPressureLimits` | Verifies blood pressure validation | **Defect**: Uses unmapped LOINC `85354-9`. |

---

### 5.2 Test Runner & Mock Environments Readiness

1. **Package.swift Scope**:
   - `Package.swift` currently builds only `RosettaEdgeCore` and `RosettaEdgeCoreTests`.
   - `RosettaEdgeApp` components (ViewModels, Models, Views) are omitted from SPM test targets.
2. **Mock Data Assets**:
   - `MockData/Mock_Laboratorio.xml`: Fully structured laboratory report containing:
     - Patient: Mario Rossi (`RSSMRA85M01H501Z`)
     - Glucose: `94.5 mg/dL` (LOINC `15074-8`)
     - Cholesterol: `215.0 mg/dL` (LOINC `2093-3`, out-of-range: 120-200)
     - Blood Pressure: `"125/80"` (LOINC `8480-6`, composite string)
     - Platelets: `240 10*3/uL` (LOINC `777-3`, unmapped / skipped metric)
   - `MockData/Mock_Specialistica.xml`: Cardiology narrative report containing:
     - Patient: Alessandro Bianchi (`BNCLSN90A01F205X`)
     - Narrative sections for Anamnesis, Physical Exam, and Conclusions.
3. **End-to-End Integration Test Strategy**:
   - Integration tests can be structured by initializing an in-memory SwiftData container:
     ```swift
     let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
     let container = try ModelContainer(for: VaultDocument.self, configurations: config)
     let context = container.mainContext
     ```
   - Testing the full pipeline:
     1. Load `Mock_Laboratorio.xml` data from bundle / filesystem.
     2. Transcode via `RosettaTranscoder` -> verify `FHIRBundle` structure.
     3. Feed `FHIRBundle` into `AppViewModel` with owner matching `RSSMRA85M01H501Z` -> verify HealthKit ingestion quantities and skipped codes.
     4. Feed `Mock_Specialistica.xml` with different patient CF -> verify dual-routing firewall blocks HealthKit and stores in `VaultDocument` SwiftData context.
     5. Query SwiftData context to verify encrypted JSON and narrative persistence.
     6. Evaluate `ClinicalDecisionSupport` against historical samples to verify notification dispatch.

---

## 6. Actionable Refactoring Roadmap

| Phase | Target File | Action |
|---|---|---|
| **Phase 1: Transcoder & Models** | `RosettaTranscoder.swift` | 1. Remove duplicate `currentRangeUnit`.<br>2. Declare `documentId: String?` and use in `FHIRBundle(id:)`.<br>3. Handle non-numeric values in `value` elements by falling back to `currentObsValueString`. |
| **Phase 1: HealthKit & Validation** | `HealthKitBridge.swift` | 1. Add `static let shared = HealthKitBridge()`.<br>2. Call `isValidPhysiologically` in `ingestQuantities()`.<br>3. Add LOINC `85354-9` or normalize systolic/diastolic components. |
| **Phase 2: App Architecture & State** | `AppViewModel.swift` | 1. Add `@Observable` macro.<br>2. Standardize signatures to accept `ModelContext`.<br>3. Align widget keys (`widget_metricName`, `widget_metricValue`, `widget_lastUpdate`).<br>4. Sanitize OSLog PII interpolation. |
| **Phase 2: SwiftData & Zero-Cloud** | `MainAppView.swift`, `SettingsView.swift` | 1. Hardcode `ModelConfiguration(cloudKitDatabase: .none)`.<br>2. Remove `isCloudSyncEnabled` references. |
| **Phase 2: UI & Concurrency Fixes** | `OnboardingView.swift`, `FamilyVaultView.swift`, `ClinicalDashboardView.swift`, `LiquidGlass.swift` | 1. Fix syntax error in `OnboardingView.swift`.<br>2. Add state properties to `PDFViewerWrapper`.<br>3. Fix non-optional guard in `ClinicalDashboardView.swift`.<br>4. Replace `glassEffect` with standard material/background. |
| **Phase 3: Unit & Integration Tests** | `Tests/RosettaEdgeCoreTests/*` | 1. Fix `FHIRBundleEntry` constructor calls.<br>2. Correct entry indexing in `RosettaTranscoderTests2.swift`.<br>3. Fix assertion in `FSEEdgeCasesTests.swift`.<br>4. Implement End-to-End Integration test suite utilizing `Mock_Laboratorio.xml` and `Mock_Specialistica.xml`. |

---
