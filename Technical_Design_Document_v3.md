# TECHNICAL DESIGN DOCUMENT (TDD) - v3.0

## Project Name: RosettaHealth (FSE CDA to Apple Health & FHIR R4)

**Document Version:** 3.0.0
**Target Environment:** iOS 17.0+ / Swift 5.10+ / SwiftUI / Xcode 15+
**Classification:** Confidential / Technical Architecture

---

## 1. Executive Summary & Problem Statement

### 1.1 Context & Problem
Il Fascicolo Sanitario Elettronico italiano (FSE 2.0) rilascia referti in formato PDF/A-3 contenenti un payload XML strutturato (HL7 CDA R2). L'estrazione e l'integrazione di questi referti (Laboratorio, Radiologia, Visite Specialistiche) all'interno dell'ecosistema Apple Salute richiede elaborazioni complesse. La transcodifica deve avvenire al 100% on-device per aderire ai principi del GDPR (Art. 9) per i dati sanitari sensibili, evitando servizi cloud.

### 1.2 The RosettaHealth Solution (Hybrid Ingestion Architecture)
**RosettaHealth** risolve il problema adottando una duplice architettura nativa ("Best of Both Worlds"):
1. **Ingestione Documentale Globale (`HKCDADocumentSample`):** Estrae il payload CDA XML puro e lo inietta direttamente in HealthKit come documento clinico nativo, garantendo l'archiviazione del referto ufficiale e la totale assenza di perdita dati (visite specialistiche, radiologia, lettere di dimissione).
2. **Estrazione Quantitativa Selettiva (`HKQuantitySample`):** Parallelamente, il *Rosetta Engine* transcodifica l'XML in FHIR R4 JSON. Se rileva parametri numerici mappabili (es. glicemia, colesterolo, battito tramite codici LOINC), genera e salva in Salute anche i relativi campioni quantitativi (`HKQuantitySample`). Questo permette di popolare automaticamente i grafici storici dei Dati Sanitari di Apple Salute.

---

## 2. Architettura IPC & App Group (Producer-Consumer)

A causa dei vincoli di Sandbox di iOS e delle policy di *Data Protection* applicate ad `HKHealthStore` a schermo bloccato, l'estensione di condivisione non comunica direttamente con HealthKit. L'architettura implementa un pattern **Coda Offline Producer-Consumer**.

### 2.1 Topologia del Container Condiviso & Dual-Track IPC
Il container condiviso (`group.dev.alexmaina.rosettahealth`) gestisce due tipologie di payload in base alla natura del documento, al fine di evitare il collasso del processo in background (Jetsam Event per superamento limiti RAM nella Share Extension):

1. **Corsia Rapida CDA (`PendingCDA_<UUID>.xml`):** Payload XML puro estratto istantaneamente (e senza peso computazionale) dalla Share Extension e depositato per la sincronizzazione diretta.
2. **Corsia Differita OCR (`PendingPDF_<UUID>.pdf`):** Copia binaria del PDF rasterizzato, depositata in fallback dalla Share Extension. L'estrazione tramite Apple Vision (Memory Intensive) viene demandata interamente al lifecycle dell'App Principale (Consumer).

- **Consumer (AppViewModel)**: L'App principale, appena torna `.active`, scansiona il container, smista i file nelle relative pipeline (Ingestione Ibrida CDA o elaborazione asincrona OCR) e infine **cancella in modo atomico e irreversibile** i file consumati.

---

## 3. Motore di Transcodifica & Normalizzazione (Rosetta Engine)

Il motore secondario implementa deterministicamente le regole del **Microsoft FHIR-Converter**. Oltre a popolare l'interfaccia SwiftUI, estrae le `HKQuantitySample`.

### 3.1 Normalizzazione Unità di Misura & Fallback di Parsing testuale (`MetricTarget`)
Apple HealthKit richiede unità di misura rigorose e tipi numerici puri (quantità doppie). Il bridge (`HealthKitBridge.swift`) mappa i codici LOINC su specifici `HKQuantityTypeIdentifier` tramite la struttura `MetricTarget`, che garantisce:
- Un'unità di default supportata (es. `mg/dL`, `%`).
- Una closure di conversione opzionale (`(Double, String) -> Double`) per regolarizzare automaticamente valori difformi.
- **Parsing String-Fallback (Resilienza ai Dati Sporchi)**: Se il referto FHIR restituisce la Pressione Arteriosa (o altre metriche) incapsulata in stringhe composite non normalizzate (es. `obs.valueString = "120/80"` anziché un campo numerico separato), un parser di fallback interno a `HealthKitBridge` processa i delimitatori e converte dinamicamente le frazioni testuali in campioni numerici `Double` validi, assicurando l'ingestione nei grafici anziché lo scarto.

