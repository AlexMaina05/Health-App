# ⚕️ RosettaHealth - Centro Documentazione

Benvenuto nel portale ufficiale di documentazione di **RosettaHealth**, l'unica app progettata per tradurre i tuoi referti medici italiani in dati strutturati per Apple Salute, con una sicurezza **Zero-Cloud** al 100% sul tuo dispositivo.

---

## 🎯 Il Problema & La Soluzione
In Italia, l'esito di un esame diagnostico viene caricato sul Fascicolo Sanitario Elettronico come file PDF. Sepolto all'interno di quel documento si trova un payload **HL7 CDA R2 XML** — uno standard clinicamente accurato ma virtualmente illeggibile.
RosettaHealth è una *pipeline invisibile e sicura* sviluppata interamente in Swift (nativa). Estrae i referti complessi e li traduce in grafici interattivi all'interno di Apple Salute, il tutto senza che un singolo byte abbandoni il tuo iPhone.

---

## 📚 Indice della Documentazione

Utilizza la barra laterale per navigare tra i vari capitoli del progetto:

### Documentazione Core
* 📘 **[Guida Utente](GUIDA_UTENTE.html)**: Manuale per l'utilizzo dell'app da parte dei pazienti, inclusa la configurazione del Vault e di iCloud.
* 🛠️ **[Technical Design Document](tdd.html)**: Dettagli architetturali (SwiftData, OCR, HealthKit, ModelActor, Liquid Glass).

### Analisi e Strategia
* 📊 **[Business Plan](BUSINESS_PLAN.html)**: Analisi di mercato e modello di monetizzazione Freemium.
* 🔮 **[Sviluppi Futuri](Sviluppi_Futuri.html)**: Vision per le versioni 4.0+ (Cruscotti Olistici, LLM Locali).
* 🔬 **[Stato dell'Arte](Stato_dell_Arte.html)**: Contesto accademico e tecnologico.

### Sicurezza e Compliance
* 🔒 **[Privacy & DPIA](DPIA.html)**: Valutazione di impatto sulla protezione dei dati, crittografia Secure Enclave e GDPR.
* 🌍 **[Internazionalizzazione](INTERNATIONALIZATION.html)**: Standard europei (IPS) supportati.

> 💡 **Nota:** Se stai cercando il codice sorgente o le istruzioni di compilazione, visita il [Repository GitHub principale](https://github.com/AlexMaina05/Health-App).
