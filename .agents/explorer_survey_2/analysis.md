# Architectural & Cross-Module Analysis Report: RosettaHealth iOS

**Date**: 2026-09-01  
**Investigator**: Explorer 2 (Subagent)  
**Scope**: HealthKit Integration, SwiftData Persistence Architecture, ViewModels & SwiftUI Observation, Transcoder Interoperability, Cross-Module Concurrency, and IPC Handshakes.

---

## Executive Summary

A comprehensive architectural inspection was conducted across the RosettaHealth iOS, watchOS, Widget, and Share Extension modules. Several critical defects, syntax errors, concurrency hazards, compilation blockers, and communication bottlenecks were identified across all subsystems. 

Key themes identified:
1. **Compilation Blockers & Invalid Availability**: Widespread use of `@available(iOS 26.0, *)` and `#available(iOS 26.0, *)` disables code execution or prevents compilation on standard iOS targets (iOS 17/18). Syntax errors such as duplicate variable declarations (`currentRangeUnit`), missing variables (`documentId`, `modelContext`, `containerToUse`, `activeError`, `showError`), and missing static singletons (`HealthKitBridge.shared`) prevent successful builds.
2. **SwiftData Threading & Concurrency Violations**: `@Model` objects (`VaultDocument`) bound to the MainActor context are passed directly across actor boundaries into `Task.detached` within `ClinicalDashboardView`, violating Swift Concurrency / CoreData thread confinement rules. Furthermore, `VaultModelActor` was created for background operations but is completely bypassed in favor of synchronous main thread context saves.
3. **SwiftUI State Propagation & Observation Failure**: `AppViewModel` and `BiometricAuthManager` are not decorated with the `@Observable` macro or `ObservableObject` conformance, preventing SwiftUI views from reactively detecting property changes (e.g. `syncedSamplesCount`, `isProcessing`, `activeError`, `isUnlocked`). Parameter mismatches between `AppViewModel` methods (`modelContext:` vs `modelContainer:`) break invocation from `ContentView`.
4. **HealthKit Validation Gate Bypass & Unit Mismatches**: The physiological validator (`isValidPhysiologically`) in `HealthKitBridge` is dead code and never invoked during `ingestQuantities`, allowing poisoned or out-of-range clinical metrics into Apple Health. Unit mismatches exist between HealthKit storage (`dietaryCholesterol` stored as mass `mg` vs queried as concentration `mg/dL` in `ClinicalDecisionSupport`, which causes runtime crashes in `doubleValue(for:)`).
5. **Transcoder Data Loss & Composite Metric Dropping**: Dirty numerical strings in `xsi:type="PQ"` (e.g. `< 0.05`) are discarded instead of falling back to `valueString`. Composite metrics (e.g. Blood Pressure `120/80`) lose their diastolic component during ingestion. Narrative clinical report text is extracted but never attached to the `FHIRComposition`, leaving the text view empty in `FamilyVaultView`.
6. **Cross-Module IPC Race Conditions & Mismatched Shared Defaults**: The Share Extension queues files into the App Group container which `AppViewModel` immediately deletes with `defer`, causing permanent data loss on ingestion errors. Mismatched UserDefaults keys and data types between `AppViewModel` (`widget_metricName`/`widget_metricValue` as strings) and `WatchDashboardView` (`latestMetricValue` as double) render watchOS synchronization completely broken.

---

## 1. HealthKit Integration Analysis

### 1.1 Missing Singleton & Inconsistent Instantiation
- **File**: `Sources/RosettaHealthCore/HealthKitBridge.swift` (Lines 4-70) vs `Sources/RosettaHealthApp/ObservationRowView.swift` (Line 108)
- **Observation**:
  `HealthKitBridge` is declared as:
  ```swift
  public final class HealthKitBridge {
      private let healthStore = HKHealthStore()
      ...
  ```
  However, in `ObservationRowView.swift` (line 108):
  ```swift
  let bridge = HealthKitBridge.shared
  ```
  `HealthKitBridge` does NOT define a `public static let shared = HealthKitBridge()` property.