### 3.2 Fallback Silenziosi (UI & FHIR Export)
1. **Codici Regionali non-LOINC**: Vengono esportati correttamente nel JSON FHIR, preservando il testo originale, ma ignorati dall'ingestione in Apple Salute.
2. **Documenti Narrativi Non Strutturati**: Se mancano dati numerici, il transcoder genera un Bundle FHIR contenente unicamente la risorsa strutturale `Composition` e `Patient`, senza generare crash.

### 3.3 Fallback Ottico e Graceful Degradation (Apple Vision OCR)
Nel panorama sanitario italiano, alcuni referti vengono ancora erogati come PDF rasterizzati (scansioni cartacee) privi di allegato XML CDA strutturato. RosettaHealth implementa un pattern di *Graceful Degradation* per gestire questi scenari estremi:
- **Estrazione Visiva**: Se il parser XML fallisce, subentra il modulo `VisionOCRExtractor` che renderizza la prima pagina in formato grafico ed esegue una `VNRecognizeTextRequest` nativa.
- **Integrità Clinica (Audit Trail)**: Per prevenire la corruzione dell'archivio clinico, i dati OCR **non** generano un documento fittizio `HKCDADocumentSample`.
- **Ingestione Metriche Grezze**: Vengono generati esclusivamente campioni quantitativi (`HKQuantitySample`) per popolare i grafici (Glicemia, Pressione, Colesterolo) ricavati tramite Regex. Questi campioni vengono "marchiati" a livello di database con i metadati di provenienza: `"EXTRACTION_METHOD": "APPLE_VISION_OCR_FALLBACK"` e `"CONFIDENCE_LEVEL": "HEURISTIC_REGEX"`, preservando l'integrità medico-legale dell'App.
- **Feedback UI**: L'interfaccia utente notifica l'evento mostrando un badge viola specifico che avverte l'utente della natura probabilistica (OCR) del dato.

### 3.4 Interoperabilità Transfrontaliera (International Patient Summary - IPS)
Il transcoder non si limita a generare un generico formato FHIR R4, ma modella le strutture dati (`FHIRModels.swift`) affinché rispettino i vincoli del profilo **IPS (International Patient Summary)**.
- **Iniezione Dinamica Metadati**: Al momento dell'istanziazione, il motore inietta i `Profile Identifier` ufficiali di HL7 all'interno del nodo `meta.profile` di ogni risorsa (es. `http://hl7.org/fhir/uv/ips/StructureDefinition/Bundle-uv-ips` per il `FHIRBundle` e `Composition-uv-ips` per la `FHIRComposition`).
- **Validità Estesa**: L'esportazione JSON risultante è formalmente riconosciuta a livello internazionale, permettendo al paziente di condividere un referto digitale strutturato leggibile istantaneamente in qualsiasi struttura ospedaliera dell'Unione Europea dotata di EMR aderenti allo standard IPS, superando i limiti del formato legacy CDA R2 italiano.

---

## 4. Gestione Sicurezza e Privacy (GDPR Art. 9)

Il sistema gestisce categorie particolari di dati personali. 

### 4.1 Zero-Cloud Isolation Guarantee
Il progetto è progettato *secure by default*: esclude formalmente l'inizializzazione di stack di networking (`URLSession` non invocato). Tutte le elaborazioni avvengono al 100% sulla CPU locale (CoreGraphics per PDF, XMLParser nativo).

### 4.2 Data Protection & Lifecycle di Cleanup
- **Crittografia GDPR By-Design**: Oltre alla direttiva dichiarativa negli entitlements (`NSFileProtectionCompleteUntilFirstUserAuthentication`), RosettaHealth implementa un paradigma *Defense-in-Depth* applicando programmaticamente la crittografia tramite le opzioni di `FileManager` (`setAttributes`) e `Data` (`write(options:)`) su ogni operazione di I/O (inclusi i file temporanei e i report JSON FHIR).
- **Regola di Cleanup Rigida**: Qualsiasi file depositato nel container condiviso viene cancellato in modo atomico e irreversibile dall'`AppViewModel` (tramite blocchi `defer`) immediatamente dopo la chiamata di elaborazione/ingestione, garantendo zero-retention sui dati sensibili esposti nel file system.

