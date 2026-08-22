<div align="center">

# ⚕️ RosettaHealth 
**Il ponte on-device tra il Fascicolo Sanitario Elettronico (FSE) e Apple Health.**

[![iOS 17+](https://img.shields.io/badge/iOS-17.0%2B-black?style=for-the-badge&logo=apple)](https://apple.com)
[![watchOS 10+](https://img.shields.io/badge/watchOS-10.0%2B-black?style=for-the-badge&logo=apple)](https://apple.com)
[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-F05138?style=for-the-badge&logo=swift)](https://swift.org)
[![Zero Cloud](https://img.shields.io/badge/Architecture-Zero_Cloud-2b2b2b?style=for-the-badge)](#)
[![License](https://img.shields.io/badge/License-GPL_v3-4CAF50?style=for-the-badge)](#)

<br/>

> **RosettaHealth** non è un semplice lettore PDF; è una *pipeline invisibile e sicura* progettata per restituire ai pazienti il controllo sui propri dati medici. Sviluppata interamente in Swift (nativa), estrae i referti complessi (FSE 2.0) e li traduce in grafici interattivi all'interno di Apple Salute... il tutto senza che un singolo byte abbandoni il tuo iPhone.

<br/>
</div>

---

## 📖 Indice
- [Il Problema & La Soluzione](#-il-problema--la-soluzione)
- [Come Funziona (User Journey)](#-come-funziona-user-journey)
- [Architettura & Rosetta Engine](#-architettura--rosetta-engine)
- [Funzionalità Core](#-funzionalità-core)
- [Ecosistema Avanzato (iOS & watchOS)](#-ecosistema-avanzato-ios--watchos)
- [Privacy & GDPR Compliance](#-privacy--gdpr-compliance)
- [Metriche Cliniche Supportate](#-metriche-cliniche-supportate)

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
| **Trend Sparklines** | Visualizzazione dinamica e fluida degli andamenti storici (interpolazione Catmull-Rom) ricavati asincronamente dall'historian di sistema. | `Swift Charts` |
| **Clinical Decision Support** | Un mini-motore di inferenza medica locale (`RosettaEngine`) che analizza i referti appena consumati e genera alert preventivi in caso di anomalie prolungate. | `RosettaEngine` |

---

## 🚀 Ecosistema Avanzato (iOS & watchOS)

L'app non è relegata a un contenitore isolato, ma sfrutta appieno il tessuto dell'ecosistema Apple:

* 📤 **Custom Share Extension SwiftUI**: Estrae e accoda i referti scavalcando la noiosa "Share UI" standard di iOS, offrendo animazioni e feedback d'estrazione istantanei (Lottie-style).
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

| Nome Parametro | LOINC Mappati (Esempi) | Identificativo Apple Salute | Unità |
|---|---|---|---|
| **Glicemia / Glucosio** | `15074-8`, `2345-7` | `bloodGlucose` | mg/dL |
| **Colesterolo Totale** | `2093-3`, `35200-5` | `dietaryCholesterol` | mg/dL |
| **Colesterolo HDL** | `2085-9` | `dietaryCholesterol` | mg/dL |
| **Pressione Sistolica** | `8480-6`, `85354-9` | `bloodPressureSystolic` | mmHg |
| **Pressione Diastolica**| `8462-4`, `85354-9` | `bloodPressureDiastolic` | mmHg |
| **Frequenza Cardiaca** | `8867-4` | `heartRate` | bpm |

*(Nota: Molte altre mappature LOINC sono estensibili nativamente modificando il dizionario in `HealthKitBridge.swift`)*

<div align="center">
  <br>
  <hr>
  <p><b>Progettato con ♥️ e SwiftUI per Apple Ecosystem.</b></p>
  <p><i>Distribuito sotto licenza Open-Source (MIT).</i></p>
</div>