- **Defect Impact**: Compile-time error `Type 'HealthKitBridge' has no member 'shared'`. Furthermore, different components (`AppViewModel`, `ProcessReportIntent`, `ValidationGateTests`) instantiate independent `HealthKitBridge` / `HKHealthStore` instances rather than sharing a single thread-safe interface.
- **Recommended Fix**: Add `public static let shared = HealthKitBridge()` to `HealthKitBridge.swift` or pass an injected instance.

### 1.2 Validation Gate Bypass / Dead Code
- **File**: `Sources/RosettaHealthCore/HealthKitBridge.swift` (Lines 155-238)
- **Observation**:
  `isValidPhysiologically(value:for:)` is implemented on lines 155-167:
  ```swift
  private func isValidPhysiologically(value: Double, for type: HKQuantityTypeIdentifier) -> Bool {
      switch type {
      case .bloodGlucose: return value >= 10 && value <= 1500
      case .bloodPressureSystolic: return value >= 40 && value <= 350
      case .bloodPressureDiastolic: return value >= 20 && value <= 200
      case .heartRate: return value >= 10 && value <= 300
      case .oxygenSaturation: return value >= 0.1 && value <= 1.0
      case .bodyTemperature: return value >= 20 && value <= 45
      case .bodyMass: return value >= 1 && value <= 600
      case .height: return value >= 0.3 && value <= 3.0
      default: return true
      }
  }
  ```
  In `ingestQuantities(fhirBundle:)` (lines 169-238), `isValidPhysiologically` is NEVER CALLED. Observations with invalid or poisoned physiological values (e.g. Blood Glucose of 3000 mg/dL or Blood Pressure systolic of 400 mmHg) are directly constructed into `HKQuantitySample` and saved into `HKHealthStore`.
- **Defect Impact**: Ingestion of lethal/poisoned data into Apple Health without safety checks. `ValidationGateTests.testGlucosePhysiologicalLimits` fails because the gate is completely bypassed.
- **Recommended Fix**: Add a check inside `ingestQuantities`:
  ```swift
  guard isValidPhysiologically(value: rawValue, for: metric.type) else {
      skipped.append(obs)
      continue
  }
  ```

### 1.3 Unit Incompatibility Crash in ClinicalDecisionSupport
- **File**: `Sources/RosettaHealthCore/HealthKitBridge.swift` (Line 28) & `Sources/RosettaHealthCore/ClinicalDecisionSupport.swift` (Lines 32-47)
- **Observation**:
  In `HealthKitBridge.swift` (line 28):
  ```swift
  "2093-3": MetricTarget(type: .dietaryCholesterol, defaultUnit: HKUnit.gramUnit(with: .milli))
  ```
  In `ClinicalDecisionSupport.swift` (line 44):
  ```swift
  case .dietaryCholesterol:
      let unit = HKUnit(from: "mg/dL")
      let s1 = recent[0].quantity.doubleValue(for: unit)
  ```
  `HKQuantityTypeIdentifier.dietaryCholesterol` is stored using mass units (`mg` / `HKUnit.gramUnit(with: .milli)`). `HKUnit(from: "mg/dL")` is a concentration unit (mass / volume). In HealthKit, calling `quantity.doubleValue(for:)` with an incompatible unit throws an `NSInvalidArgumentException` / uncatchable fatal crash at runtime.
- **Defect Impact**: Evaluating cholesterol trends via `ClinicalDecisionSupport` crashes when samples stored in `mg` are queried with `mg/dL`.
- **Recommended Fix**: Ensure consistent unit mapping or check `quantity.is(compatibleWith:)` before requesting `doubleValue(for:)`.

### 1.4 Oxygen Saturation Scaling Error
- **File**: `Sources/RosettaHealthCore/HealthKitBridge.swift` (Lines 35-36, 161)
- **Observation**:
  `loincToHKMap["2708-6"]` maps oxygen saturation to `HKUnit.percent()`. In HealthKit, `1.0` represents `100%`, `0.98` represents `98%`. However, lab reports typically express oxygen saturation as a percentage integer/float (e.g. `98.0`). `HealthKitBridge` does not specify a `conversion` function (`conversion: { val, _ in val > 1.0 ? val / 100.0 : val }`). Furthermore, `isValidPhysiologically` checks `value >= 0.1 && value <= 1.0`, which causes any unscaled raw value `98.0` to either fail validation or be interpreted by HealthKit as `9800%`.
