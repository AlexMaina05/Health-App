# In-Depth Architectural & Codebase Survey Report: RosettaHealth iOS

**Author**: Explorer Survey Agent 1  
**Date**: 2026-09-01T23:04:00+02:00  
**Target Workspace**: `e:/Code/Health-App`  
**Focus Areas**: RosettaTranscoder, HL7 CDA XML parsing, FHIR R4/IPS models, HealthKit Bridge, SwiftData Vault, ViewModels, Concurrency, and Error Handling.

---

## 1. Executive Summary

RosettaHealth is designed as a privacy-first, Zero-Cloud (GDPR Art. 9 compliant) iOS application that extracts structured clinical data from Italian Electronic Health Record (FSE 2.0) PDF/A-3 documents containing embedded HL7 CDA Release 2 XML payloads. The pipeline transcodes CDA documents into FHIR R4 / IPS (International Patient Summary) resources, segregates records by patient identity (Codice Fiscale firewall), routes owner metrics to Apple Health (HealthKit) and family records to a local encrypted SwiftData Vault, and computes local Clinical Decision Support (CDS) trend alerts.

Our systematic audit of the entire codebase (`Sources/`, `Tests/`, `MockData/`) revealed several critical defect categories:
1. **Compilation & Syntax Blockers**: Duplicate variable declarations, undeclared variables across multiple view and model files, mismatched SwiftData parameter signatures, syntax brace mismatches in `OnboardingView.swift`, non-existent static singletons (e.g. `HealthKitBridge.shared`), and non-existent iOS 26 API usages (`@available(iOS 26.0, *)`, `glassEffect`).
2. **HL7 CDA SAX Parsing & Data Loss**: Inability to parse European comma-formatted decimals (e.g., `"94,5"`), loss of inequality/range-bounded metrics (e.g., `"< 0.05 mg/dL"`), unhandled XML character text for string values, ignored coded observations (`CD`/`CE`), lack of LOINC translation fallback, and dropping accumulated narrative clinical text from the output `FHIRComposition`.
3. **HealthKit Validation Gate Dead Code**: The physiological validation function `isValidPhysiologically` in `HealthKitBridge` is completely uncalled, allowing lethal or corrupted values (e.g., Glucose = 3000 mg/dL) to bypass safety gates. Missing LOINC mappings for standard panels (e.g., Blood Pressure composite `85354-9`).
4. **Reactivity & Concurrency Safety**: `AppViewModel` lacks the `@Observable` macro, preventing SwiftUI view updates; SwiftData `@Model` references are transferred across concurrency boundaries into detached tasks in `ClinicalDashboardView`, violating actor isolation.

---

## 2. HL7 CDA XML Parsing & Transcoder Architecture (`RosettaTranscoder.swift`)

The core parsing engine `RosettaTranscoder` uses Apple's Foundation `XMLParser` (SAX event-driven parser). While memory-efficient and hardened against XXE/Billion-Laughs attacks via `shouldResolveExternalEntities = false`, the current implementation contains severe structural and logic defects.

### 2.1 Compilation Blockers & Syntax Issues
- **Duplicate Property Declaration**:
  - `Sources/RosettaHealthCore/RosettaTranscoder.swift:27-28`:
    ```swift
    27: private var currentRangeUnit: String = ""
    28: private var currentRangeUnit: String = ""
    ```
    Duplicate declaration of `currentRangeUnit` fails Swift compilation (`Invalid redeclaration of 'currentRangeUnit'`).
- **Undeclared Variable `documentId`**:
  - `Sources/RosettaHealthCore/RosettaTranscoder.swift:112-114`:
    ```swift
    if elementName == "id" && currentPath == ["ClinicalDocument", "id"] {
        documentId = attributeDict["extension"] ?? attributeDict["root"]
    }
    ```
    `documentId` is neither declared as an instance variable nor in local scope.
