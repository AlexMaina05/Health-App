# Integrazione Swift Charts e Layout iPad (NavigationSplitView)

Questo piano architetturale porta RosettaHealth al livello successivo, espandendo l'interfaccia per iPadOS 17+ (sfruttando le dimensioni dello schermo) e introducendo la visualizzazione dati proprietaria tramite Swift Charts, superando i limiti di Apple Health.

## Proposed Changes

### Componente 1: Architettura di Navigazione (iPadOS)

#### [MODIFY] Sources/RosettaHealthApp/Vault/FamilyVaultView.swift
- **Sostituzione** del `NavigationStack` con `NavigationSplitView`.
- **Sidebar**: conterrà la `List` attuale raggruppata per paziente/Codice Fiscale, gestendo lo stato `selection: $selectedDocument`.
- **Detail**: renderizzerà la nuova `VaultDocumentDetailView` potenziata, o un `ContentUnavailableView` se nessun referto è selezionato.

### Componente 2: Integrazione Swift Charts e Layout Ibrido

#### [NEW] Sources/RosettaHealthApp/Vault/ClinicalDashboardView.swift
- Creazione di una nuova View dedicata all'analisi visiva dei dati clinici estratti dai referti.
- Utilizzo intensivo di `Charts` (`LineMark`, `BarMark`, `AreaMark`) per tracciare trend ematologici (es. Ferritina, Emoglobina Glicata, Transaminasi).
- Interattività nativa: `.chartScrollableAxes`, `.chartXVisibleDomain`, e tooltips interattivi (gestures).

#### [MODIFY] Sources/RosettaHealthApp/Vault/FamilyVaultView.swift (Sezione `VaultDocumentDetailView`)
- Modifica del layout della Detail View per rispondere alla `horizontalSizeClass`.
- **Su iPad (Regular)**: `HStack` che divide lo schermo a metà. A sinistra il `PDFKit` (referto originale), a destra la `ClinicalDashboardView` (estrazione dati vettorializzata).
- **Su iPhone (Compact)**: `ScrollView` verticale con `VStack`.

## Verification Plan

### Manual Verification
- Compilazione e avvio del simulatore iPad Pro 13".
- Verifica che la `NavigationSplitView` mostri la lista a sinistra e si aggiorni cliccando su un documento.
- Verifica che il rendering simultaneo PDF + Grafico Swift Charts avvenga correttamente.
- Rotazione del device e split-screen per confermare l'adattabilità della size class.