# Analisi dello Stato dell'Arte: Fascicolo Sanitario Elettronico e Interoperabilità Consumer

Questo documento analizza lo stato attuale dell'infrastruttura sanitaria digitale (con particolare focus sul panorama italiano), l'evoluzione degli standard di interoperabilità clinica e le limitazioni degli attuali ecosistemi consumer. L'analisi contestualizza la necessità architetturale e l'innovazione introdotta dal progetto **RosettaHealth**.

---

## 1. Il Fascicolo Sanitario Elettronico (FSE 2.0) in Italia

Il Fascicolo Sanitario Elettronico rappresenta il pilastro della sanità digitale italiana. Raccoglie la storia clinica del cittadino (referti, prescrizioni, vaccinazioni) rendendola disponibile a pazienti e professionisti sanitari.

### 1.1 Il Formato HL7 CDA R2
In Italia, la struttura dei documenti all'interno del FSE è regolamentata dalle specifiche nazionali basate sullo standard **HL7 CDA R2 (Clinical Document Architecture, Release 2)**.
- **Caratteristiche**: È un formato basato su XML, estremamente rigoroso, progettato per garantire l'autenticità e la persistenza legale del documento (attraverso firme digitali e OID - *Object Identifiers*).
- **Limitazioni Consumer**: Pur essendo eccellente per l'archiviazione medico-legale, il CDA R2 è un formato legacy, "verboso" e complesso da parsare. Non è nativamente predisposto per l'integrazione con applicazioni mobili moderne o per l'estrazione rapida di singole metriche (es. la glicemia di un paziente). Viene comunemente "nascosto" incapsulandolo come allegato all'interno di file PDF/A-3.

---

## 2. L'Evoluzione degli Standard: Verso HL7 FHIR R4

Mentre l'Italia consolida il CDA R2, il panorama tecnologico globale (inclusa l'OMS, Apple, Google e Microsoft) ha virato con decisione verso un nuovo standard: **HL7 FHIR (Fast Healthcare Interoperability Resources)**, in particolare la release R4.

- **Dati come Risorse (JSON/RESTful)**: A differenza del CDA (che è incentrato sul "documento intero"), FHIR modella le informazioni cliniche come risorse indipendenti (es. `Patient`, `Observation`, `Condition`) interrogate tramite API REST e formattate in JSON.
- **Adozione Globale**: FHIR è diventato lo standard di fatto per l'integrazione consumer-medico. Negli Stati Uniti, il *21st Century Cures Act* impone l'uso di API FHIR per lo scambio di dati sanitari.

*Attualmente, esiste uno scollamento profondo tra l'archivio nazionale italiano (CDA) e gli strumenti tecnologici moderni (FHIR).*

---

## 3. L'Ecosistema Apple Health (HealthKit) e i "Clinical Records"

Apple Salute (HealthKit) è il raccoglitore di dati sanitari più diffuso al mondo, permettendo agli utenti di incrociare dati clinici (esami del sangue) con dati comportamentali (battito cardiaco, sonno, attività fisica registrati da Apple Watch).

### 3.1 Il Limite dell'Infrastruttura Chiusa
Apple ha introdotto la funzione *Cartella Clinica (Health Records)* che scarica automaticamente i referti ospedalieri nel telefono dell'utente. Tuttavia:
1. **Vincolo SMART on FHIR**: L'infrastruttura Apple si connette **esclusivamente** a portali istituzionali che supportano le API *SMART on FHIR*.
2. **Assenza in Italia**: Poiché il sistema sanitario italiano si basa su infrastrutture regionali frammentate e su documenti CDA R2 privi di endpoint FHIR esposti al pubblico, la funzione nativa di Apple non è attiva né utilizzabile in Italia (se non per pochissime cliniche private isolate).
3. **Barriera all'Ingresso**: Le API per scrivere nativamente documenti clinici in Apple Salute (`HKClinicalRecord`) sono classificate come "Restricted" e richiedono una partnership formale con Apple, tagliando fuori sviluppatori indipendenti e ricercatori.

---

## 4. Soluzioni Attuali e Loro Limiti

