# Policy del Family Vault & Gestione di Dati di Terzi
**Disclaimer e Informativa per la custodia di referti medici familiari**

L'applicazione RosettaHealth è dotata di un "Security Checkpoint" progettato per proteggere il database Apple Health dell'Utente (che è strettamente mono-utente). Qualora il motore rilevi che un referto medico importato appartenga a un'altra persona (in base all'analisi semantica del Codice Fiscale), il referto non viene iniettato in Salute, ma isolato in uno spazio crittografato chiamato **Family Vault**.

## Inquadramento Giuridico (Household Exemption)
Il trattamento di dati sanitari appartenenti a familiari o conviventi, se effettuato sul dispositivo personale dell'Utente e senza alcuna comunicazione o diffusione a terzi, ricade sotto la **Esenzione per uso personale o domestico** (Art. 2, par. 2, lett. c del Regolamento UE 2016/679 - GDPR). 
Ai sensi di tale esenzione, la normativa GDPR non si applica direttamente, ma l'Utente assume la piena responsabilità legale della custodia dei dati.

## Assunzione di Responsabilità
Mediante l'accettazione del consenso esplicito durante la fase iniziale di Onboarding, l'Utente dichiara, sotto la propria esclusiva responsabilità civile e penale, che ogni referto clinico di terzi archiviato volontariamente all'interno dell'applicazione avviene:
1. **Per i Minori**: Agendo in qualità di esercente la responsabilità genitoriale o tutore legale.
2. **Per gli Adulti**: Avendo preventivamente informato e ottenuto il libero, esplicito e inequivocabile consenso (o possedendo formale delega sanitaria/procura) della persona interessata alla conservazione dei propri referti sul dispositivo dell'Utente.

## Misure di Salvaguardia Tecniche
Per tutelare la privacy dei terzi inseriti nel Vault, l'applicazione garantisce:
- Crittografia a riposo (Data at Rest) dei file in isolamento.
- Oscuramento immediato (Black Screen) se l'app perde il focus principale.
- Requisito di sblocco biometrico (FaceID / TouchID) per consultare i referti, prevenendo l'accesso non autorizzato da parte di chiunque impugni temporaneamente il dispositivo sbloccato.