- **Hardcoded Bundle ID & Ignored Document ID**:
  - `Sources/RosettaHealthCore/RosettaTranscoder.swift:90-95`:
    ```swift
    return FHIRBundle(
        id: UUID().uuidString,
        type: "document",
        timestamp: ISO8601DateFormatter().string(from: Date()),
        entry: bundleEntries
    )
    ```
    The extracted document identifier is completely discarded. The test `RosettaTranscoderTests2.testDocumentIDExtraction` expects `bundle.id == "SOLE_DOC_12345"`, but the transcoder always generates a random UUID.

### 2.2 Numerical Parsing, Comma Formatting & Relational Operators (Data Loss)
- **Vulnerability**: In Italian FSE laboratory reports, decimal numbers frequently use commas (`"94,5"` instead of `"94.5"`), or contain inequality operators (`"< 0.05"`, `"> 100"`, `"<0.01"`).
- **Flawed Code** (`RosettaTranscoder.swift:157-165`):
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
- **Failure Mechanism**:
  1. If `valStr` is `"94,5"`, `Double(valStr)` returns `nil`. Because `type == "PQ"`, it evaluates the `if` condition to `false` and skips the `else if` branch. Both `currentObsValue` and `currentObsValueString` remain `nil`. The clinical measurement is permanently lost.
  2. If `valStr` is `"< 0.05"`, `Double(valStr)` fails. The value is not captured as string or quantity. This breaks `RosettaTranscoderTests2.testDirtyXMLValuesFallback`.
  3. When `type == "ST"` or `"TX"`, the unit attribute (e.g. `unit="mg/dL"`) is ignored, and only `attributeDict["value"]` is stored, omitting the unit from `valueString`.

### 2.3 XML Text Elements vs XML Attributes
- In HL7 CDA R2, text values for `ST` and `TX` elements can be embedded as XML character data: `<value xsi:type="ST">Positivo</value>` rather than an XML attribute `value="..."`.
- `RosettaTranscoder` only inspects `attributeDict["value"]` on line 163. If the XML text is contained inside the element body, it is never captured into `currentObsValueString`.

### 2.4 Unhandled CDA Data Types
- `xsi:type="CD"`, `"CE"`, `"CO"` (Coded concepts, e.g., `<value xsi:type="CD" code="POS" displayName="Positivo"/>`): Ignored.
- `xsi:type="IVL_PQ"` (Intervals with low/high bounds): Ignored in `<value>`.
- `<code>` with `<translation>`: CDA documents (like SOLE / Emilia-Romagna) provide local laboratory codes in `<code code="1319" codeSystem="...DNLAB">` and standard national/LOINC codes in child `<translation code="023" codeSystem="...SOLE" displayName="Ematocrito (HCT)"/>`. `RosettaTranscoder` only looks at attributes on the `<code>` tag and ignores `<translation>` tags, missing LOINC mappings.

### 2.5 Reference Range & Narrative Text Defects
- `currentRangeText` is declared on line 29, but never assigned during parsing. Reference ranges represented as text descriptions (`<text>Normale &lt; 5.0</text>`) are dropped.
- `accumulatedNarrativeText` accumulates clinical section text on lines 182-187, but when constructing `FHIRComposition` on lines 73-79, `text:` is passed as `nil`, losing all narrative clinical findings.

### 2.6 Date and Timezone Handling
- `normalizeCDADate` (`RosettaTranscoder.swift:239-256`):
  ```swift
  if raw.count >= 14 {
      formatter.dateFormat = "yyyyMMddHHmmss"
      dateString = String(raw.prefix(14))
  }
  ```
  CDA timestamps such as `20251129130208+0100` have their timezone offset `+0100` stripped by `raw.prefix(14)`. When parsed by `formatter.date(from:)` without explicit timezone configuration, the time is parsed in local device time, altering the timestamp.

---

## 3. FHIR Models & Schemas (`FHIRModels.swift`)

