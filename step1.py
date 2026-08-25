import codecs

filepath = 'e:/Code/Health-App/Sources/RosettaHealthApp/Vault/VaultDocument.swift'
with codecs.open(filepath, 'r', 'utf-8') as f:
    content = f.read()

# Make changes to VaultDocument
content = content.replace('@Attribute(.unique) public var id: UUID', 'public var id: UUID = UUID()')
content = content.replace('public var dateAdded: Date', 'public var dateAdded: Date = Date()')
content = content.replace('public var patientName: String', 'public var patientName: String = ""')
content = content.replace('public var fiscalCode: String', 'public var fiscalCode: String = ""')
content = content.replace('public var documentTitle: String', 'public var documentTitle: String = ""')
content = content.replace('public var documentDate: Date', 'public var documentDate: Date = Date()')
content = content.replace('@Attribute(.externalStorage) public var fhirBundleJSON: Data', '@Attribute(.externalStorage) public var fhirBundleJSON: Data = Data()')

with codecs.open(filepath, 'w', 'utf-8') as f:
    f.write(content)
