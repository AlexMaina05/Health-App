## 2026-09-01T21:08:36Z
You are Worker 2 for Milestone 2: App Architecture, Concurrency & UI Reactivity.

Working Directory: e:/Code/Health-App/.agents/worker_m2/
Workspace Root: e:/Code/Health-App
Original Request: e:/Code/Health-App/ORIGINAL_REQUEST.md (MUST read first)
Project Scope: e:/Code/Health-App/PROJECT.md

Exclusive Write Ownership:
- `Sources/RosettaEdgeApp/**` (all Swift files under `Sources/RosettaEdgeApp/`, including `Vault/`, `Intents/`, etc.)
- `Sources/ShareExtension/ShareViewController.swift`
- `Sources/RosettaWidget/RosettaWidget.swift`
- `Sources/RosettaWatch/WatchDashboardView.swift`

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Detailed Tasks:
1. Normalize Availability Annotations (D10):
   - Replace all instances of `@available(iOS 26.0, *)` and `if #available(iOS 26.0, *)` with `@available(iOS 17.0, *)` / `if #available(iOS 17.0, *)` (or remove redundant annotations if base target is already iOS 17.0) across all files:
     - `Sources/RosettaEdgeApp/Vault/VaultDocument.swift`
     - `Sources/RosettaEdgeApp/Vault/VaultModelActor.swift`
     - `Sources/RosettaEdgeApp/RosettaEdgeApp.swift`
     - `Sources/RosettaEdgeApp/BackgroundTaskManager.swift`
     - `Sources/RosettaEdgeApp/MainAppView.swift`
     - `Sources/RosettaEdgeApp/Vault/ClinicalDashboardView.swift`
     - `Sources/RosettaEdgeApp/Vault/FamilyVaultView.swift`
     - `Sources/RosettaEdgeApp/SpotlightManager.swift`
     - `Sources/RosettaEdgeApp/BiometricAuthManager.swift`
     - `Sources/RosettaEdgeApp/OnboardingView.swift`
     - `Sources/ShareExtension/ShareViewController.swift`
     - `Sources/RosettaWidget/RosettaWidget.swift`
     - `Sources/RosettaEdgeApp/AppViewModel.swift`
     - `Sources/RosettaEdgeApp/LiquidGlass.swift`
2. Fix `LiquidGlass.swift` (D17):
   - Replace non-existent `glassEffect(.regular.interactive(), ...)` with standard SwiftUI `.background(.ultraThinMaterial)` / `.background(.thinMaterial)` with rounded corner styling that compiles cleanly on iOS 17.0+.
3. ViewModel State Reactivity & Parameter Consistency (D11, D12, D18, D19):
   - Add `@Observable` macro to `AppViewModel` (and `BiometricAuthManager`).
   - Harmonize parameter labels between `AppViewModel` and `ContentView.swift`:
     - Ensure methods accepting container/context use consistent types and labels (e.g. `modelContainer: ModelContainer? = nil` and/or `modelContext: ModelContext? = nil`).
     - In `AppViewModel.processPDF`, fix line 237 where `modelContext` was used while parameter was `modelContainer`. Safely obtain context from `modelContainer?.mainContext` or accept `ModelContext`.
     - In `AppViewModel.swift`, prevent premature file deletion on parse failures.
     - In `AppViewModel.swift`, write watchOS keys (`latestMetricValue`, `latestMetricName`, `latestMetricUnit`) alongside widget keys in App Group UserDefaults to match `Sources/RosettaWatch/WatchDashboardView.swift`.
4. SwiftData Concurrency & Actor Boundary Violations (D13):
   - In `ClinicalDashboardView.swift`, fix lines 31-38: do NOT pass `@Model` array `patientDocuments` into `Task.detached`. Instead, map them to Sendable structs/tuples (e.g. `(id: UUID, data: Data)`) on `@MainActor` before passing to the background task, or use `VaultModelActor`.
5. View Syntax & Scope Error Fixes (D14, D15, D16):
   - `OnboardingView.swift`: Fix extra closing brace `}` at line 189 that broke the `Form` hierarchy.
   - `FamilyVaultView.swift`: Add `@State private var activeError: String? = nil` and `@State private var showError: Bool = false` to `PDFViewerWrapper` so lines 226-227 compile.
   - `BackgroundTaskManager.swift`: Correct references to `modelContext` and `containerToUse` so background sync initializes or receives `ModelContainer` correctly.
   - `ObservationRowView.swift`: Ensure `HealthKitBridge.shared` is utilized.
6. Verify all changes across `Sources/RosettaEdgeApp/`, `ShareExtension/`, `RosettaWidget/`, and `RosettaWatch/` for compilation correctness and type safety.
7. Document all changes and rationale in `e:/Code/Health-App/.agents/worker_m2/handoff.md`.
8. Update `progress.md` and send a message to orchestrator upon completion.
