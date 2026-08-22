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

## 1. Executive Summary & Problem Statement

### 1.1 Context & Problem
Il Fascicolo Sanitario Elettronico italiano (FSE 2.0) rilascia referti in formato PDF/A-3 contenenti un payload XML strutturato (HL7 CDA R2). L'estrazione e l'integrazione di questi referti (Laboratorio, Radiologia, Visite Specialistiche) all'interno dell'ecosistema Apple Salute richiede elaborazioni complesse. 
Il vincolo normativo fondamentale è la **Privacy (GDPR Art. 9)**: la transcodifica di dati sanitari sensibili deve avvenire al 100% on-device (Zero-Cloud Architecture), senza mai delegare l'elaborazione a server esterni.

### 1.2 The RosettaHealth Solution (Hybrid Ingestion Architecture)
**RosettaHealth** risolve il problema adottando una duplice architettura nativa ("Best of Both Worlds"):
1. **Ingestione Documentale Globale (`HKCDADocumentSample`):** Estrae il payload CDA XML puro e lo inietta direttamente in HealthKit come documento clinico nativo, garantendo l'archiviazione del referto ufficiale (lettere di dimissione, referti radiologici) senza alcuna perdita di metadati.
2. **Estrazione Quantitativa Selettiva (`HKQuantitySample`):** Parallelamente, il *Rosetta Engine* transcodifica l'XML in FHIR R4 JSON. Se rileva parametri numerici mappabili (es. glicemia, colesterolo, battito tramite codici LOINC), genera e salva in Salute anche i relativi campioni quantitativi (`HKQuantitySample`). Questo permette di popolare automaticamente i grafici storici dell'app nativa.

---

## 2. Architettura IPC & App Group (Producer-Consumer)

A causa dei vincoli della Sandbox di iOS e delle policy di *Data Protection* applicate ad `HKHealthStore` a schermo bloccato, l'Estensione di Condivisione (Share Extension) non può comunicare direttamente con Apple Health. L'architettura implementa un pattern **Coda Offline Producer-Consumer**.

### 2.1 Topologia del Container Condiviso & Dual-Track IPC
Il container condiviso (`group.dev.alexmaina.rosettahealth`) gestisce due tipologie di payload in base alla natura del documento, per evitare il collasso del processo in background (Jetsam Event per superamento limiti RAM):

1. **Corsia Rapida CDA (`PendingCDA_<UUID>.xml`):** Payload XML puro estratto istantaneamente (e senza peso computazionale) dalla Share Extension e depositato per la sincronizzazione diretta.
2. **Corsia Differita OCR (`PendingPDF_<UUID>.pdf`):** Copia binaria del PDF rasterizzato, depositata in fallback. L'estrazione tramite Apple Vision (Memory Intensive) viene demandata interamente al lifecycle dell'App Principale (Consumer) o ai task notturni.

- **Consumer (AppViewModel / BGTaskScheduler)**: L'App principale scansiona il container asincronamente. Smista i file nelle relative pipeline e, terminata l'ingestione, esegue un **cleanup atomico e irreversibile** (implementato tramite blocchi `defer`) per eliminare tracce nel filesystem esposto.

---

## 3. Modelli Dati & Family Vault (SwiftData)

Per prevenire l'inquinamento del database biomedico dell'utente (Apple Health è strettamente mono-utente), l'App implementa il **Family Vault**, un EMR (Electronic Medical Record) crittografato gestito tramite `SwiftData`.

### 3.1 SwiftData Schema
Il modello dati principale è `VaultDocument`, progettato per supportare attributi BLOB pesanti in storage esterno per non impattare sulle performance delle query SQL.

```swift
@Model
public final class VaultDocument {
    @Attribute(.unique) public var id: UUID
    public var patientFiscalCode: String
    public var documentDate: Date
    public var loincMappings: [String: Double]
    
    // BLOB binario del PDF originale, archiviato out-of-line
    @Attribute(.externalStorage) public var pdfData: Data?
    
    public init(...) { ... }
}
```

