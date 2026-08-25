import codecs

filepath = 'e:/Code/Health-App/Sources/RosettaHealthApp/MainAppView.swift'
with codecs.open(filepath, 'r', 'utf-8') as f:
    content = f.read()

# Add init and container
init_code = """    private let container: ModelContainer
    
    public init() {
        let syncEnabled = UserDefaults.standard.bool(forKey: "isCloudSyncEnabled")
        let config = ModelConfiguration(cloudKitDatabase: syncEnabled ? .automatic : .none)
        do {
            container = try ModelContainer(for: VaultDocument.self, configurations: config)
        } catch {
            fatalError("Impossibile caricare il database: \(error)")
        }
    }"""
content = content.replace('    public init() {}', init_code)

# Replace .modelContainer(for: [VaultDocument.self])
content = content.replace('.modelContainer(for: [VaultDocument.self])', '.modelContainer(container)')

with codecs.open(filepath, 'w', 'utf-8') as f:
    f.write(content)