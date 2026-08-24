# Data Protection Impact Assessment (DPIA)
**Valutazione d'Impatto sulla Protezione dei Dati - RosettaHealth v3.0**

Documento redatto conformemente alle linee guida WP248 (GDPR Art. 35) e metodologia ENISA/CNIL.

## 1. Descrizione del Trattamento
L'app RosettaHealth esegue operazioni di decodifica, profilazione clinica automatizzata (Clinical Decision Support) e storage a lungo termine di referti sanitari (Fascicolo Sanitario Elettronico FSE) contenenti Dati Particolari (Art. 9 GDPR).

## 2. Valutazione della Necessità e Proporzionalità
Il trattamento locale è strettamente necessario per l'erogazione del servizio di aggregazione clinica. Non esistono alternative meno invasive (Data Minimization rispettata tramite approccio Zero-Cloud).

## 3. Matrice dei Rischi e Misure di Mitigazione

| Minaccia | Probabilità | Gravità | Rischio | Misura di Mitigazione (Implementata) |
|----------|-------------|---------|---------|----------------------------------------|
| **Data Breach (Furto Dispositivo)** | Alta | Critica | **Alto** | Crittografia *Data at Rest* `FileProtectionType.completeUntilFirstUserAuthentication`. Blocco biometrico in-app (FaceID) forzato in multitasking. PII memorizzate nel Keychain. |
| **Inquinamento Dati Medici (Inesattezza)** | Media | Alta | **Medio** | 1) Iniezione HL7 XML deterministica. 2) I dati estratti tramite euristiche OCR richiedono conferma esplicita *Human-in-the-loop*. 3) Sistema di rilevamento anomalia Codice Fiscale per proteggere HealthKit dai referti di familiari. |
| **Leakage verso Cloud/Terzi** | Bassa | Critica | **Basso** | Assenza fisica di stack di rete nell'app. Impossibilità tecnica di esfiltrazione dei dati. |
| **Persistenza File Temporanei IPC** | Media | Media | **Medio** | Operazioni atomiche di pulizia: blocco `defer { try? FileManager.default.removeItem(...) }` per garantire Zero-Retention nella Share Extension. |

## 4. Conclusioni DPIA
In virtù delle misure di sicurezza paramilitari integrate (Crittografia, Zero-Cloud, Human-in-the-loop, Keychain, Anti-Inquinamento SwiftData), il rischio residuo per i diritti e le libertà degli interessati è valutato come **Accettabile**. L'elaborazione non richiede la consultazione preventiva del Garante Privacy.