# 🌍 RosettaEdge - Roadmap di Internazionalizzazione (i18n)
*Documento strategico per l'espansione nel mercato sanitario europeo.*

## Il Contesto
Allo stato attuale (v1.0), l'app è verticalizzata sull'architettura italiana. Identifica la proprietà dei referti FSE basandosi unicamente sul Namespace OID del **Codice Fiscale** (`http://hl7.it/sid/codiceFiscale`) ed esige un input di 16 caratteri nell'Onboarding.

Per espandere l'app nei principali mercati europei (dove lo standard HL7 CDA / FHIR è altrettanto utilizzato ma con chiavi primarie diverse), non serve riscrivere il core engine. È sufficiente istruire il parser a riconoscere le "targhe" sanitarie dei Ministeri esteri.

---

## 1. Mappatura degli Identificatori Nazionali (NPI)
Di seguito gli URL/OID ufficiali utilizzati nei referti elettronici delle principali nazioni target:

| Nazione | Nome Identificatore | Lunghezza/Formato | FHIR System URL / OID |
| :--- | :--- | :--- | :--- |
| 🇮🇹 **Italia** | Codice Fiscale | 16 Alfanumerici | `http://hl7.it/sid/codiceFiscale` |
| 🇬🇧 **Regno Unito** | NHS Number | 10 Numerici | `https://fhir.nhs.uk/Id/nhs-number` |
| 🇫🇷 **Francia** | INS (NIR) | 15 Numerici | `urn:oid:1.2.250.1.213.1.4.8` |
| 🇩🇪 **Germania** | KVNR | 10 Alfanumerici (Lettera + 9) | `http://fhir.de/NamingSystem/gkv/kassenpatientennummer` |
| 🇪🇸 **Spagna** | SNS / CIP-SNS | 16 Alfanumerici | `urn:oid:2.16.724.4.40` |

---

## 2. Modifiche Architetturali Richieste

### A. Core Engine (Estrazione ID Agnostica)
In `AppViewModel.swift` e `RosettaTranscoder.swift`, la logica hardcoded per l'Italia verrà sostituita da un array di validazione agnostico:

```swift
let supportedNationalIdentifiers = [
    "http://hl7.it/sid/codiceFiscale",                   // IT
    "https://fhir.nhs.uk/Id/nhs-number",                 // UK
    "urn:oid:1.2.250.1.213.1.4.8",                       // FR
    "http://fhir.de/NamingSystem/gkv/kassenpatientennummer", // DE
    "urn:oid:2.16.724.4.40"                              // ES
]

// Estrazione sicura: il primo ID riconosciuto vince
if let nationalID = patient.identifier?.first(where: { supportedNationalIdentifiers.contains($0.system ?? "") })?.value {
    patientNationalID = nationalID.uppercased()
}
```

### B. UI Onboarding (Selettore Nazione)
In `OnboardingView.swift`, il modulo per l'Identificativo Sanitario non può più forzare un limite di 16 caratteri per tutti.
1. Inserire un `Picker` (es. "Seleziona Nazione") all'inizio del Form.
2. In base alla nazione selezionata, la logica della variabile booleana `isFormValid` cambierà le regole di validazione (es. se UK, deve bloccare a 10 caratteri e accettare solo numeri).
3. Cambiare il placeholder UI del TextField in modo dinamico (es. "NHS Number (10 cifre)" anziché "Codice Fiscale (16 caratteri)").

### C. Motore OCR (Vision Fallback)
I modelli di *Regular Expression* in `VisionOCRExtractor.swift` andranno estesi con le traduzioni locali per poter supportare i vecchi PDF scansionati esteri:
- **Glicemia:** Aggiungere `blood sugar` (UK), `glycémie` (FR), `blutzucker` (DE).
- **Colesterolo:** Aggiungere `cholesterol` (UK), `cholestérol` (FR), `cholesterin` (DE).

---

## 3. Strategia di Rilascio
1. Sviluppo in feature-branch separata (`feat/i18n-identifiers`).
2. Necessità di reperire su GitHub o da enti pubblici dei **referti XML HL7 di test "Mock" (anonimizzati)** per Francia, Germania e UK per validare che l'`AppViewModel` li digerisca senza mandare in crash Apple Salute.
3. Rilascio negli Store locali una Nazione alla volta per gestire l'App Store Optimization (ASO) in lingua locale.