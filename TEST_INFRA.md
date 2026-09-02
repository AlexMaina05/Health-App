# Test Infrastructure & Architecture Specification (`TEST_INFRA.md`)

## 1. Overview & Architecture
RosettaHealth is a privacy-first, on-device iOS clinical document transcode and aggregation system.
The test infrastructure is architected to guarantee deterministic, isolated, zero-cloud verification of:
- HL7 CDA R2 XML SAX parsing into HL7 FHIR R4 / International Patient Summary (IPS) bundles.
- Physiological validation gating and biometric safety boundaries before HealthKit ingestion.
- Patient Firewall security routing (Owner matching -> HealthKit, Non-owner mismatch -> SwiftData Family Vault).
- Clinical Decision Support (CDS) preventative trend analysis.
- Multi-patient SwiftData in-memory persistence and isolation.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   XCTest Integration Test Pipeline                      │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
         ┌───────────────────────────┴───────────────────────────┐
         ▼                                                       ▼
┌─────────────────────────────────┐             ┌─────────────────────────────────┐
│       Tier 1: Feature           │             │       Tier 2: Boundary &        │
│          Coverage               │             │          Corner Cases           │
│  - CDA -> FHIR Transcoding      │             │  - Malformed & Empty XML        │
│  - Validation Gate Accept/Reject│             │  - Billion Laughs XXE Attack    │
│  - Firewall Owner Routing       │             │  - Exact Min/Max Thresholds     │
│  - Anonymous Fuzzy Name Match   │             │  - Comma Decimals & Fallbacks   │
└─────────────────────────────────┘             └─────────────────────────────────┘
                                     │
         ┌───────────────────────────┴───────────────────────────┐
         ▼                                                       ▼
┌─────────────────────────────────┐             ┌─────────────────────────────────┐
│       Tier 3: Cross-Feature     │             │       Tier 4: Real-World        │
│            Pipelines            │             │            Workloads            │
│  - Transcoder + HK + CDS Alert  │             │  - Mock_Laboratorio.xml Panel   │
│  - Transcoder + SwiftData Vault │             │  - Mock_Specialistica.xml ECG   │
│  - In-Memory Multi-Patient Vault│             │  - Concurrent Batch Processing  │
└─────────────────────────────────┘             └─────────────────────────────────┘
```

---

## 2. Directory Structure & Test Target Layout
All test suites are contained within `Tests/RosettaHealthCoreTests/`:

```
Tests/
└── RosettaHealthCoreTests/
    ├── Tier1FeatureCoverageTests.swift       # Tier 1: Core Feature Coverage
    ├── Tier2BoundaryCornerTests.swift        # Tier 2: Boundary, Precision & Security Cases
    ├── Tier3CrossFeaturePipelineTests.swift  # Tier 3: Transcoder + HealthKit + CDS + SwiftData
    ├── Tier4RealWorldWorkloadTests.swift     # Tier 4: Real-world FSE CDA XML files
    ├── RosettaE2ETests.swift                 # Comprehensive End-to-End Test Orchestrator
    ├── ClinicalDecisionSupportTests.swift    # Core CDS Unit Tests
    ├── ValidationGateTests.swift             # Core Physiological Gate Unit Tests
    ├── RosettaTranscoderTests.swift          # Transcoder Patient Unit Tests
    ├── RosettaTranscoderTests2.swift         # Transcoder Comma/Fallback Unit Tests
    └── FSEEdgeCasesTests.swift               # Transcoder XXE/Narrative Unit Tests
```

---

## 3. Test Tier Classification Matrix

| Tier | Focus Area | Key Verification Scenarios | Test Files |
|---|---|---|---|
| **Tier 1** | Feature Coverage | CDA -> FHIR full fidelity; IPS Bundle profiles; Physiological gate acceptance/rejection; Firewall owner routing; Anonymous fuzzy matching. | `Tier1FeatureCoverageTests.swift` |
| **Tier 2** | Boundary & Corner Cases | Malformed XML error throwing; Missing header; Empty document; Billion Laughs XXE mitigation; Exact min/max physiological thresholds; Comma decimals (`"94,5"`); Inequality fallbacks (`"< 0.05"`); Composite blood pressure (`"125/80"`). | `Tier2BoundaryCornerTests.swift` |
| **Tier 3** | Cross-Feature Pipelines | Transcoder -> HealthKit -> CDS trend alerts (Cholesterol, Glucose, BP Systolic); Improving trends (no false alerts); SwiftData in-memory `ModelContainer` persistence; Multi-patient vault isolation. | `Tier3CrossFeaturePipelineTests.swift` |
| **Tier 4** | Real-World Workloads | Full ingestion of `MockData/Mock_Laboratorio.xml` (4 observations, HealthKit mapping, skipped codes); Full ingestion of `MockData/Mock_Specialistica.xml` (3 narrative sections, 0 observations); Concurrent document batch processing. | `Tier4RealWorldWorkloadTests.swift` |
| **E2E** | End-to-End Lifecycles | Complete cross-module integration lifecycle scenarios, Zero-Cloud GDPR Art. 9 certification. | `RosettaE2ETests.swift` |

---

## 4. Execution & Runner Commands

### 4.1. Swift Package Manager (CLI / CI/CD)
To build and execute all tests via SwiftPM:
```bash
# Build the test target
swift build --build-tests

# Run all tests
swift test

# Run a specific Tier test class
swift test --filter Tier1FeatureCoverageTests
swift test --filter Tier2BoundaryCornerTests
swift test --filter Tier3CrossFeaturePipelineTests
swift test --filter Tier4RealWorldWorkloadTests
swift test --filter RosettaE2ETests
```

### 4.2. Xcodebuild (iOS Simulator / macOS Runner)
To run tests using `xcodebuild` targeting the iOS 17 Simulator:
```bash
xcodebuild test \
  -scheme RosettaHealthCore \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
  -resultBundlePath './TestResults.xcresult'
```

---

## 5. Fixture & Isolation Strategy
1. **Self-Contained Fixtures**: Test cases utilize self-contained HL7 CDA XML strings conforming to Italian FSE specifications and real-world mock fixtures from `MockData/`.
2. **Deterministic Time & Identifiers**: Dates are normalized via ISO-8601 UTC formatters, and sync identifiers follow deterministic hashes (`FSE-{DocID}-{LOINC}-{Date}`).
3. **SwiftData In-Memory Isolation**: SwiftData persistence tests utilize in-memory storage configurations (`isStoredInMemoryOnly: true`, `cloudKitDatabase: .none`), ensuring zero persistent state leakage between test executions.
4. **HealthKit Mocking & Gate Simulation**: Biometric samples are validated using the in-memory `isValidPhysiologically` validation gate and evaluated using `ClinicalDecisionSupport` actors without requiring physical device HealthKit store entitlements.

---

## 6. Zero-Cloud & Privacy Boundary Invariants
- **Zero Network Transmission**: All test cases enforce 100% on-device local execution. Zero network calls (`URLSession`, `Alamofire`, `Network.framework`) are utilized.
- **GDPR Art. 9 Security**: SwiftData configuration explicitly enforces `cloudKitDatabase: .none`.
- **PII Protection**: System logging in ViewModels utilizes Apple OSLog `.private` redaction.