The models in `FHIRModels.swift` represent standard HL7 FHIR R4 resources with IPS (International Patient Summary) profile markers:
- `FHIRBundle`: Container of type `"document"` or `"collection"`.
- `FHIRComposition`: Clinical report header, clinical category, patient reference, document date, and narrative text.
- `FHIRPatient`: Anagraphics, Codice Fiscale identifier (`http://hl7.it/sid/codiceFiscale`), family/given names.
- `FHIRObservation`: Lab and vital sign measurements with `code`, `valueQuantity`, `valueString`, and `referenceRange`.

### Findings:
1. `FHIRBundleEntry.resource` is a polymorphic enum `FHIRResource` (`observation`, `patient`, `composition`). Its custom `Codable` implementation works well.
2. In `FHIRComposition`, the `text: FHIRNarrative?` property exists, confirming the model supports narrative text, but `RosettaTranscoder` omitted passing it during initialization.
3. In `FHIRObservation`, `effectiveDateTime` is declared as `public let effectiveDateTime: String` (non-optional). In `ProcessReportIntent.swift:51`, code attempts `obs.effectiveDateTime ?? ""`, which causes compiler warnings.

---

## 4. HealthKit Bridge & Validation Gate (`HealthKitBridge.swift`)

`HealthKitBridge` interfaces between domain FHIR observations and Apple HealthKit (`HKHealthStore`).

### 4.1 Inactive Physiological Validation Gate (Dead Code)
- `HealthKitBridge.swift:155-167` defines:
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
- **Defect**: `isValidPhysiologically` is NEVER CALLED anywhere in `ingestQuantities` or `ingestRawMetrics`.
- **Consequence**: `ValidationGateTests.testGlucosePhysiologicalLimits` fails because a lethal glucose value (3000 mg/dL) is accepted and added to `samplesToSave` rather than appended to `skippedObservations`.

### 4.2 Incomplete LOINC Mappings & Blood Pressure Handling
- `loincToHKMap` lacks `"85354-9"` (Blood pressure panel systolic and diastolic).
- For composite blood pressure strings (`"120/80"`), the parsing in `ingestQuantities` (lines 188-198) only assigns `finalValue` for a single `HKQuantityTypeIdentifier`. It cannot split a single observation into two distinct HealthKit samples (Systolic and Diastolic) when given a composite code.

### 4.3 Missing Static Singleton `HealthKitBridge.shared`
- `Sources/RosettaHealthApp/ObservationRowView.swift:108`:
  ```swift
  let bridge = HealthKitBridge.shared
  ```
  `HealthKitBridge` does NOT define `public static let shared = HealthKitBridge()`. This prevents compilation of `ObservationRowView`.

---

## 5. Persistence, Concurrency & Family Vault (`VaultDocument.swift`, `VaultModelActor.swift`, `FamilyVaultView.swift`)

### 5.1 Fantasy iOS 26 Availability Blockers
Throughout the app files, `@available(iOS 26.0, *)` is applied:
- `VaultDocument.swift:7`
- `VaultModelActor.swift:6`
- `RosettaHealthApp.swift:4`
- `MainAppView.swift:5`
- `FamilyVaultView.swift:5, 98, 202`
- `ClinicalDashboardView.swift:6`
- `BiometricAuthManager.swift:6`
- `SpotlightManager.swift:6`
- `OnboardingView.swift:3`
- `ShareViewController.swift:8, 17, 54`
- `RosettaWidget.swift:72`

**Impact**: iOS 26 does not exist (current iOS is 17/18). SwiftData and modern SwiftUI features used here are available in iOS 17.0+.

### 5.2 SwiftData Actor Isolation & Thread Safety Violation
- In `ClinicalDashboardView.swift:31-32`:
  ```swift
  let docs = patientDocuments
  let trends = await Task.detached { () -> [(title: String, unit: String, data: [ChartDataPoint])] in
      for doc in docs {
          guard let data = doc.fhirBundleJSON ...
      }
  }
  ```
  `docs` contains `[VaultDocument]` models tied to the main actor's `ModelContext`. Passing them across actor boundaries into `Task.detached` causes concurrency crashes or data race warnings. Instead, data extraction (e.g., extracting JSON `Data` or using `VaultModelActor`) should happen safely.

