import codecs

with codecs.open('e:/Code/Health-App/README.md', 'r', 'utf-8') as f:
    readme = f.read()
readme = readme.replace('Requisiti di Sistema\n- iOS 17.0+', 'Requisiti di Sistema\n- iOS 26.0+ (Swift 6, Liquid Glass UI)')
readme = readme.replace('Architettura Moderna: SwiftUI, SwiftData', 'Architettura Moderna: SwiftUI (Liquid Glass), SwiftData (ModelActor)')
with codecs.open('e:/Code/Health-App/README.md', 'w', 'utf-8') as f:
    f.write(readme)

with codecs.open('e:/Code/Health-App/tdd.md', 'r', 'utf-8') as f:
    tdd = f.read()
updates = "\n\n## Aggiornamenti Architetturali (iOS 26 & Swift 6)\n- **Performance:** Risolto un memory leak critico implementando `HealthKitBridge` come Singleton globale.\n- **UI/UX:** Implementato il modificatore custom `.liquidGlass()` retrocompatibile e poi promosso a API nativa per iOS 26.\n- **Concorrenza:** Migrazione completa a `@Observable` e introduzione di `VaultModelActor` per query thread-safe in background."
tdd += updates
with codecs.open('e:/Code/Health-App/tdd.md', 'w', 'utf-8') as f:
    f.write(tdd)