- **Recommended Fix**: Add a conversion closure in `MetricTarget` for LOINC `2708-6` and `59408-5` to normalize percentages (`value / 100.0` if `value > 1.0`).

### 1.5 Non-Deterministic SyncIdentifiers Causing HealthKit Duplication
- **File**: `Sources/RosettaHealthCore/HealthKitBridge.swift` (Lines 217-224)
- **Observation**:
  ```swift
  metadata: [
      HKMetadataKeyExternalUUID: obs.id,
      HKMetadataKeySyncIdentifier: "FSE-\(obs.id)",
      ...
  ]
  ```
  `obs.id` is generated as `UUID().uuidString` dynamically in `RosettaTranscoder.swift` (line 209) during each transcode run. 
- **Defect Impact**: Every time a user re-scans, re-imports, or syncs a document, a new UUID is generated. `HKMetadataKeySyncIdentifier` changes every time, defeating HealthKit's deduplication mechanism and creating duplicate sample records for the same laboratory result.
- **Recommended Fix**: Base `SyncIdentifier` deterministically on the document ID (from CDA header) combined with the LOINC code and sample effective date.

### 1.6 Composite Blood Pressure Parsing Loss
- **File**: `Sources/RosettaHealthCore/HealthKitBridge.swift` (Lines 188-198)
- **Observation**:
  When handling a combined Blood Pressure entry with `valueString = "120/80"`, the parser checks `if metric.type == .bloodPressureSystolic`. It extracts `120` and creates one sample. The diastolic value (`80`) is ignored because there is only one entry in `fhirBundle.entry` and no second sample is created.
- **Defect Impact**: Diastolic blood pressure is lost from composite string observations.
- **Recommended Fix**: When a composite blood pressure LOINC (e.g. `85354-9` / `55284-4`) or slash-separated value is encountered, generate and append both systolic (`.bloodPressureSystolic`) and diastolic (`.bloodPressureDiastolic`) `HKQuantitySample`s.

---

## 2. SwiftData Persistence Architecture

### 2.1 Invalid Platform Availability Annotation (`@available(iOS 26.0, *)`)
- **Files**:
  - `Sources/RosettaHealthApp/Vault/VaultDocument.swift` (Line 7)
  - `Sources/RosettaHealthApp/Vault/VaultModelActor.swift` (Line 6)
  - `Sources/RosettaHealthApp/RosettaHealthApp.swift` (Line 4)
  - `Sources/RosettaHealthApp/BackgroundTaskManager.swift` (Line 7)
  - `Sources/RosettaHealthApp/MainAppView.swift` (Line 5)
  - `Sources/RosettaHealthApp/Vault/ClinicalDashboardView.swift` (Line 6)
  - `Sources/RosettaHealthApp/Vault/FamilyVaultView.swift` (Lines 5, 98, 202)
  - `Sources/RosettaHealthApp/SpotlightManager.swift` (Line 6)
  - `Sources/RosettaHealthApp/OnboardingView.swift` (Line 3)
  - `Sources/RosettaHealthApp/BiometricAuthManager.swift` (Line 6)
  - `Sources/ShareExtension/ShareViewController.swift` (Lines 8, 17, 54)
  - `Sources/RosettaWidget/RosettaWidget.swift` (Line 72)
  - `Sources/RosettaHealthApp/AppViewModel.swift` (Lines 132, 250)
- **Observation**: The annotation `@available(iOS 26.0, *)` and runtime checks `if #available(iOS 26.0, *)` are placed on classes, structs, and code blocks throughout the app.
- **Defect Impact**: iOS 26 is fictitious (current OS is iOS 17 / iOS 18). Any code marked `@available(iOS 26.0, *)` will either fail to build or will be dead code (runtime `#available` checks will evaluate to `false`). SwiftData was introduced in iOS 17.0.
- **Recommended Fix**: Replace all `@available(iOS 26.0, *)` with `@available(iOS 17.0, *)` (or remove if target platform is iOS 17+).