### 5.3 Undefined Variables in `PDFViewerWrapper`
- `FamilyVaultView.swift:226-227`:
  ```swift
  } catch {
      activeError = "Impossibile caricare il PDF: \(error.localizedDescription)"
      showError = true
  }
  ```
  `activeError` and `showError` are not declared anywhere in `PDFViewerWrapper`.

---

## 6. Cross-Module Communication & ViewModels (`AppViewModel.swift`, `ContentView.swift`, `BackgroundTaskManager.swift`)

### 6.1 Parameter Signature Incompatibilities
1. **`requestHealthKitAccess`**:
   - Declared in `AppViewModel.swift:61`: `public func requestHealthKitAccess(modelContext: ModelContext? = nil) async`
   - Called in `ContentView.swift:76`: `await viewModel.requestHealthKitAccess(modelContainer: modelContext.container)` -> Argument label mismatch (`modelContainer:` vs `modelContext:`).
2. **`syncPendingDocuments`**:
   - Declared in `AppViewModel.swift:78`: `public func syncPendingDocuments(modelContext: ModelContext? = nil) async`
   - Called in `ContentView.swift:293, 298`: `await viewModel.syncPendingDocuments(modelContainer: modelContext.container)` -> Argument label mismatch.
   - Called in `BackgroundTaskManager.swift:68`: `await viewModel.syncPendingDocuments(modelContainer: containerToUse)` -> `containerToUse` undefined variable, and argument label mismatch.
3. **`processPDF`**:
   - Declared in `AppViewModel.swift:203`: `public func processPDF(url: URL, modelContainer: Any? = nil) async`
   - Body at line 237: `if let context = modelContext as? SwiftData.ModelContext` -> `modelContext` is not an argument of `processPDF` and does not exist in `AppViewModel`.
   - Called in `ContentView.swift:325, 370`: `await viewModel.processPDF(url: safeURL, modelContainer: modelContext.container)`.

### 6.2 SwiftUI UI Reactivity Blockers
- `AppViewModel` imports `Observation`, but lacks the `@Observable` macro annotation on `public final class AppViewModel`.
- `BiometricAuthManager` lacks `@Observable`.
- As a result, mutations to published state (`isProcessing`, `syncedSamplesCount`, `extractedObservations`, `activeError`, `isUnlocked`) do not trigger SwiftUI view re-renders.

### 6.3 Syntax Error in `OnboardingView.swift`
- `OnboardingView.swift:188-198`: An extra closing brace `}` at line 189 prematurely terminates `Form`, placing the subsequent `Section` outside `Form` and creating mismatched brace counts.

### 6.4 Non-Existent UI Methods
- `Sources/RosettaHealthApp/LiquidGlass.swift:7`:
  ```swift
  self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
  ```
  `glassEffect` is not a standard SwiftUI View modifier in iOS 17.

---

## 7. Clinical Decision Support, OCR & Fallback Pipeline

### 7.1 Clinical Decision Support (`ClinicalDecisionSupport.swift`)
- Correctly analyzes 3-point chronological historical trend lines for Cholesterol (`.dietaryCholesterol`), Blood Glucose (`.bloodGlucose`), and Blood Pressure (`.bloodPressureSystolic`).
- Triggers local notifications via `UNUserNotificationCenter` when worsening trend criteria are met.
- Unit compatibility check uses `HKUnit(from: "mg/dL")` and `HKUnit.millimeterOfMercury()`.

### 7.2 Vision OCR Fallback (`VisionOCRExtractor.swift`)
- Implements Graceful Degradation (Plan C) when a PDF lacks embedded XML attachments.
- Renders PDF pages to `CGImage` off the main thread and runs `VNRecognizeTextRequest` with Italian (`it-IT`) and English (`en-US`) language hints.
- Uses regex patterns to extract Glycemia, Cholesterol, HDL, Triglycerides, Heart Rate, and Blood Pressure.
- Attaches provenance metadata (`EXTRACTION_METHOD: "APPLE_VISION_OCR_FALLBACK"`, `CONFIDENCE_LEVEL: "HEURISTIC_REGEX"`) upon ingestion into HealthKit.