### 3.2 Dual-Routing Engine
L'AppViewModel estrae il Codice Fiscale del Paziente (dal CDA) e lo incrocia con i dati biometrici del proprietario dell'iPhone. 
- **Match Positivo**: I dati vengono salvati in Apple Health e nel Vault locale.
- **Match Negativo (Familiare)**: Intervento di Anti-Inquinamento. Il salvataggio su HealthKit viene abortito (Throw `RosettaError.unmatchedFiscalCode`), e il reperto viene dirottato esclusivamente sul `ModelContext` del Family Vault.

---

## 4. Motore di Transcodifica & Normalizzazione (Rosetta Engine)

Il motore secondario implementa deterministicamente le regole del **Microsoft FHIR-Converter**. 

### 4.1 Interoperabilità Transfrontaliera (IPS)
Oltre alla mera estrazione numerica, il motore formatta i JSON finali in architetture `FHIR R4 Bundle`. Per garantire la mobilità del paziente a livello internazionale, inietta i Profile Identifier del framework **International Patient Summary (IPS)**:
- `http://hl7.org/fhir/uv/ips/StructureDefinition/Bundle-uv-ips`
Tale iniezione rende l'esportazione valida e compatibile con tutti gli EMR ospedalieri dell'Unione Europea.

### 4.2 Mappatura Semantica e LOINC Target
Apple HealthKit richiede unità di misura rigorose (`HKUnit`). Il bridge (`HealthKitBridge.swift`) mappa i codici internazionali LOINC su tipi nativi Apple tramite uno struct `MetricTarget`.

| Metrica (IT) | LOINC (Primary) | HKQuantityTypeIdentifier | Fallback Unit |
|--------------|-----------------|--------------------------|---------------|
| Glicemia | `15074-8` | `.bloodGlucose` | `mg/dL` |
| Colesterolo Totale | `2093-3` | `.dietaryCholesterol` | `mg/dL` |
| Pressione Sistolica | `8480-6` | `.bloodPressureSystolic` | `mmHg` |
| Pressione Diastolica | `8462-4` | `.bloodPressureDiastolic`| `mmHg` |

- **Parsing String-Fallback (Resilienza ai Dati Sporchi)**: Se il referto FHIR restituisce misurazioni composite incapsulate in stringhe (es. `"120/80"`), un parser Regex interno scompatta i delimitatori in vettori validi (`[120.0, 80.0]`) e genera metriche `Double` accettabili da HealthKit.

---

## 5. Fallback Ottico (Apple Vision) e Annotazioni PDF