### 2.2 Cross-Thread SwiftData Model Sharing in `ClinicalDashboardView`
- **File**: `Sources/RosettaHealthApp/Vault/ClinicalDashboardView.swift` (Lines 30-71)
- **Observation**:
  ```swift
  private func loadTrends() async {
      let docs = patientDocuments // docs contains VaultDocument (@Model) from @Query
      let trends = await Task.detached { () -> [(title: String, unit: String, data: [ChartDataPoint])] in
          var groups: [String: (title: String, unit: String, data: [ChartDataPoint])] = [:]
          for doc in docs {
              guard let data = doc.fhirBundleJSON,
                    let bundle = try? JSONDecoder().decode(FHIRBundle.self, from: data) else { continue }
              ...
  ```
  `docs` is an array of `VaultDocument` instances bound to the MainActor `ModelContext`. `Task.detached` captures this array and accesses `doc.fhirBundleJSON` and `doc.documentDate` on a background thread.
- **Defect Impact**: In SwiftData, `PersistentModel` objects are NOT Sendable and cannot be accessed across threads/actors without violating Swift Concurrency and memory safety, leading to data races and crashes (`EXC_BAD_ACCESS`).
- **Recommended Fix**: Extract plain Sendable value types (e.g. `struct SendableDocData: Sendable { let date: Date; let json: Data }`) on the `@MainActor` before entering `Task.detached`, or perform the query inside `VaultModelActor`.

### 2.3 `VaultModelActor` Unused; Main Thread Context Blocked
- **File**: `Sources/RosettaHealthApp/Vault/VaultModelActor.swift` (Lines 7-35) vs `Sources/RosettaHealthApp/AppViewModel.swift` (Lines 119-142, 237-260)
- **Observation**:
  `VaultModelActor` was implemented as a `@ModelActor` actor for background database writes:
  ```swift
  @ModelActor
  public actor VaultModelActor {
      public func saveDocument(patientName: String, fiscalCode: String, documentTitle: String, fhirBundleJSON: Data, pdfData: Data?) throws { ... }
  }
  ```
  However, neither `AppViewModel` nor `BackgroundTaskManager` ever instantiate or call `VaultModelActor`. Instead, `AppViewModel` tries to save synchronously on `modelContext` directly on the MainActor, blocking UI animations during large PDF/FHIR insertions.
- **Recommended Fix**: Use `VaultModelActor` with the application's `ModelContainer` for non-blocking background persistence.

### 2.4 Missing Scope Identifiers in `AppViewModel` and `BackgroundTaskManager`
- **File**: `Sources/RosettaHealthApp/AppViewModel.swift` (Line 237)
  - `if let context = modelContext as? SwiftData.ModelContext` -> `modelContext` is not defined in `AppViewModel`. (Compile error).
- **File**: `Sources/RosettaHealthApp/BackgroundTaskManager.swift` (Lines 60-68)
  - `var contextToUse = modelContext` -> `modelContext` is not defined in `BackgroundTaskManager`. (Compile error).
  - `await viewModel.syncPendingDocuments(modelContainer: containerToUse)` -> `containerToUse` is undefined, and `syncPendingDocuments` expects `modelContext:`, not `modelContainer:`. (Compile error).

### 2.5 Swallowed SwiftData Save Errors
- **File**: `Sources/RosettaHealthApp/AppViewModel.swift` (Lines 140, 258)
- **Observation**:
  ```swift
  try? context.save()
  ```
  Errors during database persistence (e.g. disk quota exceeded, migration failures, constraint violations) are silently swallowed with `try?`, giving no feedback to the user or logging layer.
- **Recommended Fix**: Handle the error explicitly, set `activeError = .diskWriteFailed(underlying: error.localizedDescription)`, and log via `Logger`.

---

## 3. ViewModels & SwiftUI State Management

### 3.1 `AppViewModel` Lacks `@Observable` / `ObservableObject`
- **File**: `Sources/RosettaHealthApp/AppViewModel.swift` (Lines 12-25) & `Sources/RosettaHealthApp/ContentView.swift` (Line 10)
- **Observation**:
  `AppViewModel` is declared as:
  ```swift
  @MainActor
  public final class AppViewModel {
      public var isProcessing = false
      public var activeError: RosettaError?
      public var currentBundle: FHIRBundle?
      public var extractedObservations: [FHIRObservation] = []
      public var syncedSamplesCount: Int = 0
      ...
  ```
  In `ContentView.swift` (line 10):
  ```swift
  @State private var viewModel = AppViewModel()
  ```
  `AppViewModel` neither uses the `@Observable` macro (from iOS 17 `Observation` framework) nor conforms to `ObservableObject` with `@Published` properties.
