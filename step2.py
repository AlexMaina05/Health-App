import codecs

filepath = 'e:/Code/Health-App/Sources/RosettaHealthApp/AppViewModel.swift'
with codecs.open(filepath, 'r', 'utf-8') as f:
    content = f.read()

if 'isCloudSyncEnabled' not in content:
    content = content.replace('@AppStorage("isProUnlocked") public var isProUnlocked: Bool = false', '@AppStorage("isProUnlocked") public var isProUnlocked: Bool = false\n    @AppStorage("isCloudSyncEnabled") public var isCloudSyncEnabled: Bool = false')
    with codecs.open(filepath, 'w', 'utf-8') as f:
        f.write(content)