Ad oggi, un paziente italiano che desidera monitorare i propri valori storici (es. l'andamento del colesterolo negli ultimi 5 anni) ha a disposizione soluzioni inadeguate:

1. **App Regionali del FSE**: Permettono la visualizzazione dei referti esclusivamente in formato PDF. Agiscono come "visualizzatori" e non estraggono alcun dato computabile per tracciare grafici o trend.
2. **Inserimento Manuale**: L'utente è costretto ad aprire il PDF del referto e trascrivere manualmente ogni singolo valore (es. Pressione, Glicemia) all'interno dell'App Salute di Apple. Un processo tedioso e prono ad errori di battitura, che disincentiva il monitoraggio a lungo termine.
3. **Parser Cloud-Based di Terze Parti**: Alcune startup propongono l'invio del PDF a server proprietari per l'estrazione tramite AI. Questa soluzione viola il principio di minimizzazione dei dati (GDPR Art. 9) e pone enormi rischi di sicurezza (Data Leakage) esponendo dati medico-legali su reti esterne.

---

## 5. Il Vuoto Tecnologico Colmato da RosettaHealth

Dall'analisi dello stato dell'arte emerge un vuoto infrastrutturale che isola il cittadino dai propri dati sanitari. **RosettaHealth** si inserisce esattamente in questa frattura, proponendo un'architettura che supera tutti i limiti analizzati:

1. **Interoperabilità Retroattiva (Local Transcoder)**: Invece di attendere l'adeguamento statale a FHIR, l'app intercetta il PDF/A-3, estrae l'XML CDA locale e lo converte in FHIR R4 JSON istantaneamente e *on-device*, fungendo da ponte (Rosetta Stone) tra la vecchia sanità e il nuovo ecosistema.
2. **Dual-Track Ingestion (Bypass delle API Restricted)**: Non potendo usare l'API riservata `HKClinicalRecord`, l'app scompone chirurgicamente il dato in due vie legali e pubbliche: il salvataggio documentale integrale (`HKCDADocumentSample`) per l'archiviazione formale, e l'estrazione quantitativa selettiva (`HKQuantitySample`) per popolare i grafici di sistema.
3. **Resilienza (Graceful Degradation)**: Riconoscendo che molti documenti del FSE sono scansioni rasterizzate prive di XML, l'architettura non fallisce ma adotta un piano di fallback tramite Computer Vision (Apple Vision OCR), garantendo l'estrazione del dato anche dai referti analogici, etichettandolo rigorosamente con metadati di provenienza per mantenere la validità dell'audit clinico.
4. **Dashboard Olistica Proprietaria**: Dal momento che HealthKit supporta nativamente un numero ristretto di misurazioni grafiche (scartando ad esempio Creatinina e TSH), l'App funge non solo da traduttore, ma da *Electronic Medical Record (EMR)* indipendente, fornendo interfacce tridimensionali (Swift Charts 3D Scroll) e Live Activities su Dynamic Island per coprire i buchi architetturali di Apple.
5. **Privacy by Design**: Ogni singola elaborazione, dal parsing XML all'inferenza IA, avviene sulla CPU locale senza alcuna chiamata di rete (`URLSession` assente), applicando programmaticamente la crittografia di grado militare hardware (AES-256) per conformità totale al GDPR.


---

## 📚 Riferimenti Bibliografici & Monografia Ufficiale

- **Monografia Tecnica Accademica**: [Scarica il Paper Completo (PDF, 43 Pagine)](https://alexmaina.dev/Health-App/rosettahealth-monografia-tecnica.pdf)
- **Autore**: [Alessandro Mainardi](https://alexmaina.dev/) — Alma Mater Studiorum Università di Bologna (DISI)
- **Identificatori Persistenti**: ORCID [0009-0003-7003-7247](https://orcid.org/0009-0003-7003-7247) · Wikidata [Q141886579](https://www.wikidata.org/wiki/Q141886579) · DOI [10.5281/zenodo.23692700](https://doi.org/10.5281/zenodo.23692700)
- **Portale Ufficiale**: [alexmaina.dev](https://alexmaina.dev/)