---

## 8. Security, GDPR & Zero-Cloud Isolation Compliance

1. **Network Isolation**: Zero external network requests (`URLSession`, Alamofire, or telemetry SDKs). All transcoding, OCR, and storage operations are performed 100% on-device.
2. **Patient Segregation Firewall**: `AppViewModel.extractPatientInfo` extracts the Codice Fiscale from the FHIR Patient resource (`http://hl7.it/sid/codiceFiscale`) and compares it to `ownerFiscalCode` stored in Keychain. If they mismatch, HealthKit injection is bypassed and records are routed strictly to the encrypted SwiftData Family Vault (if PRO unlocked).
3. **Data Protection**: Temporary files and App Group container files enforce `FileProtectionType.complete` and `completeUntilFirstUserAuthentication`.

---

## 9. Comprehensive Defect Inventory

| ID | Component | File & Line | Severity | Description | Proposed Fix |
|---|---|---|---|---|---|
| **DEF-01** | Transcoder | `RosettaTranscoder.swift:27-28` | **CRITICAL (Compile)** | Duplicate `currentRangeUnit` variable declaration. | Remove redundant declaration. |
| **DEF-02** | Transcoder | `RosettaTranscoder.swift:113` | **CRITICAL (Compile)** | Undeclared `documentId` variable. | Declare `private var documentId: String?` and assign to `bundle.id`. |
| **DEF-03** | Transcoder | `RosettaTranscoder.swift:90-95` | **HIGH (Logic)** | `bundle.id` always set to random UUID, ignoring extracted document ID. | Use `documentId ?? UUID().uuidString`. |
| **DEF-04** | Transcoder | `RosettaTranscoder.swift:157-165` | **CRITICAL (Data Loss)** | Numerical parsing fails on comma decimals (`"94,5"`) and inequality strings (`"< 0.05"`). | Sanitize commas (`replacingOccurrences(of: ",", with: ".")`), parse inequalities into `valueString`, and append unit. |
| **DEF-05** | Transcoder | `RosettaTranscoder.swift:163` | **MEDIUM (Parsing)** | `ST`/`TX` values in XML element bodies are missed (only XML attribute checked). | Check XML body text in `didEndElement` as fallback. |
| **DEF-06** | Transcoder | `RosettaTranscoder.swift:202` | **MEDIUM (Parsing)** | `currentRangeText` is never populated during SAX parsing. | Capture narrative text in `<referenceRange>` into `currentRangeText`. |
| **DEF-07** | Transcoder | `RosettaTranscoder.swift:73-79` | **MEDIUM (Data Loss)** | `accumulatedNarrativeText` is discarded and not passed to `FHIRComposition(text:)`. | Pass `text: FHIRNarrative(div: accumulatedNarrativeText)` when non-empty. |
| **DEF-08** | Transcoder | `RosettaTranscoder.swift:239-256` | **MEDIUM (Logic)** | `normalizeCDADate` truncates timezone offset (`+0100`), shifting dates. | Use proper ISO8601 / timezone-aware DateFormatter. |
| **DEF-09** | HealthKit | `HealthKitBridge.swift:155, 174` | **CRITICAL (Safety)** | `isValidPhysiologically` validation gate is uncalled dead code. | Call `isValidPhysiologically` in `ingestQuantities` before saving; append invalid to `skipped`. |
| **DEF-10** | HealthKit | `HealthKitBridge.swift:20` | **MEDIUM (Feature)** | Missing LOINC `"85354-9"` (Blood pressure panel) in `loincToHKMap`. | Add composite systolic/diastolic splitting logic for blood pressure panel. |
| **DEF-11** | HealthKit | `HealthKitBridge.swift:4` | **CRITICAL (Compile)** | Missing `public static let shared = HealthKitBridge()`. | Add singleton accessor `public static let shared = HealthKitBridge()`. |
| **DEF-12** | App / ViewModels | `AppViewModel.swift:13` | **HIGH (Reactivity)** | Missing `@Observable` macro on `AppViewModel`. | Annotate `@Observable` on `AppViewModel`. |
| **DEF-13** | App / ViewModels | `AppViewModel.swift:203, 237` | **CRITICAL (Compile)** | Undeclared `modelContext` referenced in `processPDF`. | Accept `modelContext: SwiftData.ModelContext?` or resolve from `modelContainer`. |
| **DEF-14** | App / ViewModels | `AppViewModel.swift:61, 78` vs `ContentView.swift:76, 293` | **CRITICAL (Compile)** | Argument label mismatch (`modelContext:` vs `modelContainer:`). | Standardize parameter labels across `AppViewModel` and `ContentView`. |
| **DEF-15** | Background | `BackgroundTaskManager.swift:60, 68` | **CRITICAL (Compile)** | Undeclared `modelContext` and `containerToUse`. | Fix container instantiation and pass valid context. |
| **DEF-16** | Views | `FamilyVaultView.swift:226-227` | **CRITICAL (Compile)** | Undeclared `activeError` and `showError` in `PDFViewerWrapper`. | Declare `@State private var errorMessage: String?` or remove invalid lines. |
| **DEF-17** | Views | `OnboardingView.swift:189` | **CRITICAL (Compile)** | Extra closing brace `}` causing syntax error. | Fix Form closure hierarchy. |
| **DEF-18** | UI / Theme | `LiquidGlass.swift:7` | **CRITICAL (Compile)** | Calls non-existent `glassEffect` API. | Replace with standard ultraThinMaterial styling. |
| **DEF-19** | Compatibility | Multiple files | **CRITICAL (Compile)** | `@available(iOS 26.0, *)` fantasy annotations. | Change to `@available(iOS 17.0, *)` or remove where platform target is already iOS 17. |
| **DEF-20** | SwiftData / Concurrency | `ClinicalDashboardView.swift:31-32` | **HIGH (Safety)** | `[VaultDocument]` models passed into `Task.detached`. | Extract raw JSON `Data` or model IDs before background task execution. |
| **DEF-21** | Intents | `ProcessReportIntent.swift:51` | **LOW (Warning)** | `obs.effectiveDateTime ?? ""` nil-coalescing on non-optional `String`. | Remove unnecessary `?? ""` and redundant `try`. |

