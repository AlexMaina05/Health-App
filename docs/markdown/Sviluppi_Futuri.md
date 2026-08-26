# Sviluppi Futuri e Roadmap Architetturale (v4.0+)

Avendo completato l'integrazione con Apple HealthKit, la messa in sicurezza multi-profilo (Family Vault), l'estensione ai Widget, i Background Tasks notturni, l'annotazione vettoriale dei PDF e la Companion App per watchOS (in rigoroso rispetto del GDPR Zero-Cloud), le seguenti funzionalità rappresentano i prossimi passi per trasformare RosettaHealth nel punto di riferimento HealthTech europeo.

---

## 1. Dashboard Olistica Proprietaria (Oltre i limiti di Apple Health)
Apple Salute (HealthKit) limita storicamente i propri grafici nativi a un set predefinito di metriche (`HKQuantityTypeIdentifier`), escludendo parametri fondamentali della medicina di base (es. **Creatinina sierica, TSH, FT4, Transaminasi, Ferritina, Emoglobina Glicata**). 
L'obiettivo è sviluppare un'interfaccia proprietaria in *Swift Charts* all'interno di RosettaHealth. L'App diventerà un aggregatore clinico assoluto: leggerà i dati autorizzati da Apple Salute e li intersecherà con i dati avanzati estratti dai referti FHIR archiviati nel Vault, offrendo al paziente (e al medico curante) un panorama ematologico completo e senza punti ciechi, superando i vincoli di sistema imposti da Cupertino.

---

## 2. Desktop-Class App per iPadOS 17 (NavigationSplitView)
Grazie al nuovissimo supporto nativo di HealthKit introdotto da Apple in **iPadOS 17**, il database sanitario è ora accessibile anche dai tablet. Il prossimo passo architetturale per la UI prevede l'abbandono del semplice `NavigationStack` in favore di un layout a `NavigationSplitView`. 
Questo permetterà di sfruttare i display di grandi dimensioni: la sidebar laterale ospiterà il *Family Vault* e la lista dei pazienti, mentre la *Detail View* centrale renderizzerà simultaneamente il referto PDF originale (via `PDFKit`) e i modelli tridimensionali delle metriche cliniche.

---

---

## 3. Estensione Ontologica Globale (SNOMED CT)
Espandere l'attuale mappatura LOINC statica con un database vettoriale locale (es. SQLite/CoreData) contenente l'ontologia completa **SNOMED CT** e **ICD-10**. Questo permetterebbe di convertire in codice strutturato non solo le misurazioni vitali, ma anche patologie, farmaci prescritti e allergie per una mappatura clinica totale.

---

## 4. Portabilità dei Dati: Integrazione SMART on FHIR
Integrare il protocollo globale OAuth 2.0 (tramite `ASWebAuthenticationSession`) e un Client di Rete FHIR dedicato. Questo permetterebbe agli utenti di trasmettere direttamente, e con granularità di permessi, i propri referti transcodificati all'EMR (Electronic Medical Record) del proprio ospedale europeo, dando piena e formale attuazione al Diritto alla Portabilità dei Dati (Art. 20 GDPR).

---

## 6. Integrazione Apple Intelligence (AppIntents e Siri)
Sfruttando le nuove capacità semantiche di Siri (con esecuzione strettamente locale su Apple Silicon), implementare l'interrogazione vocale autonoma tramite il framework `AppIntents`. 
Esempio di query: *"Ehi Siri, chiedi a RosettaHealth se il mio colesterolo e la mia creatinina sono peggiorati rispetto al referto dell'anno scorso"*.