### 4.3 Prevenzione Inquinamento Dati (Multi-Profile Routing)
L'infrastruttura Apple Health è strettamente personale ("mono-utente"). Dato che i cittadini italiani spesso scaricano i referti dei propri familiari (es. figli o genitori), l'ingestione cieca dei documenti corromperebbe il database del proprietario.
- **Validazione Fiscale (CF Match)**: L'`AppViewModel` introduce un Security Checkpoint (`checkPatientMatch()`). Estraendo il Codice Fiscale del Paziente dal Bundle FHIR (tag `<patientRole>`), il sistema verifica la congruenza con l'Identificativo Proprietario salvato nelle impostazioni dell'app (`@AppStorage`). In caso di discrepanza, solleva l'eccezione `.cfMismatch`, bloccando chirurgicamente il transito dei parametri estranei verso HealthKit.

---

## 5. Requisiti di Compilazione (Entitlements e Configuration)

Per compilare il progetto su Xcode senza errori di Code Signing, configurare le seguenti capabilities:

### 5.1 App Groups Entitlement
Nei file `.entitlements` di **entrambi i target** (App Principale e Share Extension):
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.dev.alexmaina.rosettahealth</string>
</array>
```

### 5.2 HealthKit Entitlement (Solo App Target)
L'App principale deve abilitare HealthKit e richiedere le autorizzazioni per:
1. La tipologia **Documenti Clinici** (`HKDocumentTypeIdentifier.CDA`).
2. I tipi di **Quantità** mappati (Glicemia, Colesterolo, Frequenza Cardiaca, ecc.).
```xml
<key>com.apple.developer.healthkit</key>
<true/>
```

### 5.3 Data Protection Level (Entitlements)
Permette la scrittura dei file XML da parte della Share Extension anche a schermo bloccato:
```xml
<key>com.apple.developer.default-data-protection</key>
<string>NSFileProtectionCompleteUntilFirstUserAuthentication</string>
```

### 5.4 Info.plist (Privacy Strings)
L'App principale necessita delle stringhe d'uso:
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription` (Motivazione: "Integrazione dei referti clinici CDA FSE e dei parametri vitali in Apple Salute").

L'estensione necessita della regola di attivazione per intercettare esclusivamente i PDF (`NSExtensionActivationRule`).

---

## 6. Architettura User Interface (SwiftUI & HIG)

Il progetto rispetta rigorosamente le **Apple Human Interface Guidelines (HIG)** e adotta i pattern visivi introdotti a partire da iOS 16/17 (Glassmorphism e tipografia di sistema HealthKit).

### 6.1 Implementazione Glassmorphism
I risultati clinici estratti dal Rosetta Engine sono renderizzati come "Floating Cards":
- L'utilizzo di `.background(.regularMaterial)` applica l'effetto vetro smerigliato e il vibracy control.
- Le forme utilizzano il `RoundedRectangle` con stile `.continuous` (squircle) per massima fedeltà al design Apple.
- La tipografia numerica sfrutta `design: .rounded` e `.bold()` come avviene nativamente nell'app Salute.

---

## 7. Gestione degli Errori ed Eccezioni

L'infrastruttura di Error Handling si affida all'enum nativo `RosettaError` (conforme a `LocalizedError`), separato su 4 domini:
- **PDF/A-3**: Errori di estrazione (es. `.pdfCorrupted`, `.encryptedPDFNotSupported`).
- **Parsing SAX**: Riservato al Rosetta Engine (es. `.malformedXML`, `.missingClinicalDocumentHeader`).
- **HealthKit**: Fallimenti di autorizzazione o mancato supporto del tipo di documento CDA/Quantity (es. `.healthKitUnavailable`).
- **IPC**: Errori di scrittura su container o malformazione del payload XML in transito (es. `.appGroupContainerUnavailable`).

Ogni errore solleva alert nativi SwiftUI non bloccanti contenenti `failureReason` e `recoverySuggestion`.

---

## 8. Quality Assurance & Unit Testing (XCTest)

Per certificare la sicurezza e la resilienza del motore di transcodifica clinica, il modulo `RosettaHealthCore` implementa una suite strutturata tramite il framework nativo `XCTest`.
- **Validazione Parser (Mocking)**: Vengono iniettati payload XML fittizi per certificare che il `RosettaTranscoder` estragga correttamente le metriche (es. Glicemia `15074-8`) e i profili IPS.
- **Resilienza (Edge Cases)**: Sono coperti test specifici per la gestione della degradazione morbida (*Graceful Degradation*), ad esempio l'assenza del nodo Paziente o la mancanza dell'intestazione `<ClinicalDocument>`.
- **Static Mapping**: I test unitari su `HealthKitBridge` prevengono regressioni sul mapping dei codici LOINC critici (es. Pressione, Colesterolo) e certificano la sicurezza matematica del fallback testuale sulle stringhe composite.