---

## 10. Recommended Next Steps for Implementation

1. **Fix `RosettaHealthCore` Transcoder & HealthKit Bridge**:
   - Fix duplicate `currentRangeUnit` and declare `documentId`.
   - Implement comma-to-dot normalization and relational string fallback (`< 0.05 mg/dL`).
   - Hook up `isValidPhysiologically` validation gate in `HealthKitBridge.ingestQuantities`.
   - Add `HealthKitBridge.shared` and LOINC `"85354-9"` panel handling.
   - Attach narrative text to `FHIRComposition`.
2. **Fix `RosettaHealthApp` Architecture & ViewModels**:
   - Annotate `AppViewModel` and `BiometricAuthManager` with `@Observable`.
   - Harmonize `modelContext:` / `modelContainer:` signatures across `AppViewModel`, `ContentView`, and `BackgroundTaskManager`.
   - Replace `@available(iOS 26.0, *)` with `@available(iOS 17.0, *)`.
   - Fix `OnboardingView.swift` syntax and `FamilyVaultView.swift` undeclared variables.
   - Isolate SwiftData queries in `ClinicalDashboardView` to prevent concurrency violations.
3. **Integration & End-to-End Testing**:
   - Ensure all existing unit tests in `Tests/RosettaHealthCoreTests/` pass.
   - Add comprehensive integration tests verifying end-to-end flow from CDA XML parsing to ViewModel state and HealthKit/SwiftData.