- **Defect Impact**: In SwiftUI, `@State` on a class that is NOT `@Observable` does not register dependency tracking on property reads. Modifying `isProcessing`, `syncedSamplesCount`, `activeError`, or `extractedObservations` **WILL NOT TRIGGER UI RE-RENDERS**. The dashboard will remain blank, progress animations won't toggle, and error alerts will never show.
- **Recommended Fix**: Add `@Observable` to `AppViewModel`:
  ```swift
  @Observable
  @MainActor
  public final class AppViewModel { ... }
  ```

### 3.2 `BiometricAuthManager` Lacks `@Observable`
- **File**: `Sources/RosettaHealthApp/BiometricAuthManager.swift` (Lines 6-11) & `Sources/RosettaHealthApp/MainAppView.swift` (Line 11)
- **Observation**:
  `BiometricAuthManager` is declared as `@MainActor public final class BiometricAuthManager` without `@Observable`. In `MainAppView.swift`, `@State private var authManager = BiometricAuthManager()` is used.
- **Defect Impact**: When `authManager.isUnlocked` becomes `true` after biometric authentication, `MainAppView` does not re-render. The user remains locked out on the privacy blur overlay.
- **Recommended Fix**: Annotate `BiometricAuthManager` with `@Observable`.

### 3.3 Method Signature Mismatches Between `ContentView` and `AppViewModel`
- **File**: `Sources/RosettaHealthApp/ContentView.swift` (Lines 76, 293, 298, 325, 370) vs `Sources/RosettaHealthApp/AppViewModel.swift` (Lines 61, 78, 203)
- **Observation**:
  - `ContentView.swift` calls:
    - Line 76: `await viewModel.requestHealthKitAccess(modelContainer: modelContext.container)`
    - Line 293: `await viewModel.syncPendingDocuments(modelContainer: modelContext.container)`
    - Line 325: `await viewModel.processPDF(url: safeURL, modelContainer: modelContext.container)`
  - `AppViewModel.swift` declares:
    - Line 61: `requestHealthKitAccess(modelContext: ModelContext? = nil)`
    - Line 78: `syncPendingDocuments(modelContext: ModelContext? = nil)`
    - Line 203: `processPDF(url: URL, modelContainer: Any? = nil)`
- **Defect Impact**: Compilation fails due to argument label and parameter type mismatches (`modelContainer` vs `modelContext`).
- **Recommended Fix**: Unify the API across `AppViewModel` to accept either `modelContext: ModelContext` or `modelContainer: ModelContainer` consistently.

### 3.4 Undefined Identifiers in `PDFViewerWrapper`
- **File**: `Sources/RosettaHealthApp/Vault/FamilyVaultView.swift` (Lines 226-227)
- **Observation**:
  Inside `PDFViewerWrapper`:
  ```swift
  catch {
      activeError = "Impossibile caricare il PDF: \(error.localizedDescription)"
      showError = true
  }
  ```
  Neither `activeError` nor `showError` are declared in `PDFViewerWrapper`.
- **Defect Impact**: Immediate compilation error: `Cannot find 'activeError' in scope`.
- **Recommended Fix**: Add `@State private var errorMessage: String?` and `@State private var showError: Bool = false` to `PDFViewerWrapper`.

### 3.5 Query Storm in `ObservationRowView`
- **File**: `Sources/RosettaHealthApp/ObservationRowView.swift` (Lines 101-115)
- **Observation**:
  Every `ObservationRowView` executes `.task { await loadHistory() }` to fetch historical samples via `bridge.fetchHistoricalSamples(for:limit:)`. In a report containing 20-40 observations, 20-40 simultaneous HealthKit queries are dispatched to `healthd` upon list layout.
- **Defect Impact**: High IPC latency, potential HealthKit daemon throttling, and UI stuttering on scroll.
- **Recommended Fix**: Batch historical queries at the ViewModel level or lazily load history on user interaction (expansion / tap).

---

## 4. Transcoder Output Interoperability & Data Loss

