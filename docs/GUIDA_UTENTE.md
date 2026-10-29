# ⚕️ RosettaEdge - Guida Utente Completa

Benvenuto in **RosettaEdge**, l'unica app progettata per tradurre i tuoi referti medici italiani in dati strutturati per Apple Salute, il tutto con una sicurezza **Zero-Cloud** al 100% sul tuo dispositivo.

---

## 1. Installazione

1. Apri l'**App Store** sul tuo iPhone (richiede iOS 26.0 o successivo).
2. Cerca **RosettaEdge** e tocca **Ottieni**.
3. Al termine del download, l'app apparirà nella tua schermata Home.

---

## 2. Configurazione Iniziale (Onboarding)

Al primo avvio, RosettaEdge ti guiderà nella configurazione di base per garantire la tua privacy.

1. **Scorri il Carosello:** Leggi le introduzioni sulle funzionalità chiave.
2. **Dati Anagrafici:** Inserisci il tuo **Nome**, **Cognome** e **Data di Nascita**. L'app genererà un *Codice Fiscale virtuale* basato sui tuoi dati per riconoscere i tuoi referti.
3. **Modalità Anonima:** Se non possiedi un Codice Fiscale italiano (es. utente straniero / STP), attiva l'interruttore **"Non possiedo un Codice Fiscale"**. L'app utilizzerà il riconoscimento intelligente (Fuzzy Name Matching) per proteggerti.
4. **Autorizzazione Salute:** Tocca **Consenti** quando viene richiesto l'accesso ad Apple Salute. Devi attivare tutti gli interruttori (Es. *Glicemia*, *Pressione*, *Colesterolo*) per permettere la scrittura.
5. **Consenso GDPR:** Accetta i termini per l'elaborazione dei dati *On-Device*.

---

## 3. Come Importare i Referti (PDF)

Puoi inviare i referti PDF scaricati dal tuo Fascicolo Sanitario Elettronico (FSE) all'app in tre modi:

### Metodo A: Share Sheet (Consigliato)
1. Apri l'app **File**, **Safari** o la tua app mail.
2. Apri il PDF del tuo esame del sangue.
3. Tocca il tasto **Condividi** (il quadrato con la freccia in alto).
4. Seleziona l'icona viola di **RosettaEdge**.
5. L'interfaccia ti confermerà l'acquisizione tramite un feedback aptico.

### Metodo B: In-App
1. Apri RosettaEdge e recati nella **Dashboard**.
2. Tocca l'icona a forma di **+** o la card per importare un file.
3. Scegli il PDF tramite il *File Picker* nativo.

### Metodo C: Drag & Drop (su iPad o multitasking)
1. Affianca RosettaEdge e l'app File.
2. Trascina fisicamente uno o più PDF all'interno della schermata dell'app.

> [!NOTE] 
> Durante l'importazione, la **Dynamic Island** e le **Live Activities** mostreranno lo stato di elaborazione in tempo reale, specialmente se il referto richiede un'estrazione tramite Intelligenza Artificiale (OCR).

---

## 4. Navigare nell'App

### Dashboard & Grafici
* **Grafici Interattivi:** Scorri lungo le curve (sparkline) per leggere l'esatto valore temporale delle tue metriche (es. *Colesterolo Totale*).
* **Badge Viola:** Se vedi un indicatore viola di fianco a un dato, significa che è stato estratto in via eccezionale dall'algoritmo visivo (OCR) e va considerato come *probabilistico*.

### Family Vault (Solo PRO)
* **Accesso:** Recati nella tab **Archivio**.
* **Referti Familiari:** Se importi un PDF appartenente a un tuo familiare (con Codice Fiscale diverso dal tuo), l'app **bloccherà l'invio ad Apple Salute** per non inquinare le tue statistiche, salvandolo nel Vault in modo cifrato.
* **Gestione:** Puoi visualizzare i referti originali o cancellarli scorrendo verso sinistra (Swipe-to-delete).

### Impostazioni e Personalizzazione
* **Tema Dinamico:** Nella tab Settings, puoi cambiare i colori dell'app scegliendo tra *Verde Salute*, *Rosso Cardio*, ecc.
* **Blocco Biometrico:** Verifica che il blocco Face ID / Touch ID sia attivo. In questo modo l'app richiederà lo sblocco ogni volta che la riapri o la riporti in primo piano, sfocando lo schermo nel multitasking (Privacy Blur).

---

## 5. Manutenzione e Sincronizzazione in Background

Non devi fare nulla per mantenere i dati aggiornati:
* **Elaborazione Notturna:** L'app utilizzerà la batteria residua di notte per elaborare enormi pile di referti non ancora scansionati, fancedoti trovare i grafici pronti al mattino.
* **Aggiornamento Manuale:** Nel Vault, puoi fare uno *Swipe verso il basso* (Pull-to-Refresh) per forzare l'app a ri-verificare tutti i referti pendenti.

---

## 🛡️ Sicurezza: Il tuo Diritto all'Oblio
Se decidi di disinstallare RosettaEdge, tutti i dati processati e contenuti nel Vault verranno **distrutti istantaneamente** dal tuo dispositivo e dal portachiavi (Keychain). Apple Salute manterrà unicamente i numeri nudi esportati in precedenza.
