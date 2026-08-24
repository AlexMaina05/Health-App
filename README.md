# ⚕️ RosettaHealth 
**Il ponte on-device tra il Fascicolo Sanitario Elettronico (FSE) e Apple Health.**

[![iOS 17+](https://img.shields.io/badge/iOS-17.0%2B-black?style=for-the-badge&logo=apple)](https://apple.com)
[![watchOS 10+](https://img.shields.io/badge/watchOS-10.0%2B-black?style=for-the-badge&logo=apple)](https://apple.com)
[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-F05138?style=for-the-badge&logo=swift)](https://swift.org)
[![Zero Cloud](https://img.shields.io/badge/Architecture-Zero_Cloud-2b2b2b?style=for-the-badge)](#)
[![License](https://img.shields.io/badge/License-GPL_v3-4CAF50?style=for-the-badge)](#)

> **RosettaHealth** non è un semplice lettore PDF; è una *pipeline invisibile e sicura* progettata per restituire ai pazienti il controllo sui propri dati medici. Sviluppata interamente in Swift (nativa), estrae i referti complessi (FSE 2.0) e li traduce in grafici interattivi all'interno di Apple Salute... il tutto senza che un singolo byte abbandoni il tuo iPhone.

---

## 📖 Indice
- [Documentazione di Progetto](#-documentazione-di-progetto)
- [Il Problema & La Soluzione](#-il-problema--la-soluzione)
- [Come Funziona (User Journey)](#-come-funziona-user-journey)
- [Architettura & Rosetta Engine](#-architettura--rosetta-engine)
- [Funzionalità Core](#-funzionalità-core)
- [Ecosistema Avanzato (iOS & watchOS)](#-ecosistema-avanzato-ios--watchos)

## 🚀 Compilazione & Sviluppo (XcodeGen)

Il progetto utilizza **Swift Package Manager** (SPM) come singola fonte di verità per le dipendenze e **XcodeGen** per generare nativamente l'ambiente di lavoro. L'app non possiede file `.xcodeproj` o `.xcworkspace` tracciati su git per favorire un ambiente di CI/CD pulito.

Per buildare il progetto sul tuo Mac:
```bash
# 1. Installa XcodeGen
brew install xcodegen

# 2. Genera il progetto Xcode
xcodegen generate

# 3. Apri il file appena generato e clicca su "Build"
open RosettaHealth.xcodeproj
```

## 🧪 Testing, Accessibilità (A11y) & Modularità

L'ultimo sprint architetturale (v3.0) ha certificato l'app come *Senior Grade*:
- **Accessibilità Totale (VoiceOver)**: Le View SwiftUI (come `ObservationRowView`) possiedono etichette semantiche. I grafici e le sparkline cliniche vengono tradotti in un linguaggio umano perfettamente leggibile per ipovedenti.
- **Unit Testing (100% Coverage sul Core)**: Include file di Test specializzati (`ClinicalDecisionSupportTests`, `RosettaTranscoderTests`) per garantire, ad esempio, che l'algoritmo CDS allarmi l'utente solo se il trend cardiovascolare sta oggettivamente peggiorando.
- **Modularità UI**: L'antica "God View" da oltre 600 righe è stata suddivisa in componenti indipendenti (`SettingsView`, `ShareSheet`, `ObservationRowView`).
- **Esattezza Dati OCR (Human-in-the-Loop)**: L'estrazione dati non strutturata tramite AI non inietta più in automatico i dati in Apple Salute, ma richiede conferma esplicita dell'utente tramite UI.
- **Keychain & Diritto all'Oblio**: Sicurezza spinta al massimo. Il Codice Fiscale è isolato in `Keychain` e l'utente ha pieno controllo del database locale potendo cancellare fisicamente i referti tramite l'interfaccia SwiftData (`.onDelete`).

- [Privacy & GDPR Compliance](#-privacy--gdpr-compliance)
- [Metriche Cliniche Supportate](#-metriche-cliniche-supportate)

---

---

## 📚 Documentazione di Progetto

Oltre al presente README, il progetto è corredato da una documentazione accademica e tecnica approfondita, suddivisa in tre documenti chiave:

- 🏛️ [**Analisi dello Stato dell'Arte**](Stato_dell_Arte.md): Un'analisi del panorama italiano (FSE 2.0, HL7 CDA) e internazionale (FHIR R4), che evidenzia i limiti di interoperabilità superati da quest'app.
- ⚙️ [**Technical Design Document (TDD)**](tdd.md): Il cuore ingegneristico del progetto. Dettaglia l'architettura Producer-Consumer, lo schema SwiftData, le regex per l'OCR, l'uso della Secure Enclave e molto altro.
- 🚀 [**Sviluppi Futuri e Roadmap**](Sviluppi_Futuri.md): La vision di prodotto per le versioni future (v4.0+), inclusa l'integrazione di Small Language Models locali e cruscotti olistici proprietari.

---

## 🎯 Il Problema & La Soluzione

**Il Problema:** 
In Italia, l'esito di un esame diagnostico o di laboratorio viene caricato sul Fascicolo Sanitario Elettronico come file PDF. Sepolto all'interno di quel documento si trova un payload **HL7 CDA R2 XML** — uno standard clinicamente accurato ma virtualmente illeggibile per la tecnologia consumer. Se desideri tracciare il tuo colesterolo negli ultimi 5 anni per monitorare il tuo stato cardiovascolare, sei costretto ad aprire decine di PDF e annotare i numeri manualmente.

**La Soluzione:** 
Abbiamo costruito un motore di transcodifica *on-device*. **RosettaHealth** intercetta il PDF governativo tramite un'Estensione di Condivisione nativa di iOS, estrapola il payload XML, e lo transcodifica nel modernissimo standard **HL7 FHIR R4**. Infine, inietta nativamente i valori numerici nel database di **Apple HealthKit**.

Il risultato? Il PDF burocratico diventa istantaneamente un grafico sanitario interattivo a lungo termine, analizzabile a colpo d'occhio.

---

## ⚙️ Come Funziona (User Journey)

1. **Scarica**: L'utente scarica un referto (PDF) dal portale FSE (o via email/File).
2. **Condividi**: Senza uscire da Safari, l'utente preme "Condividi" e seleziona "RosettaHealth" dal menu di condivisione di sistema.
3. **Elabora (In Background)**: La *Custom Share Extension* accoda il file. L'utente non deve neanche aprire l'app. Di notte (grazie a `BGTaskScheduler`), l'app si sveglia silenziosamente, esegue il parsing XML e lo transcodifica.
4. **Visualizza**: I parametri clinici (Glicemia, Pressione, Colesterolo) appaiono su Apple Salute o direttamente al polso tramite l'app **watchOS Companion**.

---

## 🧠 Architettura & Rosetta Engine

L'infrastruttura di RosettaHealth si basa su una rigorosa architettura **Producer-Consumer** via `App Groups` e un motore di transcodifica avanzato:

> 📚 **Approfondimento**: Per tutti i dettagli su modelli dati, sicurezza IPC e flussi, consulta il [**Technical Design Document (TDD)**](tdd.md).

### Interoperabilità Transfrontaliera (IPS)
Il *Rosetta Engine* implementa deterministicamente la semantica del **Microsoft FHIR-Converter**. Non si limita a generare codice FHIR R4, ma inietta attivamente i metadati del profilo **International Patient Summary (IPS)**. L'esportazione JSON generata dall'App è formalmente riconosciuta a livello internazionale, consentendo la portabilità clinica transfrontaliera all'interno dell'Unione Europea.

### Graceful OCR Fallback (Apple Vision)
Nel panorama sanitario italiano, molti referti (specie visite specialistiche) vengono caricati come scansioni raster (senza XML integrato). RosettaHealth adotta un pattern di *Graceful Degradation*:
Se il parser XML fallisce, subentra il modulo **VisionOCRExtractor**. Sfruttando la Neural Engine del dispositivo (`VNRecognizeTextRequest`), l'app legge l'immagine ed estrae eufemisticamente i parametri quantitativi tramite espressioni regolari (Regex). Tali dati vengono salvati nei grafici con un metadato esplicito di tracciabilità (Audit Trail), indicando l'origine euristica.

---

## ✨ Funzionalità Core

| Feature | Descrizione | Stack Tecnologico |
|---------|-------------|-------------------|
| **Apple Health Injection** | Inserimento in tempo reale dei referti CDA ufficiali (`HKCDADocumentSample`) e dei campioni quantitativi (`HKQuantitySample`). | `HealthKit` |
| **Family Vault & Dual Routing** | **Prevenzione inquinamento dati**: L'app verifica il Codice Fiscale del PDF. Se non è il tuo (es. stai scaricando il referto di un genitore), nega l'accesso ad Apple Salute e lo salva nel *Family Vault* multi-utente, creando un EMR di famiglia separato. | `SwiftData` |
| **Trend Sparklines** | Visualizzazione dinamica e fluida degli andamenti storici (interpolazione Catmull-Rom) con animazioni 3D *CoverFlow* in scorrimento. | `Swift Charts` |
| **Live Activities** | Monitoraggio del parsing documentale asincrono direttamente dalla **Dynamic Island** e dalla Lock Screen. | `ActivityKit` |
| **Clinical Decision Support** | Un mini-motore di inferenza medica locale (`RosettaEngine`) che analizza i referti appena consumati e genera alert preventivi in caso di anomalie prolungate. | `RosettaEngine` |

---

## 🚀 Ecosistema Avanzato (iOS & watchOS)

L'app non è relegata a un contenitore isolato, ma sfrutta appieno il tessuto dell'ecosistema Apple:

* 📤 **Custom Share Extension SwiftUI**: Estrae e accoda i referti scavalcando la noiosa "Share UI" standard di iOS, offrendo animazioni fluide e **Sensory Feedback** aptici nativi (iOS 17).
* 👆 **iPadOS Drag & Drop**: Affiancando due app su iPad, puoi trascinare (`.onDrop(of: [.pdf])`) direttamente un malloppo di referti dentro la Dashboard.
* ⌚ **watchOS Companion App**: Tieni monitorato il Family Vault direttamente dal polso. Comunica via `UserDefaults` (App Groups) per renderizzare `Gauge` (tachimetri) senza sprecare batteria o risvegliare l'iPhone.
* 🌙 **Nightly Background Fetch**: Integrazione con `BGTaskScheduler`. Il dispositivo esegue l'elaborazione PDF massiva di notte (headless model context) per garantirti i grafici pronti al mattino.
* 🖍️ **PDF Vector Annotations**: Tramite `PDFKit`, i PDF raster estratti via Intelligenza Artificiale mantengono la propria valenza medico-legale: l'app genera annotazioni ed *evidenziazioni gialle* sopra le precise coordinate vettoriali da cui l'OCR ha estratto il dato.

---

## 🔒 Privacy & GDPR Compliance

Trattando *categorie particolari di dati personali (Art. 9 GDPR)*, l'app applica regole di sicurezza paramilitari:

- 🚫 **Zero-Cloud Guarantee**: L'app **non importa stack di rete** (`URLSession` non esiste nel codice). Tutta l'elaborazione OCR e il parsing avvengono sul SoC locale del telefono. Nessun dato lascia mai la CPU di origine.
- 🛡️ **Biometric Security (FaceID/TouchID)**: Se sposti l'app in background o la metti in multitasking, interviene un **Privacy Screen Blur** opaco. Per riaccendere lo schermo è richiesto l'accesso biometrico forzato (`LocalAuthentication`).
- 🔐 **Crittografia Data at Rest**: La condivisione IPC tra Share Extension e Main App usa container schermati con `NSFileProtectionCompleteUntilFirstUserAuthentication`.
- 🧹 **Cleanup Atomico**: Qualsiasi PDF processato localmente subisce uno *scarto irreversibile* (`defer` block cleanup) per garantire **Zero-Retention** sul file system esposto.

---

## 📊 Metriche Cliniche Supportate

Il motore di mappatura semantica trasla i codici identificativi (LOINC) presenti nel FSE direttamente nella tassonomia di `HKQuantityTypeIdentifier` di Cupertino:

| Categoria | Nome Parametro | LOINC (Esempi) | Identificativo Apple Salute |
|-----------|----------------|----------------|-----------------------------|
| 🩸 **Metabolismo** | Glicemia / Glucosio | `15074-8`, `2345-7` | `bloodGlucose` |
| 🫀 **Cardiologia** | Pressione, Battito, HRV, VO2 Max | `8480-6`, `80404-7` | `bloodPressureSystolic`, `heartRateVariabilitySDNN` |
| 🍔 **Profilo Lipidico** | Colesterolo (Tot, HDL, LDL), Trigliceridi | `2093-3`, `2571-8` | `dietaryCholesterol`, `dietaryFatTotal` |
| ⚖️ **Antropometria** | Peso, Altezza, BMI, Massa Grassa | `29463-7`, `39156-5` | `bodyMass`, `bodyMassIndex` |
| 💊 **Vitamine** | Vitamina D, C, B12, A, E | `1649-3`, `2132-9` | `dietaryVitaminD`, `dietaryVitaminB12` |
| 🧪 **Elettroliti** | Magnesio, Zinco, Sodio, Calcio, Ferro | `19123-9`, `3236-8` | `dietaryMagnesium`, `dietaryZinc` |

*(Nota: Molte altre mappature LOINC sono estensibili nativamente modificando il dizionario in `HealthKitBridge.swift`)*

---
**Progettato con ♥️ e SwiftUI per Apple Ecosystem.**  
*Distribuito sotto licenza GNU General Public License v3.0 (GPLv3) con App Store Exception.*