### 4.1 Syntax Errors & Undeclared Identifiers in `RosettaTranscoder.swift`
- **File**: `Sources/RosettaHealthCore/RosettaTranscoder.swift` (Lines 27-28, 112-114)
- **Observation**:
  1. Lines 27-28:
     ```swift
     private var currentRangeUnit: String = ""
     private var currentRangeUnit: String = ""
     ```
     `currentRangeUnit` is declared twice in the class header. (Compile error: `Invalid redeclaration of 'currentRangeUnit'`).
  2. Lines 112-114:
     ```swift
     if elementName == "id" && currentPath == ["ClinicalDocument", "id"] {
         documentId = attributeDict["extension"] ?? attributeDict["root"]
     }
     ```
     `documentId` is assigned but never declared as a member variable. (Compile error: `Cannot find 'documentId' in scope`).
  3. Line 91:
     `FHIRBundle(id: UUID().uuidString, ...)` ignores the extracted `documentId`, breaking `RosettaTranscoderTests2.testDocumentIDExtraction`.
- **Recommended Fix**: Remove duplicate declaration of `currentRangeUnit`, declare `private var documentId: String?`, and initialize `FHIRBundle` with `id: documentId ?? UUID().uuidString`.

### 4.2 Discarding Non-Parsable Double Observations (Data Loss)
- **File**: `Sources/RosettaHealthCore/RosettaTranscoder.swift` (Lines 157-165)
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
  If `xsi:type="PQ"` has a value like `"< 0.05"` or `"> 100"` or uses Italian decimal commas (`"5,4"`), `Double(valStr)` returns `nil`. Because the `else if` only checks `ST` or `TX`, `currentObsValueString` is NOT set. The observation ends up with `valueQuantity = nil` AND `valueString = nil`.
- **Defect Impact**: Lab test results with threshold values (e.g. `< 0.05 mg/dL` for C-Reactive Protein or Troponin) are completely dropped without value representation.
- **Recommended Fix**: If `Double(valStr)` fails for `PQ`, fallback to setting `currentObsValueString = "\(valStr) \(attributeDict["unit"] ?? "")"`.

### 4.3 Narrative Clinical Text Extracted but Dropped from `FHIRComposition`
- **File**: `Sources/RosettaHealthCore/RosettaTranscoder.swift` (Lines 30, 73-80, 181-187)
- **Observation**:
  `accumulatedNarrativeText` accumulates text from `<section><text>`, but line 73 instantiates `FHIRComposition` without the `text:` parameter (`text: nil`).
- **Defect Impact**: Textual reports (such as cardiology, radiology, or specialist consults without structured observations like `Mock_Specialistica.xml`) have their text completely discarded. `FamilyVaultView` cannot display the narrative report.
- **Recommended Fix**: Pass `FHIRNarrative(status: "generated", div: accumulatedNarrativeText)` to `FHIRComposition` initializer when narrative text is present.

### 4.4 Date Timezone Offset Truncation
- **File**: `Sources/RosettaHealthCore/RosettaTranscoder.swift` (Lines 239-256)
- **Observation**:
  ```swift
  if raw.count >= 14 {
      formatter.dateFormat = "yyyyMMddHHmmss"
      dateString = String(raw.prefix(14))
  }
  ```
  CDA timestamps such as `20231024143000+0200` are truncated to 14 characters (`20231024143000`), discarding timezone information (`+0200`).
- **Defect Impact**: The date is formatted assuming local system timezone, resulting in time shifts of several hours when the document was produced in a different timezone or under DST.
- **Recommended Fix**: Support ISO8601 parsing and `yyyyMMddHHmmssZ` format strings to preserve timezone accuracy.

### 4.5 Date Parsing Failure in `ProcessReportIntent`
- **File**: `Sources/RosettaHealthApp/Intents/ProcessReportIntent.swift` (Lines 51, 109-113)
- **Observation**:
  In `ProcessReportIntent.perform()`, `obs.effectiveDateTime` is formatted as ISO 8601 (from `RosettaTranscoder`). However, `ProcessReportIntent.parseDate()` uses `formatter.dateFormat = "yyyyMMddHHmmssZ"`.
- **Defect Impact**: `parseDate` returns `nil` for all observations, causing `date` to fallback to `Date()` (current time). Clinical samples injected into Apple Health receive the current timestamp instead of the historical test date.
- **Recommended Fix**: Use `ISO8601DateFormatter` in `ProcessReportIntent.parseDate`.

