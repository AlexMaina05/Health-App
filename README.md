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
- [Funzionalità Core](#-funzionalità-core)
- [Sviluppi Avanzati (iOS & watchOS)](#-sviluppi-avanzati-ios--watchos)
- [Privacy & GDPR Compliance](#-privacy--gdpr-compliance)

---

## 🎯 Il Problema & La Soluzione

**Il Problema:** 
In Italia, l'esito di un esame del sangue viene caricato sul Fascicolo Sanitario Elettronico come file PDF. Sepolto all'interno di quel PDF si trova un file **HL7 CDA R2 XML** — uno standard clinicamente accurato ma virtualmente illeggibile per la tecnologia consumer. Per tracciare un andamento (es. il Colesterolo negli ultimi 5 anni), l'utente è costretto ad aprire decine di PDF e annotarsi i numeri a mano.

**La Soluzione:** 
Un motore di traduzione *on-device*. RosettaHealth intercetta il PDF tramite l'Estensione di Condivisione di iOS, estrapola l'XML e lo transcodifica nel modernissimo standard **HL7 FHIR R4** (iniettando profili EU IPS per l'interoperabilità europea). Infine, mappa e salva i valori numerici direttamente in **Apple HealthKit**.

Il risultato? Il noioso PDF governativo diventa istantaneamente un grafico sanitario interattivo a lungo termine, protetto dal Face ID del tuo iPhone.

---

## ⚙️ Come Funziona (User Journey)

1. **Scarica**: L'utente scarica un referto (PDF) dal portale FSE.
2. **Condividi**: Senza uscire da Safari o File, l'utente preme "Condividi" e seleziona "RosettaHealth".
3. **Elabora (In Background)**: La *Custom Share Extension* accoda il file. Di notte (grazie a BGTaskScheduler), l'app si sveglia silenziosamente, scompatta l'XML e lo transcodifica.
4. **Visualizza**: I parametri appaiono su Apple Salute o direttamente al tuo polso tramite l'app **watchOS Companion**.

---

## ✨ Funzionalità Core

| Feature | Descrizione | Stack Tecnologico |
|---------|-------------|-------------------|
| **Apple Health Injection** | Scrittura in tempo reale di campioni quantitativi (HKQuantitySample). | HealthKit |
| **Family Vault** | Evita l'inquinamento dei dati Apple Health salvando i referti dei familiari in un database locale criptato. | SwiftData |
| **Graceful OCR** | Legge dati biometrici vitali anche da PDF scansionati senza XML integrato. | Vision Framework |
| **Trend Sparklines** | Visualizzazione dinamica e fluida degli andamenti storici clinici (interpolazione Catmull-Rom). | Swift Charts |
| **Clinical Decision Support** | Avvisi preventivi in base all'aumento di valori (es. LDL) in ottemperanza ai protocolli medici. | RosettaEngine |

---

## 🚀 Sviluppi Avanzati (iOS & watchOS)

L'architettura è stata potenziata con funzionalità *Desktop-Class* e profonde integrazioni con l'ecosistema Apple:

* 📤 **Custom Share Extension**: Invia file all'app direttamente da Safari. L'interfaccia inietta un UIHostingController personalizzato che mostra animazioni Lottie-style al posto del noioso tasto "Post" di sistema.
* 👆 **iPadOS Drag & Drop**: Supporto nativo per trascinare i documenti direttamente nella Dashboard da finestre affiancate su iPad e Mac.
* ⌚ **watchOS Companion**: Monitora il tuo *Family Vault* dal polso. Utilizza gli *App Groups* condivisi per renderizzare tachimetri (Gauges) sulla salute senza svegliare l'iPhone.
* 🌙 **Nightly Background Fetch**: Grazie a BGTaskScheduler, l'app elabora centinaia di PDF accodati in background mentre il telefono è in carica.
* 🖍️ **PDF Vector Annotations**: Renderizza il PDF originale evidenziando **in giallo** (come con un pennarello) le esatte coordinate vettoriali in cui l'Intelligenza Artificiale ha intercettato i parametri clinici.

---

## 🔒 Privacy & GDPR Compliance

L'ingestione di categorie particolari di dati personali (Art. 9 GDPR) è gestita con rigore militare:
- 🚫 **Zero-Cloud**: Il framework di rete (URLSession) non viene mai invocato. Elaborazione CPU 100% locale (Apple Neural Engine).
- 🛡️ **Biometric Security**: Chiusura dell'app con .blur (Privacy Screen) nel task switcher, e sblocco forzato tramite **FaceID** via LocalAuthentication.
- 🔐 **Data at Rest**: L'App Group inter-processo forza NSFileProtectionCompleteUntilFirstUserAuthentication. I file temporanei subiscono un cleanup atomico immediato (defer).

<div align="center">
  <br>
  <p>Progettato con ♥️ per l'ecosistema Apple.</p>
</div>
