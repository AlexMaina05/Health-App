# Sviluppi Futuri e Miglioramenti dell'Architettura

Sebbene l'attuale architettura di RosettaHealth (v3.0) abbia raggiunto l'obiettivo di colmare il divario tra il FSE 2.0 (CDA R2) e Apple Health (HealthKit) in maniera pienamente conforme al GDPR, esistono diverse direttrici di evoluzione tecnologica. 

Questi miglioramenti, ideali per una roadmap di produzione (o come capitolo conclusivo di una tesi di laurea), mirano ad espandere le capacità analitiche dell'app, migliorare la *User Experience* e abbracciare i nuovi paradigmi di Intelligenza Artificiale *on-device*.

---

## 1. Evoluzione del Motore di Estrazione (Intelligenza Artificiale Generativa Locale)

L'attuale motore di fallback (`VisionOCRExtractor`) utilizza espressioni regolari (Regex) applicate al testo riconosciuto da Apple Vision. Sebbene efficace per parametri quantitativi standard (Pressione, Colesterolo, Glicemia), mostra limiti sui referti puramente discorsivi o narrativi (es. anamnesi, lettere di dimissione, referti radiologici).

- **Integrazione di SLM (Small Language Models) On-Device**: Grazie ai recenti framework Apple (come `MLX` o `CoreML`), sarebbe possibile eseguire modelli linguistici di dimensioni ridotte (es. Llama 3 8B quantizzato o modelli specializzati in NLP medico) **direttamente sulla NPU (Neural Processing Unit) dell'iPhone**.
- **Vantaggio**: Un LLM locale potrebbe estrarre entità complesse (es. patologie, farmaci prescritti, allergie) da un testo destrutturato e mapparli automaticamente nei rispettivi codici LOINC o SNOMED CT, **senza mai inviare i dati al cloud**, mantenendo intatta l'architettura *Zero-Cloud* e la conformità al GDPR (Art. 9).

---

## 2. Ingegneria del Software: Test Automatizzati (XCTest e CI/CD)

L'attuale validazione del software è demandata a test manuali end-to-end sull'infrastruttura iOS. Trattandosi di un'applicazione in ambito *Digital Health*, la tolleranza per regressioni nei parser o nei calcoli di conversione (es. sfasamenti nelle unità di misura) deve essere nulla.
- **Integrazione XCTest**: Lo sviluppo futuro prevede la stesura di una suite completa di Unit Test (per testare individualmente le Regex e le mappature LOINC) e UI Test. Sarebbe fondamentale iniettare dozzine di "Mock CDA XML" (anominizzati) per validare che l'estrattore SAX (`RosettaTranscoder`) si comporti in modo deterministico al variare della struttura del referto.
- **CI/CD Pipeline**: L'implementazione di una pipeline di Continuous Integration (es. tramite GitHub Actions o Xcode Cloud) permetterebbe di testare automaticamente la tenuta del codice ad ogni nuovo aggiornamento degli standard HL7.

---

## 3. Storage Indipendente e Caching (SwiftData)

Allo stato attuale, l'app agisce puramente come "Ponte di transito" (Producer-Consumer): estrae, invia ad Apple Salute e cancella (Zero-Retention) per massimizzare la sicurezza.
- **Integrazione SwiftData**: Per gli utenti che desiderano un archivio documentale avanzato *all'interno* di RosettaHealth, si potrebbe implementare un layer di persistenza locale utilizzando **SwiftData** protetto da crittografia hardware di massimo livello (`.complete`).
- **Vantaggio**: Questo permetterebbe all'app di offrire funzioni di ricerca testuale full-text sui referti passati, filtri per data/patologia e una *Timeline Storica* navigabile offline in tempo reale, indipendentemente dalle limitazioni di visualizzazione dell'app Salute nativa.

---

## 4. Sincronizzazione Trasparente in Background (BGTaskScheduler)

Il pattern attuale richiede che l'utente apra l'App Principale affinché il `Consumer` (`AppViewModel`) intercetti e processi i file accumulati dall'estensione nel container condiviso (sfruttando il trigger `.scenePhase == .active`).
- **Integrazione BGAppRefreshTask**: Registrando un task di background tramite il framework `BackgroundTasks`, l'app potrebbe essere "risvegliata" silenziosamente da iOS per pochi secondi.
- **Vantaggio**: I documenti inviati all'estensione di condivisione verrebbero transcodificati e ingeriti in HealthKit in maniera totalmente invisibile. L'utente riceverebbe solo una notifica locale di conferma (es. *"Nuovo referto aggiunto ad Apple Salute"*), senza mai dover aprire fisicamente RosettaHealth. L'unico vincolo tecnico rimane la gestione della *Data Protection* (l'esecuzione deve avvenire solo quando il dispositivo è sbloccato).