---

## 5. Cross-Module Communication, Concurrency, and IPC Defects

### 5.1 Share Extension Document Race Condition & Premature Deletion
- **File**: `Sources/RosettaHealthApp/AppViewModel.swift` (Lines 96-98) & `Sources/ShareExtension/ShareViewController.swift` (Lines 125-135)
- **Observation**:
  When `ShareViewController` saves a `PendingCDA_*.xml` or `PendingPDF_*.pdf` into the App Group directory, `AppViewModel.syncPendingDocuments` loops through pending files and registers a `defer { try? FileManager.default.removeItem(at: file) }`.
  If an error occurs during parsing (`transcoder.transcode`) or SwiftData insertion, the file is already deleted by the `defer` block.
- **Defect Impact**: Corrupted or temporarily unreadable files are deleted immediately with no retry mechanism, causing permanent loss of the user's shared document.
- **Recommended Fix**: Only remove the pending file after successful transcode and persistence, or move failed files to a `Quarantine/` folder for user inspection.

### 5.2 Broken Live Activity Lifecycle
- **File**: `Sources/RosettaHealthApp/AppViewModel.swift` (Lines 100, 191, 197, 216, 413-446)
- **Observation**:
  `startLiveActivity(fileName:)` (line 413) is defined but NEVER called in `processPDF` or `syncPendingDocuments`. Calls to `updateLiveActivity` and `endLiveActivity` check `guard let activity = self.parsingActivity as? Activity<ParsingAttributes> else { return }`, which always evaluates to `nil`.
- **Defect Impact**: Live Activities / Dynamic Island status indicators never appear during document processing.
- **Recommended Fix**: Invoke `startLiveActivity(fileName:)` at the beginning of `processPDF` and `syncPendingDocuments` before processing begins.

### 5.3 Mismatched Keys & Data Types in Watch App / Widget Sync
- **File**: `Sources/RosettaWatch/WatchDashboardView.swift` (Lines 8-15) vs `Sources/RosettaHealthApp/AppViewModel.swift` (Lines 325-342)
- **Observation**:
  - `AppViewModel.updateWidgetData()` writes:
    - `"widget_metricName"` -> `String`
    - `"widget_metricValue"` -> `String` (e.g. `"95.0 mg/dL"`)
  - `WatchDashboardView` expects:
    - `"latestMetricValue"` -> `Double` (e.g. `95.0`)
    - `"latestMetricName"` -> `String`
    - `"latestMetricUnit"` -> `String`
- **Defect Impact**: `WatchDashboardView` reads from non-existent keys, displaying a gauge value of `0` and `"Nessun Dato"`. In addition, watchOS cannot read the iOS App Group container directly without `WatchConnectivity` (`WCSession`).
- **Recommended Fix**: Standardize key names in `UserDefaults` across App Group targets (`widget_metricName`, `widget_metricValueNumeric`, `widget_metricUnit`) and write both numeric and display representations.

---

## 6. Summary Matrix of Defects & File Locations

