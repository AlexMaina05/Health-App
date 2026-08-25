import codecs

filepath = 'e:/Code/Health-App/tdd.md'
with codecs.open(filepath, 'r', 'utf-8') as f:
    content = f.read()

updates = """

### 7.4 Backup iCloud e CloudKit (Opt-In)
Il *Family Vault* supporta la sincronizzazione opzionale tramite il **CloudKit Private Database** di Apple.
- **Architettura a Doppio Container:** In base alla variabile `isCloudSyncEnabled` in `UserDefaults`, `RosettaHealthApp.swift` inizializza `ModelConfiguration` con `cloudKitDatabase: .automatic` oppure `.none`.
- **GDPR Compliance:** Dato che sfrutta il database privato dell'utente associato al suo Apple ID, l'infrastruttura CloudKit rimane invisibile agli sviluppatori e crittografata end-to-end. Il passaggio invalida il termine "Zero-Cloud" mutandolo in "Zero-Server-Terzi".
- **Limiti di SwiftData:** Per supportare CloudKit, il vincolo di unicità (`@Attribute(.unique)`) su `VaultDocument.id` è stato rimosso in favore degli identificativi nativi di CloudKit, e tutti gli attributi del modello hanno ora valori di default espliciti."""

content += updates

with codecs.open(filepath, 'w', 'utf-8') as f:
    f.write(content)