Il panorama sanitario italiano presenta spesso referti PDF/raster generati da scansioni (privi dell'allegato XML nativo). Il sistema implementa un potente **Graceful Degradation Fallback**.

### 5.1 Heuristic Regex & Vision Extraction
Se `CGPDFDocument` non individua payload `application/xml` nell'alberatura, viene instanziato `VisionOCRExtractor`:
- Renderizza il raster e invoca `VNRecognizeTextRequest`.
- Utilizza un motore Regex euristico per individuare pattern clinici classici (es. `(?i)Colesterolo.*?(\d{3})\s*mg`).
- **Audit Trail (Valenza Legale)**: I campioni estratti via OCR vengono generati escludendo il documento CDA in HealthKit e marcati con metadati espliciti `["EXTRACTION_METHOD": "APPLE_VISION_OCR_FALLBACK"]`. L'interfaccia SwiftUI etichetta questi campioni con un badge viola (Probabilistico).

### 5.2 PDF Vector Annotations (PDFKit)
Per garantire all'utente il controllo visivo, il `pdfData` grezzo viene passato ad una `UIViewRepresentable` che fa il wrap di `PDFView`. 
L'IA calcola le `CGRect` delle *boundingBox* del testo riconosciuto. Queste coordinate vengono scalate nello spazio vettoriale di PDFKit e trasformate in `PDFAnnotation` con colore `.systemYellow` (Highlighter Effect), indicando all'utente l'esatto pixel da cui l'App ha estrapolato il dato numerico.

---

## 6. Ecosistema Avanzato (iOS, watchOS, BGTasks)

### 6.1 Headless Background Fetch (BGTaskScheduler)
Per consumare decine di PDF accodati, viene registrato un `BGProcessingTask`. 
- **Headless Context**: L'App innesca un `ModelContainer` puramente slegato dalla UI (Headless).
- Esegue il parsing XML notturno senza causare battery drain attivo all'utente.

### 6.2 watchOS Companion App (Shared App Group)
Per via delle limitazioni energetiche, Apple Watch non può eseguire pesanti estrazioni XML. 
L'App iOS Serializza le *ultime misurazioni critiche* e le codifica in `UserDefaults(suiteName: "group.dev...")`.
Il target `RosettaWatch` (compilato sotto direttive `#if os(watchOS)`) legge questi UserDefaults ed espone le metriche in tempo reale sotto forma di `Gauge` interattivi al polso, fornendo supporto decisionale senza risvegliare l'iPhone.

### 6.3 Advanced Inputs (Share Extension & iPadOS Drag & Drop)
- **Share Extension SwiftUI**: Intercetta esplicitamente file `public.composite-content` (PDF). Inietta un `UIHostingController` per fornire caricamenti con animazioni *Lottie-style* (`.symbolEffect`), superando l'interfaccia statica nativa "Post".
- **iPadOS Drag & Drop**: Attraverso il modifier `.onDrop(of: [.pdf])`, gli `NSItemProvider` passano il riferimento binario direttamente alla Dashboard se il PDF viene trascinato dall'App File in Split View.

---

## 7. Requisiti di Sicurezza & Compliance (GDPR Art. 9)

Trattando dati biometrici (Art. 9 GDPR), l'App è disegnata in ottica **Zero-Trust** e **Zero-Cloud**.

### 7.1 Networking Isolation
L'intero framework `Foundation.URLSession` è assente dalla business logic. Tutte le inferenze (Apple Neural Engine) e i task di transcodifica XML girano localmente sul SoC del dispositivo ospite.

### 7.2 Entitlements e Permessi HealthKit
Per compilare l'infrastruttura, Xcode necessita delle capability HealthKit:

```xml
<key>com.apple.developer.healthkit</key>
<true/>
```

Inoltre, il gruppo IPC necessita dell'entitlement di crittografia *Data At Rest* a schermo bloccato:

```xml
<key>com.apple.developer.default-data-protection</key>
<string>NSFileProtectionCompleteUntilFirstUserAuthentication</string>
```

### 7.3 Privacy Screen e Biometria
Se l'app transita in stato `.inactive` o entra nello Switcher delle App, il `BiometricAuthManager` inietta una vista `.blur(radius: 20)` a tutto schermo. 
Il ripristino dell'interazione (stato `.active`) è sbloccabile esclusivamente richiedendo un prompt nativo di `LocalAuthentication` (FaceID o TouchID).

---

## 8. Quality Assurance & Error Handling

L'architettura gestisce le eccezioni tramite un enumeratore conformante a `LocalizedError` (`RosettaError`), separato per domini di fallimento: `.healthKitUnavailable`, `.pdfCorrupted`, `.unmatchedFiscalCode`, ecc.

Per la certificazione di stabilità, il framework core usa `XCTest`:
- **Mocking XML**: Iniezione di payload simulati per verificare la corretta lettura dei codici LOINC critici da parte del parser SAX.
- **Resilienza Strutturale**: Valutazione della tolleranza d'errore (Graceful Fallback) se un referto medico è privo di intestazione o di *Patient ID*.
