---
layout: default
title: Technical Design Document
permalink: /tdd/
---

# TECHNICAL DESIGN DOCUMENT (TDD) - v3.0

## Project Name: RosettaHealth (FSE CDA to Apple Health & FHIR R4)

**Document Version:** 3.0.0  
**Target Environment:** iOS 17.0+ / watchOS 10.0+ / Swift 5.10+ / SwiftUI / Xcode 15+  
**Classification:** Confidential / Technical Architecture  

---

## 📖 Table of Contents
1. [Executive Summary & Problem Statement](#1-executive-summary--problem-statement)
2. [Architettura IPC & Memory Management](#2-architettura-ipc--memory-management)
3. [Modelli Dati & Family Vault (SwiftData)](#3-modelli-dati--family-vault-swiftdata)
4. [Motore di Transcodifica (SAX Parsing & FHIR)](#4-motore-di-transcodifica-sax-parsing--fhir)
5. [Graceful Degradation (Apple Vision OCR)](#5-graceful-degradation-apple-vision-ocr)
6. [Ecosistema Avanzato (iOS, watchOS, BGTasks)](#6-ecosistema-avanzato-ios-watchos-bgtasks)
7. [Sicurezza, Crittografia & Compliance (GDPR Art. 9)](#7-sicurezza-crittografia--compliance-gdpr-art-9)
8. [UI/UX & Accessibility (A11y)](#8-uiux--accessibility-a11y)
9. [Quality Assurance & CI/CD](#9-quality-assurance--cicd)

---

## 1. Executive Summary & Problem Statement

### 1.1 Context & Problem
Il Fascicolo Sanitario Elettronico italiano (FSE 2.0) rilascia referti in formato PDF/A-3 contenenti un payload XML strutturato (HL7 CDA R2). L'estrazione e l'integrazione di questi referti (Laboratorio, Radiologia, Visite Specialistiche) all'interno dell'ecosistema Apple Salute richiede elaborazioni complesse. 
Il vincolo normativo fondamentale è la **Privacy (GDPR Art. 9)**: la transcodifica di dati sanitari sensibili deve avvenire al 100% on-device (Zero-Cloud Architecture), senza mai delegare l'elaborazione a server esterni.

### 1.2 The RosettaHealth Solution (Hybrid Ingestion Architecture)
**RosettaHealth** risolve il problema adottando una duplice architettura nativa ("Best of Both Worlds"):
1. **Ingestione Documentale Globale (`HKCDADocumentSample`):** Estrae il payload CDA XML puro e lo inietta direttamente in HealthKit come documento clinico nativo, garantendo l'archiviazione del referto ufficiale (lettere di dimissione, referti radiologici) senza alcuna perdita di metadati.
2. **Estrazione Quantitativa Selettiva (`HKQuantitySample`):** Parallelamente, il *Rosetta Engine* transcodifica l'XML in FHIR R4 JSON. Se rileva parametri numerici mappabili (es. glicemia, colesterolo, battito tramite codici LOINC), genera e salva in Salute anche i relativi campioni quantitativi (`HKQuantitySample`). Questo permette di popolare automaticamente i grafici storici dell'app nativa.

---

## 2. Architettura IPC & Memory Management

A causa dei vincoli della Sandbox di iOS e delle policy di *Data Protection* applicate ad `HKHealthStore` a schermo bloccato, l'Estensione di Condivisione (Share Extension) non può comunicare direttamente con Apple Health. L'architettura implementa un pattern **Coda Offline Producer-Consumer**.

### 2.1 Gestione dei Limiti Jetsam (120MB)
Le Share Extension su iOS sono soggette a stringenti limiti di memoria (circa 120MB). L'apertura e il rendering nativo di PDF multipagina pesanti causerebbe un immediato *Jetsam Event* (terminazione forzata da parte del SO).
Per aggirare il problema, la Share Extension **non esegue il parsing**. Si limita ad agire da *Producer*:
1. Valida il MIME type (`application/pdf`).
2. Scrive il binario grezzo nel container IPC.
3. Chiude il processo delegando il calcolo pesante all'App principale.

### 2.2 Topologia del Container Condiviso & Dual-Track IPC
Il container condiviso (`group.dev.alexmaina.rosettahealth`) gestisce due tipologie di payload:

1. **Corsia Rapida CDA (`PendingCDA_<UUID>.xml`):** Payload XML puro estratto istantaneamente (se embedded nel PDF/A-3).
2. **Corsia Differita OCR (`PendingPDF_<UUID>.pdf`):** Copia binaria del PDF rasterizzato, depositata in fallback se l'XML è assente.

- **Consumer (AppViewModel / BGTaskScheduler)**: L'App principale scansiona il container asincronamente. Terminata l'ingestione, esegue un **cleanup atomico e irreversibile** (implementato tramite blocchi `defer`) per eliminare tracce nel filesystem esposto.

---

## 3. Modelli Dati & Family Vault (SwiftData)

Apple Health è strettamente mono-utente. L'ingestione accidentale del referto di un familiare corromperebbe i trend biomedici del proprietario del dispositivo. L'App implementa il **Family Vault**, un EMR (Electronic Medical Record) crittografato gestito tramite `SwiftData`.

### 3.1 SwiftData Schema & Out-of-Line Storage
Il modello dati principale è `VaultDocument`, progettato per supportare attributi BLOB pesanti in storage esterno per non impattare sulle performance delle query (SQLite).

```swift
@Model
public final class VaultDocument {
    @Attribute(.unique) public var id: UUID
    public var patientFiscalCode: String
    public var documentDate: Date
    public var loincMappings: [String: Double]
    
    // BLOB binario del PDF originale archiviato out-of-line (filesystem)
    @Attribute(.externalStorage) public var pdfData: Data?
    
    public init(...) { ... }
}
```

### 3.2 Dual-Routing Engine (Prevenzione Inquinamento Dati)
L'AppViewModel implementa un Security Checkpoint:
1. Estrae il Codice Fiscale del Paziente (dal CDA o tramite regex OCR).
2. Lo incrocia con i dati biometrici del proprietario dell'iPhone recuperati dal certificato primario HealthKit.
- **Match Positivo**: I dati vengono salvati in Apple Health e nel Vault locale.
- **Match Negativo (Familiare)**: Intervento di Anti-Inquinamento. Il salvataggio su HealthKit viene abortito (Throw `RosettaError.unmatchedFiscalCode`), e il reperto viene dirottato esclusivamente sul `ModelContext` del Family Vault.

---

## 4. Motore di Transcodifica (SAX Parsing & FHIR)

L'elaborazione dei documenti clinici non utilizza parser DOM (Document Object Model) che allocherebbero l'intero albero XML in RAM.

### 4.1 SAX Parsing (Streaming XML)
Il motore si affida al delegato nativo `XMLParserDelegate` (Simple API for XML). Questo approccio garantisce una complessità spaziale O(1): il referto FSE (che può superare i 10MB per cartelle cliniche complesse) viene letto in streaming nodo per nodo, scartando i dati non clinici in tempo reale e annullando il rischio di *Memory Warning* su dispositivi legacy (es. iPhone Xs).

### 4.2 Interoperabilità Transfrontaliera (IPS)
Oltre all'estrazione numerica, il motore formatta i JSON finali in architetture `FHIR R4 Bundle`. Per garantire la mobilità del paziente a livello internazionale, inietta i Profile Identifier del framework **International Patient Summary (IPS)**:
- `http://hl7.org/fhir/uv/ips/StructureDefinition/Bundle-uv-ips`
Tale iniezione rende l'esportazione valida e compatibile con tutti gli EMR ospedalieri dell'Unione Europea.

### 4.3 Mappatura Semantica e LOINC Target
Il bridge (`HealthKitBridge.swift`) mappa i codici internazionali LOINC su tipi nativi Apple tramite uno struct `MetricTarget`.

| Metrica (Categoria) | LOINC (Primary) | HKQuantityTypeIdentifier | Fallback Unit |
|---------------------|-----------------|--------------------------|---------------|
| **Metabolismo** (Glicemia) | `15074-8` | `.bloodGlucose` | `mg/dL` |
| **Profilo Lipidico** (Colesterolo Totale) | `2093-3` | `.dietaryCholesterol` | `mg/dL` |
| **Profilo Lipidico** (Trigliceridi) | `2571-8` | `.dietaryFatTotal` | `g` |
| **Cardiologia** (Pressione Sistolica) | `8480-6` | `.bloodPressureSystolic` | `mmHg` |
| **Cardiologia** (HRV - SDNN) | `80404-7` | `.heartRateVariabilitySDNN` | `ms` |
| **Antropometria** (BMI) | `39156-5` | `.bodyMassIndex` | `count` |
| **Antropometria** (Massa Grassa) | `41982-0` | `.bodyFatPercentage` | `%` |
| **Vitamine** (Vitamina D) | `1649-3` | `.dietaryVitaminD` | `mcg` |
| **Minerali** (Magnesio) | `19123-9` | `.dietaryMagnesium` | `mg` |

*(Nota: La tabella sovrastante è un estratto. L'architettura supporta oltre 30 mappature LOINC native, includendo tossicologia, elettroliti e fitness avanzato come il VO2 Max).*

**Parsing String-Fallback:** Se FHIR restituisce misurazioni composite incapsulate in stringhe (es. `"120/80"`), un parser Regex le scompatta in vettori validi (`[120.0, 80.0]`) e genera due metriche separate.

---

## 5. Graceful Degradation (Apple Vision OCR)

Molti referti (es. visite specialistiche private) vengono forniti come PDF raster (scansioni senza XML). Il sistema adotta un pattern di *Graceful Degradation Fallback*.

### 5.1 Heuristic Regex & Vision Extraction
Se `CGPDFDocument` non individua payload `application/xml`:
1. Viene instanziato `VisionOCRExtractor` che renderizza il raster e invoca `VNRecognizeTextRequest` sfruttando la **Apple Neural Engine**.
2. Utilizza un motore Regex euristico per individuare pattern clinici (es. `(?i)Colesterolo.*?(\d{3})\s*mg`).

### 5.2 Audit Trail (Valenza Medico-Legale)
Per preservare la rigorosità del dato medico, i campioni estratti via OCR vengono generati escludendo il documento CDA in HealthKit e marcati con metadati espliciti `["EXTRACTION_METHOD": "APPLE_VISION_OCR_FALLBACK"]`. L'interfaccia SwiftUI etichetta visivamente questi campioni con un badge viola (Dato Probabilistico).

### 5.3 PDF Vector Annotations (PDFKit)
Per garantire all'utente il controllo visivo, il sistema esegue una complessa trasformazione di coordinate:
- L'IA calcola le `CGRect` normalizzate del testo riconosciuto.
- Tali coordinate vengono tradotte dallo spazio di Vision (origine in basso a sinistra) allo spazio vettoriale della pagina PDFKit (origine in alto a sinistra, considerando le `mediaBox` e l'angolo di rotazione del documento).
- Le bounding box vengono trasformate in `PDFAnnotation` con colore `.systemYellow` e `blendMode = .multiply` (Highlighter Effect), indicando l'esatto pixel da cui l'App ha estrapolato il numero.

---

## 6. Ecosistema Avanzato (iOS, watchOS, BGTasks)

### 6.1 Live Activities & Dynamic Island (ActivityKit)
Sfruttando il target `RosettaWidget`, l'App innesca una `Live Activity` quando l'utente processa uno o più PDF e porta l'applicazione in background. 
La `Dynamic Island` si espande mostrando una `ProgressView` in tempo reale sulle operazioni di *Parsing XML* o *OCR Fallback*, migliorando enormemente la visibilità dei task asincroni del *Rosetta Engine*.

### 6.2 Headless Background Fetch (BGTaskScheduler)
Per consumare decine di PDF accodati, viene registrato un `BGProcessingTask` (richiede l'entitlement `UIBackgroundModes` -> `processing`). 
- **Headless Context**: L'App innesca un `ModelContainer` puramente slegato dalla UI.
- L'esecuzione massiva avviene esclusivamente quando l'iPhone è inattivo e in carica, azzerando il *battery drain* attivo percepito dall'utente.

### 6.3 watchOS Companion App (Shared App Group)
Per le limitazioni energetiche (e l'impossibilità di leggere HealthKit nativo in background persistente), il target iOS serializza le *ultime misurazioni critiche* in un `UserDefaults(suiteName: "group.dev...")` transitorio.
Il target `RosettaWatch` (compilato sotto direttive `#if os(watchOS)`) consuma i dati e aggiorna le sue Complicazioni e `Gauge` interattivi, fornendo alert di Medicina Preventiva direttamente al polso senza risvegliare il SoC dell'iPhone.

---

## 7. Sicurezza, Crittografia & Compliance (GDPR Art. 9)

### 7.1 Isolamento Rete (Zero-Cloud)
Il framework `Foundation.URLSession` è assente dalla business logic. Tutte le inferenze LLM/Vision e le computazioni FHIR avvengono localmente. Nessun dato varca il perimetro del dispositivo.

### 7.2 Crittografia AES-256 e Secure Enclave
Il gruppo IPC necessita dell'entitlement di crittografia *Data At Rest* a schermo bloccato:

```xml
<key>com.apple.developer.default-data-protection</key>
<string>NSFileProtectionCompleteUntilFirstUserAuthentication</string>
```

Questa stringa garantisce che le chiavi crittografiche (AES-256) utilizzate per proteggere il filesystem dell'App Group vengano distrutte dalla **Secure Enclave** nel momento in cui il telefono viene riavviato e non sbloccato. 

### 7.3 Privacy Screen e Biometria
Tramite l'hook sul ciclo di vita `scenePhase`:
Se l'app transita in stato `.inactive` (Task Switcher aperto), il `BiometricAuthManager` inietta una vista `.blur(radius: 20)` in overlay protettivo. Il ripristino dell'interazione (`.active`) è subordinato a un prompt `LocalAuthentication` (FaceID o TouchID).

---

## 8. UI/UX & Accessibility (A11y)

Il livello di presentazione è costruito in **SwiftUI** rispettando le Apple Human Interface Guidelines (HIG).

### 8.1 Glassmorphism, 3D Scroll Transitions & Sensory Feedback
- **Scroll Transitions**: I referti all'interno del `FamilyVaultView` e `ContentView` sfruttano il modifier nativo iOS 17 `.scrollTransition`. Al variare dell'offset della ScrollView, il framework interpola dinamicamente `scaleEffect` e `rotation3DEffect`, restituendo un feedback visivo tridimensionale simile allo storico *CoverFlow* di Apple.
- **Sensory Feedback**: Eliminato il vecchio `UIKit` in favore dell'API puramente dichiarativa `.sensoryFeedback(trigger:)`, innescando feedback aptici coordinati con gli stati della `Live Activity`.
- L'interfaccia utilizza `RoundedRectangle` con stile `.continuous` (squircle) e materiali opachi (`.ultraThinMaterial`) per effetti di traslucenza (Glassmorphism).
- Le storicità cliniche sono renderizzate tramite `Swift Charts`. Un task asincrono recupera da HealthKit gli ultimi campioni LOINC e li disegna con un'interpolazione `.catmullRom` per creare sparklines organiche. Il *Color Coding* degrada in `.red.gradient` se l'ultimo valore estratto eccede il range di sicurezza clinica.

### 8.2 Accessibilità Inclusiva (VoiceOver & Dynamic Type)
Il codice UI è ottimizzato per l'inclusività:
- Le `ObservationRowView` implementano i modificatori `.accessibilityElement(children: .combine)` e `.accessibilityLabel()`, convertendo dati complessi (es. "LDL 120 mg/dL, in aumento") in una singola frase fluida per VoiceOver.
- Tutte le viste testuali scalano correttamente secondo le impostazioni di sistema **Dynamic Type**, garantendo leggibilità per utenti ipovedenti senza rompere il layout a griglia.

---

## 9. Quality Assurance & CI/CD

Per la certificazione di stabilità biomedica, il framework core usa una suite di Test (`XCTest`):
- **Mocking XML & SAX Testing**: Iniezione di payload simulati per verificare la corretta astrazione dei codici LOINC critici da parte dell'`XMLParserDelegate`.
- **Unit Testing HealthKitBridge**: Verifica che i divisori di frazioni composite (es. "130/80") restituiscano i tuple-type corretti o falliscano in modo controllato.
- **Edge Cases & Resilience**: Valutazione della tolleranza d'errore se un referto medico è malformato (es. privo di intestazione o di *Patient ID*), garantendo che la pipeline fallisca silenziosamente (*Fail Gracefully*) senza generare eccezioni non gestite (crash a runtime).
