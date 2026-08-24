# Data Protection Impact Assessment (DPIA)
Valutazione d'impatto ex Art. 35 GDPR.

## 1. Necessità
La DPIA è necessaria poiché RosettaHealth tratta dati sanitari su larga scala (se adottata) e utilizza tecnologie innovative (OCR euristico) su dati ex Art. 9.

## 2. Valutazione dei Rischi
- **Rischio**: Accesso non autorizzato ai dati locali.
  **Mitigazione**: Utilizzo di File Protection (crittografia at-rest) e Blocco Biometrico (Face ID).
- **Rischio**: Iniezioni errate in HealthKit causa OCR.
  **Mitigazione**: Validazione incrociata delle Regex e conversione corretta delle unità (es. mmol/L).
