# RosettaHealth 🧬

**RosettaHealth** is a 100% on-device iOS application and Share Extension that bridges the gap between the Italian Electronic Health Record (FSE 2.0) and modern health ecosystems like Apple Health (HealthKit).

It seamlessly extracts HL7 CDA R2 XML payloads embedded within FSE PDF/A-3 reports, transcodes them to standard **HL7 FHIR R4**, and securely ingests the clinical observations directly into Apple HealthKit—without relying on any cloud processing, ensuring strict compliance with GDPR Art. 9 data minimization principles.

## Features ✨

- **Native PDF/A-3 Extraction**: Automatically traverses the PDF CoreGraphics catalog to extract embedded medical XMLs without heavy third-party dependencies.
- **On-Device Transcoding (Rosetta Engine)**: Implements Microsoft FHIR-Converter semantics natively in Swift, transforming CDA R2 into validated FHIR R4 JSON Bundles.
- **Apple Health Integration**: Bridges LOINC coded observations (Glucose, Cholesterol, Heart Rate, Blood Pressure) directly to `HKHealthStore`.
- **Share Extension**: Extract and sync medical data in a single tap directly from Safari or the Files app using iOS Share Sheets.
- **Offline & Private by Design**: Zero network calls. No `URLSession`. All processing happens within your device's Secure Enclave and local sandbox.
- **Modern SwiftUI Interface**: Built with the latest Apple Human Interface Guidelines, featuring Glassmorphism, continuous squircle shapes, and native typographic designs.

## Requirements 📱

- **iOS 17.0+**
- **Xcode 15.0+**
- **Swift 5.10+**
- Active Apple Developer Account (for App Groups and HealthKit entitlements)

## Getting Started 🚀

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/RosettaHealth.git
   ```
2. **Open in Xcode:**
   Drag the `Sources` package into a new iOS App project, or open the Swift Package directly.
3. **Configure Capabilities:**
   In your Xcode Target settings, ensure the following are enabled for both the Main App and the Share Extension:
   - **HealthKit** (Main App only)
   - **App Groups** (Create an identifier like `group.dev.yourname.rosettahealth` and apply it to both targets)
4. **Update Entitlements**:
   Ensure `NSFileProtectionCompleteUntilFirstUserAuthentication` is configured to allow Share Extension background operations.

## Architecture Overview 🏗

RosettaHealth employs a **Producer-Consumer IPC pattern** to navigate iOS sandbox constraints:
1. **Producer (Share Extension)** parses the PDF securely and writes a `PendingFHIR_*.json` bundle into the shared App Group container.
2. **Consumer (AppViewModel)** detects the pending bundle when the main app returns to the foreground (`.scenePhase`), processes the ingestion into HealthKit, and atomically removes the file.

For deeper architectural details, refer to the [Technical Design Document](Technical_Design_Document_v3.md).

## License 📄

This project is licensed under the **GNU General Public License v3.0** with an explicit **Apple App Store Exception** - see the [LICENSE](LICENSE) file for details. This allows the application to be legally distributed on the iOS App Store while maintaining strong copyleft protections for the source code.
