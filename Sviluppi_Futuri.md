# Sviluppi Futuri e Roadmap Architetturale (v4.0+)

Avendo completato l'integrazione con Apple HealthKit, la messa in sicurezza multi-profilo (Family Vault), l'estensione ai Widget e l'analisi predittiva (CDS) in rigoroso rispetto del GDPR (Zero-Cloud), le seguenti funzionalità rappresentano i prossimi passi per trasformare RosettaHealth in un prodotto HealthTech *State of the Art*.

---

## 1. Evoluzione del Motore di Estrazione (Intelligenza Artificiale Generativa Locale)
L'attuale motore OCR utilizza euristiche e regex. L'integrazione di SLM (Small Language Models) nativi tramite **MLX** o **CoreML** (es. modelli NLP specializzati in ambito medico) permetterebbe di estrarre e strutturare testi liberi complessi (anamnesi, lettere di dimissione), elaborando tutto sul Neural Engine dell'iPhone senza mai inviare dati su cloud.

---

## 2. Sincronizzazione Trasparente in Background (BGTaskScheduler)
Registrando un task di background tramite il framework `BackgroundTasks`, l'app potrebbe elaborare silenziosamente i referti depositati nel container condiviso dall'estensione senza che l'utente debba aprirla fisicamente, emettendo solo una notifica a operazione conclusa.

---

## 3. Estensione Ontologica (SNOMED CT e Mappatura Dinamica)
Espandere l'attuale mappatura LOINC statica con un database SQLite contenente l'ontologia SNOMED CT completa. Questo permetterebbe di convertire in codice FHIR non solo le misurazioni vitali, ma anche patologie, farmaci prescritti e allergie.

---

## 4. Portabilità dei Dati: Integrazione SMART on FHIR
Integrare il protocollo globale OAuth 2.0 (tramite `ASWebAuthenticationSession`) e un Client di Rete FHIR dedicato. Questo permetterebbe agli utenti di trasmettere direttamente, e con granularità di permessi, i propri referti transcodificati all'EMR dell'ospedale (piena attuazione dell'Art. 20 GDPR).

---

## 5. Tracciamento Visivo e Annotazione PDF (PDFKit + Vision)
Sfruttando le Bounding Boxes restituite da Apple Vision, il PDF originale verrebbe conservato e visualizzato all'interno del Vault, evidenziando vettorialmente in giallo i parametri esatti estratti dall'OCR, per una totale trasparenza e verificabilità da parte del medico o del paziente.

---

## 6. Companion App per Apple Watch (watchOS)
Un target *watchOS* indipendente che offra *Complications* (widget quadrante) per tenere sempre sott'occhio i propri trend glicemici o pressori direttamente dal polso.

---

## 7. Integrazione Siri On-Device (Apple Intelligence)
Sfruttando le nuove capacità semantiche di Siri introdotte con iOS 18 (e l'esecuzione strettamente locale su Apple Silicon), implementare l'interrogazione vocale autonoma: *"Ehi Siri, chiedi a RosettaHealth quanto avevo di Colesterolo lo scorso Gennaio"*.
