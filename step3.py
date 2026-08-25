import codecs

filepath = 'e:/Code/Health-App/Sources/RosettaHealthApp/SettingsView.swift'
with codecs.open(filepath, 'r', 'utf-8') as f:
    content = f.read()

# Add the @AppStorage for isCloudSyncEnabled
if 'isCloudSyncEnabled' not in content:
    content = content.replace('@AppStorage("isProUnlocked") private var isProUnlocked: Bool = false', '@AppStorage("isProUnlocked") private var isProUnlocked: Bool = false\n    @AppStorage("isCloudSyncEnabled") private var isCloudSyncEnabled: Bool = false')

# Insert the section
section = """                Section(header: Text("Backup e Sincronizzazione")) {
                    Toggle("iCloud Sync (Family Vault)", isOn: $isCloudSyncEnabled)
                        .tint(.blue)
                    Text("Attivando iCloud, i referti verranno salvati sul tuo account privato. Modificare questa impostazione richiede il riavvio manuale dell'app per avere effetto.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section(header: Text("Funzionalità Sperimentali")) {"""
content = content.replace('Section(header: Text("Funzionalità Sperimentali")) {', section)

with codecs.open(filepath, 'w', 'utf-8') as f:
    f.write(content)