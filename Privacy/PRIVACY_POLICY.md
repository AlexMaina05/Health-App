# Informativa sul Trattamento dei Dati Personali (Privacy Policy)
**Ai sensi degli Artt. 13 e 14 del Regolamento (UE) 2016/679 (GDPR)**

Ultimo aggiornamento: 24 Agosto 2026

## 1. Titolare del Trattamento
Il Titolare del Trattamento dei dati è Alex Maina, in qualità di sviluppatore indipendente (il "Titolare").  
Contatto privacy: privacy@alexmaina.dev

## 2. Tipologia di Dati Trattati e Finalità
L'Applicazione **RosettaHealth** (di seguito l'"App") acquisisce, decodifica e gestisce **Dati relativi alla Salute** (appartenenti alle categorie particolari di dati ex Art. 9 GDPR) e **Dati Anagrafici** (Nome, Cognome, Codice Fiscale, Data di Nascita).
I dati vengono acquisiti quando l'utente importa volontariamente referti medici in formato PDF/CDA.  
**Finalità**: La finalità esclusiva del trattamento è consentire all'Utente la decodifica, l'archiviazione e la visualizzazione interattiva dei propri parametri clinici o di quelli dei propri familiari, integrando i risultati con Apple HealthKit.

## 3. Modalità del Trattamento (Zero-Cloud Architecture)
L'App adotta un approccio **Privacy by Design**. Tutto il trattamento (parsing XML, estrazione ottica OCR, calcolo trend CDS) avviene **rigorosamente in locale (on-device)** sul dispositivo dell'Utente.
- Nessun dato clinico viene mai trasmesso a server cloud, endpoint API esterni, né al Titolare.
- L'App è deliberatamente sprovvista di autorizzazioni di rete (Networking disabilitato a livello OS).
- I dati biometrici sensibili (es. Codice Fiscale) sono protetti nel Keychain hardware.

## 4. Base Giuridica del Trattamento
Il trattamento si fonda sul **Consenso esplicito** dell'interessato (Art. 9, par. 2, lett. a GDPR), raccolto in fase di Onboarding. Nel caso di gestione di referti di terzi (es. familiari, minori), il trattamento ricade nell'**Esenzione per uso personale o domestico** (Art. 2, par. 2, lett. c GDPR) sotto la diretta responsabilità legale dell'Utente.

## 5. Diritto all'Oblio e Conservazione (Art. 17 GDPR)
L'Utente ha il controllo assoluto sui propri dati. Essendo archiviati solo in locale (via SwiftData e HealthKit), l'Utente può esercitare il Diritto alla Cancellazione in qualsiasi momento:
- Eseguendo uno swipe-to-delete sul referto specifico all'interno della schermata "Family Vault".
- Disinstallando l'applicazione (azione che distrugge irreversibilmente il database locale).

## 6. Processi Decisionali Automatizzati e AI
L'App utilizza algoritmi di Intelligenza Artificiale (Apple Vision Framework) per estrarre valori numerici dai PDF testuali. L'Utente è protetto da errori sistemici (esattezza dei dati) grazie a un meccanismo di **Human-in-the-Loop**: i dati estratti via OCR non vengono mai salvati automaticamente nel registro clinico, ma richiedono la convalida visiva e l'esplicita accettazione ("Approva e Salva") da parte dell'Utente.