---

## 5. Estensione Ontologica (SNOMED CT e Mappatura Dinamica)

Attualmente il bridge di HealthKit si affida a una mappatura statica (`loincToHKMap`) limitata a un set predefinito di codici LOINC per le misurazioni vitali principali.
- **Integrazione SNOMED CT**: Lo standard CDA italiano fa ampio uso del vocabolario SNOMED CT per codificare diagnosi, procedure e sostanze (es. allergeni). Il motore potrebbe essere esteso per includere un resolver locale (SQLite-based) in grado di decodificare e mappare l'ontologia SNOMED verso i rispettivi *Clinical Records* (quando disponibili) o esportarli nel JSON.
- **Vantaggio**: Espanderebbe la portata dell'estrattore dalle semplici metriche quantitative a un fascicolo narrativo e diagnostico completo, rendendo il dato strutturato intellegibile a qualsiasi motore inferenziale medico.

---

## 6. iOS Widgets e Monitoraggio della Prevenzione (Empowerment del Paziente)

Per aumentare la consapevolezza clinica e incentivare la medicina preventiva, l'esposizione dei dati non dovrebbe limitarsi all'apertura dell'app.
- **Integrazione `WidgetExtension`**: Sviluppo di un Widget per la Home Screen e Lock Screen di iOS, rigorosamente vincolato alle regole di *Data Protection* (oscuramento automatico a schermo bloccato).
- **Vantaggio**: Il Widget mostrerebbe le metriche più critiche dell'ultimo referto (es. Colesterolo LDL o Glicemia) affiancate al delta di variazione rispetto all'anno precedente. Questo meccanismo di *Nudging* visivo favorisce l'engagement continuo del paziente nella gestione attiva della propria salute.

---

## 7. Evoluzione da "Pipe" a "Vault": Archivio Familiare Crittografato (EMR Tascabile)

Attualmente RosettaHealth opera come un sistema di transito puro (Pipe) con politica *Zero-Retention*, scartando i referti (tramite blocco `cfMismatch`) qualora il Codice Fiscale del paziente non coincida con quello del proprietario dell'iPhone. 
- **Integrazione "Family Vault" (Post-Tesi)**: In scenari reali, i *caregiver* gestiscono i referti di figli minorenni o genitori anziani. L'espansione naturale post-tesi prevede l'evoluzione dell'app in un **Fascicolo Sanitario Elettronico (EMR) multi-utente**. Se il Codice Fiscale non combacia col proprietario, il referto non verrebbe scartato, ma segregato in "Cartelle Familiari" locali.
- **Vantaggio e Implementazione**: Sfruttando `SwiftData` o il File System locale protetto (escludendo programmaticamente la directory dal backup iCloud per mantenere il vincolo *Zero-Cloud*), il cittadino potrebbe navigare i PDF e i trend clinici dei propri familiari all'interno di tab separati, trasformando RosettaHealth in un vero e proprio archivio medico centralizzato per l'intera famiglia.

---

## 8. Portabilità dei Dati: Integrazione SMART on FHIR

Attualmente, l'esportazione dei referti transcodificati in formato JSON IPS avviene in modo statico e manuale (condivisione file). Un'espansione post-tesi di caratura Enterprise prevede l'integrazione del protocollo globale **SMART on FHIR**.
- **Implementazione (ASWebAuthenticationSession)**: Implementando un modulo `FHIRNetworkClient`, l'app permetterebbe al paziente di autenticarsi tramite OAuth 2.0 presso i portali dei propri ospedali o specialisti di riferimento.
- **Il Paradosso della Privacy Risolto**: Pur rompendo tecnicamente l'isolamento *Zero-Cloud*, questa trasmissione avverrebbe sotto rigido layer crittografico (TLS 1.3) ed esclusivamente tramite consenso granulare. Si tratterebbe della massima espressione del **Diritto alla Portabilità dei Dati (Art. 20 GDPR)**, consentendo al cittadino di inviare il proprio Bundle FHIR direttamente all'EMR del medico curante, senza dover consegnare documenti cartacei.