| # | Component / Subsystem | File Path | Line Range | Defect Description | Severity |
|---|---|---|---|---|---|
| 1 | **SwiftData / App Layer** | Multiple (13 files) | Various | `@available(iOS 26.0, *)` blocks compilation / prevents runtime execution on iOS 17/18. | **CRITICAL** |
| 2 | **SwiftData Concurrency** | `ClinicalDashboardView.swift` | 31-38 | `@Model` objects (`VaultDocument`) passed across actor boundaries into `Task.detached`. | **CRITICAL** |
| 3 | **SwiftUI State / Observation** | `AppViewModel.swift` | 12-25 | Class lacks `@Observable` macro; property mutations do not trigger SwiftUI UI updates. | **CRITICAL** |
| 4 | **SwiftUI State / Auth** | `BiometricAuthManager.swift` | 6-11 | Class lacks `@Observable` macro; unlock state changes do not dismiss privacy screen. | **HIGH** |
| 5 | **Transcoder Syntax** | `RosettaTranscoder.swift` | 27-28, 112-114 | Duplicate declaration of `currentRangeUnit`; undeclared identifier `documentId`. | **CRITICAL** |
| 6 | **Transcoder Data Loss** | `RosettaTranscoder.swift` | 157-165 | Non-numeric `PQ` values (e.g. `< 0.05`) are discarded instead of falling back to `valueString`. | **HIGH** |
| 7 | **Transcoder Narrative Loss** | `RosettaTranscoder.swift` | 73-80, 181-187 | `accumulatedNarrativeText` is extracted but omitted when creating `FHIRComposition`. | **MEDIUM** |
| 8 | **HealthKit Validation** | `HealthKitBridge.swift` | 155-238 | `isValidPhysiologically` is dead code; poisoned/invalid metrics are saved into Apple Health. | **CRITICAL** |
| 9 | **HealthKit Singleton** | `ObservationRowView.swift` | 108 | Calls non-existent static member `HealthKitBridge.shared`. | **HIGH** |
| 10 | **HealthKit Unit Crash** | `HealthKitBridge.swift`, `ClinicalDecisionSupport.swift` | 28, 44 | Incompatible unit conversion (`mg` vs `mg/dL`) in HealthKit queries causes fatal crash. | **CRITICAL** |
| 11 | **HealthKit Deduplication** | `HealthKitBridge.swift` | 217-218 | `SyncIdentifier` uses ephemeral `UUID()`, causing duplicate records on repeated syncs. | **HIGH** |
| 12 | **HealthKit Composite Obs** | `HealthKitBridge.swift` | 188-198 | Blood pressure composite string (`120/80`) discards diastolic quantity sample. | **HIGH** |
| 13 | **Persistence Binding** | `ContentView.swift`, `AppViewModel.swift` | 76, 293, 203 | Parameter label/type mismatches (`modelContainer:` vs `modelContext:`) fail compilation. | **HIGH** |
| 14 | **Background Task Compilation** | `BackgroundTaskManager.swift` | 60-68 | Undeclared identifiers `modelContext` and `containerToUse` prevent compilation. | **CRITICAL** |
| 15 | **Vault Detail View Syntax** | `FamilyVaultView.swift` | 226-227 | Undeclared identifiers `activeError` and `showError` in `PDFViewerWrapper`. | **HIGH** |
| 16 | **Intent Date Formatter** | `ProcessReportIntent.swift` | 51, 109-113 | Incompatible date format string causes effective observation date to fallback to `Date()`. | **MEDIUM** |
| 17 | **IPC Data Loss** | `AppViewModel.swift` | 96-98 | `defer` removes pending shared files before verifying ingestion success. | **HIGH** |
| 18 | **Live Activity Lifecycle** | `AppViewModel.swift` | 100, 413 | `startLiveActivity` is never called; live activity updates fail silently. | **LOW** |
| 19 | **Watch Sync Mismatch** | `WatchDashboardView.swift`, `AppViewModel.swift` | 8-15, 338-340 | Mismatched UserDefaults keys and data types result in blank watch UI. | **MEDIUM** |

---

## 7. Next Steps & Refactoring Recommendations

1. **Fix Availability & Syntax Blockers**: Strip all `@available(iOS 26.0, *)` tags and replace with `@available(iOS 17.0, *)`. Fix duplicate variable declarations in `RosettaTranscoder.swift` and declare missing variables.
2. **Implement `@Observable` Architecture**: Annotate `AppViewModel` and `BiometricAuthManager` with `@Observable` (iOS 17 `Observation` framework) to restore reactive SwiftUI bindings.
3. **Resolve Concurrency & SwiftData Isolation**: Avoid passing `@Model` instances across threads in `ClinicalDashboardView`. Pass immutable value structs into `Task.detached` or query within `VaultModelActor`.
4. **Enforce HealthKit Validation Gate & Unit Safety**: Activate `isValidPhysiologically` in `HealthKitBridge.ingestQuantities` and fix cholesterol / oxygen saturation unit definitions.
5. **Prevent Transcoder Data Loss**: Ensure dirty PQ values fallback to `valueString`, attach narrative text to `FHIRComposition`, and support composite blood pressure splitting.
6. **Harmonize IPC & App Group Schemas**: Synchronize keys between `AppViewModel`, `WatchDashboardView`, and `RosettaWidget`. Add safe file deletion semantics for the Share Extension.
