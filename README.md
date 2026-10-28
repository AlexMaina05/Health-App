# ⚕️ RosettaHealth 
**Il ponte mobile edge on-device tra il Fascicolo Sanitario Elettronico (FSE) e Apple Health.**

[![Author](https://img.shields.io/badge/Author-Alessandro_Mainardi-00e5ff?style=for-the-badge)](https://alexmaina.dev/)
[![Affiliation](https://img.shields.io/badge/UniBo-DISI-CC0000?style=for-the-badge)](https://disi.unibo.it/)
[![ORCID](https://img.shields.io/badge/ORCID-0009--0003--7003--7247-A6CE39?style=for-the-badge&logo=orcid&logoColor=white)](https://orcid.org/0009-0003-7003-7247)
[![Wikidata](https://img.shields.io/badge/Wikidata-Q141886579-3399CC?style=for-the-badge&logo=wikidata&logoColor=white)](https://www.wikidata.org/wiki/Q141886579)
[![DOI](https://img.shields.io/badge/DOI-10.5281%2Fzenodo.23692700-007EC6?style=for-the-badge)](https://doi.org/10.5281/zenodo.23692700)
[![iOS 17+](https://img.shields.io/badge/iOS-17.0%2B-black?style=for-the-badge&logo=apple)](https://apple.com)
[![watchOS 10+](https://img.shields.io/badge/watchOS-10.0%2B-black?style=for-the-badge&logo=apple)](https://apple.com)
[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-F05138?style=for-the-badge&logo=swift)](https://swift.org)
[![Zero Cloud](https://img.shields.io/badge/Architecture-Zero_Cloud-2b2b2b?style=for-the-badge)](#)
[![License](https://img.shields.io/badge/License-CC_BY_4.0-4CAF50?style=for-the-badge)](https://creativecommons.org/licenses/by/4.0/)

> **RosettaHealth** non è un semplice lettore PDF; è una *pipeline invisibile e sicura* progettata per restituire ai pazienti il controllo sui propri dati medici. Sviluppata interamente in Swift (nativa), estrae i referti complessi (FSE 2.0) e li traduce in grafici interattivi all'interno di Apple Salute... il tutto senza che un singolo byte abbandoni il tuo iPhone.

---

## 📖 Indice
- [Documentazione di Progetto & Monografia](#-documentazione-di-progetto--monografia)
- [Guida Utente](#-guida-utente)
- [Il Problema & La Soluzione](#-il-problema--la-soluzione)
- [Come Funziona (User Journey)](#-come-funziona-user-journey)
- [Architettura & Rosetta Engine](#-architettura--rosetta-engine)
- [Funzionalità Core](#-funzionalità-core)
- [Ecosistema Avanzato (iOS & watchOS)](#-ecosistema-avanzato-ios--watchos)
- [Privacy & GDPR Compliance](#-privacy--gdpr-compliance)
- [Metriche Cliniche Supportate](#-metriche-cliniche-supportate)
- [Autore & Attribuzione Accademica](#-autore--attribuzione-accademica)

---

## 📚 Documentazione di Progetto & Monografia

Oltre al presente README e alla [Homepage Interattiva](https://alexmaina.dev/Health-App/), il progetto include una corposa monografia accademica e documentazione tecnica strutturata:

- 📄 [**Monografia Tecnica Ufficiale (PDF, 40 Pagine)**](https://alexmaina.dev/Health-App/rosettahealth-monografia-tecnica.pdf): Trattato formale in LaTeX redatto da Alessandro Mainardi (UniBo DISI). Include specifiche matematiche, modello di minaccia STRIDE, validazione dell'Identity Firewall (D.M. 23/12/1976 + Jaro-Winkler), benchmark sperimentali su iPhone 15 Pro / iPhone 13 e appendici ontologiche LOINC complete. DOI: [10.5281/zenodo.23692700](https://doi.org/10.5281/zenodo.23692700).
- 🏛️ [**Analisi dello Stato dell'Arte**](https://alexmaina.dev/Health-App/tesi/#/Stato_dell_Arte): Analisi del panorama italiano (FSE 2.0, HL7 CDA R2, standard regionali Emilia-Romagna/Lombardia/Veneto) e internazionale (FHIR R4).
- ⚙️ [**Technical Design Document (TDD)**](https://alexmaina.dev/Health-App/tesi/#/tdd): Il cuore ingegneristico (modello Producer-Consumer, schema SwiftData `@ModelActor`, crittografia Secure Enclave, Swift Concurrency).
- 🚀 [**Sviluppi Futuri e Roadmap**](https://alexmaina.dev/Health-App/tesi/#/Sviluppi_Futuri): Vision evolutiva (v4.0+), inclusi Small Language Models (SLM) on-device con CoreML ed European Health Data Space (EHDS).
- 🔒 [**Valutazione d'Impatto DPIA**](https://alexmaina.dev/Health-App/tesi/#/DPIA) & [**Informativa Privacy**](https://alexmaina.dev/Health-App/tesi/#/PRIVACY_POLICY): Conformità rigorosa al GDPR Art. 9 ed esenzione Art. 2(2)(c).
- 📖 [**Manuale Utente Operativo**](https://alexmaina.dev/Health-App/tesi/#/GUIDA_UTENTE): Istruzioni passo-passo per l'acquisizione, la condivisione e la revisione Human-in-the-Loop.

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
2. **Condividi**: Senza uscire da Safari o Mail, l'utente preme "Condividi" e seleziona "RosettaHealth" dal menu di condivisione di sistema.
3. **Elabora (In Background)**: La *Custom Share Extension* accoda il file. L'utente non deve neanche aprire l'app. In background (grazie a `BGTaskScheduler`), l'app esegue il parsing XML in streaming e lo transcodifica.
4. **Visualizza**: I parametri clinici (Glicemia, Pressione, Colesterolo) appaiono su Apple Salute o direttamente al polso tramite l'app **watchOS Companion**.

---

## 💎 Modello di Business (Freemium Etico)

L'applicazione abbraccia un modello di monetizzazione etico e sostenibile (Zero-Ads, Zero-Data-Selling):
- **Core Gratuito**: Importazione illimitata di referti personali (Glicemia, Pressione, ecc.) sincronizzati direttamente in Apple Salute.
- **RosettaHealth PRO**: Sblocca il *Family Vault*, permettendo l'archiviazione di referti appartenenti a terzi (figli minori, genitori anziani) sul dispositivo con isolamento crittografico Face ID.

---

## 🚀 Compilazione & Sviluppo (XcodeGen)

Il progetto utilizza **Swift Package Manager** (SPM) come singola fonte di verità per le dipendenze e **XcodeGen** per generare nativamente l'ambiente di lavoro. L'app non possiede file `.xcodeproj` o `.xcworkspace` tracciati su git per favorire un ambiente di CI/CD pulito e deterministico.

Per compilare il progetto sul tuo Mac:
```bash
# 1. Installa XcodeGen
brew install xcodegen

# 2. Genera il progetto Xcode
xcodegen generate

# 3. Apri il file appena generato e clicca su "Build"
open RosettaHealth.xcodeproj
```

---

## 🧪 Testing, Accessibilità (A11y) & Modularità

L'architettura rispetta gli standard industriali più rigorosi:
- **Accessibilità Totale (VoiceOver)**: Le View SwiftUI (`ObservationRowView`) possiedono etichette semantiche. I grafici e le sparkline cliniche vengono tradotti in un linguaggio umano perfettamente leggibile per ipovedenti.
- **Unit Testing (100% Coverage sul Core)**: Include test specialistici (`ClinicalDecisionSupportTests`, `RosettaTranscoderTests`, `ValidationGateTests`) per garantire che l'algoritmo allarmi l'utente solo se il trend cardiovascolare o metabolico sta oggettivamente peggiorando.
- **Modularità UI**: Scomposizione in componenti atomici indipendenti (`SettingsView`, `ShareSheet`, `ObservationRowView`, `FamilyVaultView`).
- **Esattezza Dati OCR (Human-in-the-Loop)**: L'estrazione dati non strutturata tramite AI/Vision non inietta mai automaticamente i dati in Apple Salute, ma richiede conferma esplicita dell'utente tramite UI con crop dell'immagine originale.
- **Keychain & Diritto all'Oblio**: Il Codice Fiscale è isolato in `Keychain` e l'utente ha pieno controllo del database locale potendo cancellare fisicamente i referti tramite SwiftData (`.onDelete`) con propagazione automatica a HealthKit (`deleteObject`).

---

## 🛡️ Privacy & GDPR Compliance

Trattando *categorie particolari di dati personali (Art. 9 GDPR)*, l'app applica regole di sicurezza paramilitari:
- 🚫 **Zero-Cloud Guarantee**: L'app **non importa stack di rete** (`URLSession` non esiste nel codice core). Tutta l'elaborazione OCR e il parsing avvengono sul SoC locale del telefono. Nessun dato lascia mai la CPU di origine.
- 🛡️ **Biometric Security (FaceID/TouchID)**: Se sposti l'app in background, interviene un **Privacy Screen Blur** opaco. Per sbloccare lo schermo è richiesta l'autenticazione biometrica hardware (`LocalAuthentication`).
- 🔐 **Crittografia Data at Rest**: La condivisione IPC tra Share Extension e Main App usa container schermati con `NSFileProtectionComplete`.
- 🧹 **Cleanup Atomico**: Qualsiasi PDF processato localmente subisce uno *scarto irreversibile* (`defer` block cleanup) per garantire **Zero-Retention** sul file system esposto.

---

## 📊 Metriche Cliniche Supportate

Il motore di mappatura semantica trasla i codici identificativi (LOINC) presenti nel FSE direttamente nella tassonomia di `HKQuantityTypeIdentifier` di Apple:

| Categoria | Nome Parametro | LOINC (Esempi) | Identificativo Apple Salute |
|-----------|----------------|----------------|-----------------------------|
| 🩸 **Metabolismo** | Glicemia / Glucosio | `15074-8`, `2345-7` | `bloodGlucose` |
| 🫀 **Cardiologia** | Pressione, Battito, HRV, VO2 Max | `8480-6`, `80404-7` | `bloodPressureSystolic`, `heartRateVariabilitySDNN` |
| 🍔 **Profilo Lipidico** | Colesterolo (Tot, HDL, LDL), Trigliceridi | `2093-3`, `2571-8` | `dietaryCholesterol`, `dietaryFatTotal` |
| ⚖️ **Antropometria** | Peso, Altezza, BMI, Massa Grassa | `29463-7`, `39156-5` | `bodyMass`, `bodyMassIndex` |
| 💊 **Vitamine** | Vitamina D, C | `32309-7`, `32220-6` | `dietaryVitaminD`, `dietaryVitaminC` |
| 🧪 **Elettroliti** | Sodio, Potassio nel Siero | `2951-2`, `2823-3` | `dietarySodium`, `dietaryPotassium` |

---

## 👤 Autore & Attribuzione Accademica

Il progetto **RosettaHealth** è ideato, formalizzato e sviluppato da:

- **Autore:** [Alessandro Mainardi](https://alexmaina.dev/)
- **Affiliazione:** Alma Mater Studiorum — Università di Bologna, Dipartimento di Informatica — Scienza e Ingegneria (DISI)
- **ORCID:** [0009-0003-7003-7247](https://orcid.org/0009-0003-7003-7247)
- **Wikidata:** [Q141886579](https://www.wikidata.org/wiki/Q141886579)
- **Concept DOI:** [10.5281/zenodo.23692700](https://doi.org/10.5281/zenodo.23692700) (Zenodo / OpenAIRE)
- **Contatto:** `maina@alexmaina.dev` · Sito Ufficiale: [alexmaina.dev](https://alexmaina.dev/)
- **Licenza:** [Creative Commons Attribuzione 4.0 Internazionale (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/)
