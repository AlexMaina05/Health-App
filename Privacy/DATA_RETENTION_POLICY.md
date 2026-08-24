# Data Retention Policy
**Politiche di conservazione ed eliminazione dei dati ex Art. 5, par. 1, lett. e) GDPR**

La presente policy definisce i cicli di vita esatti dei dati processati da RosettaHealth sul dispositivo locale dell'Utente. Essendo l'architettura Zero-Cloud, non esistono log o backup residenti su server di proprietà del Titolare.

## 1. Dati in Transito (IPC e Memoria Volatile)
- **Container IPC Condiviso**: I documenti caricati tramite la "Share Extension" vengono depositati temporaneamente in un App Group condiviso crittografato. L'App principale esegue cicli di lettura su questa coda e applica una policy di **Zero-Retention**. Tramite costrutti atomici (`defer { try? FileManager.default.removeItem() }`), ogni file viene distrutto in modo definitivo e irreversibile al millisecondo esatto in cui termina l'operazione di parsing, indipendentemente dall'esito (successo o errore).
- **RAM**: Le stringhe diagnostiche caricate in RAM (es. il parser SAX XML) seguono lo stesso principio: la memoria viene liberata ad ogni fine nodo.

## 2. Dati Clinici nel "Family Vault" (Archivio a Lungo Termine)
- **Durata Conservazione**: I referti anomali (o deviati volontariamente al Vault per proteggere HealthKit) non possiedono una data di scadenza (Time-To-Live). L'app funge da cartella clinica EMR (Electronic Medical Record) personale, volta alla comparazione storica decennale dei parametri. Pertanto, la conservazione è **a tempo indeterminato**.
- **Smaltimento**: I dati persistono esclusivamente finché l'Utente non esercita un'azione esplicita e volontaria di distruzione, che avviene tramite l'interfaccia SwiftData (Swipe-to-Delete) o eliminando fisicamente l'applicazione dal dispositivo.

## 3. Dati Inseriti in Apple Salute (HealthKit)
- I campioni numerici estratti (`HKQuantitySample`) o i referti CDA iniettati (`HKCDADocumentSample`) in Apple HealthKit lasciano il dominio di competenza di RosettaHealth.
- Dal momento del salvataggio, la loro retention, backup (es. su iCloud crittografato end-to-end) ed eliminazione ricadono esclusivamente sotto i Termini di Servizio, le Policy Privacy e i controlli centralizzati forniti dall'applicazione **Salute (Health)** nativa di Apple Inc.