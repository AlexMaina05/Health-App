import codecs
import os
import glob
import shutil

# Move all python scripts
os.makedirs("scripts/maintenance", exist_ok=True)
for file in glob.glob("*.py"):
    shutil.move(file, os.path.join("scripts/maintenance", file))

# Fix A.4 Poison Pill in AppViewModel
with codecs.open('Sources/RosettaHealthApp/AppViewModel.swift', 'r', 'utf-8') as f:
    text = f.read()

target_loop = """            for file in pendingXMLs {
                if let xmlData = try? Data(contentsOf: file) {"""
rep_loop = """            for file in pendingXMLs {
                defer { try? FileManager.default.removeItem(at: file) }
                if let xmlData = try? Data(contentsOf: file) {"""
text = text.replace(target_loop, rep_loop)

with codecs.open('Sources/RosettaHealthApp/AppViewModel.swift', 'w', 'utf-8') as f:
    f.write(text)

# Fix A.8 Blur in MainAppView
with codecs.open('Sources/RosettaHealthApp/MainAppView.swift', 'r', 'utf-8') as f:
    main = f.read()
main = main.replace('.blur(radius: (isBiometricLockEnabled && !authManager.isUnlocked) ? 15 : 0)', '')
main = main.replace('.disabled(isBiometricLockEnabled && !authManager.isUnlocked)', '.disabled(isBiometricLockEnabled && !authManager.isUnlocked)\n                .overlay { if isBiometricLockEnabled && !authManager.isUnlocked { Color.black.ignoresSafeArea() } }')
with codecs.open('Sources/RosettaHealthApp/MainAppView.swift', 'w', 'utf-8') as f:
    f.write(main)

# Fix A.10 RosettaError
with codecs.open('Sources/RosettaHealthCore/RosettaError.swift', 'r', 'utf-8') as f:
    err = f.read()
err = err.replace('non corrisponde al proprietario del Vault (\\(owner))', 'non corrisponde al proprietario del Vault (***)')
with codecs.open('Sources/RosettaHealthCore/RosettaError.swift', 'w', 'utf-8') as f:
    f.write(err)

# Fix A.12 PrivacySensitive in Widget
with codecs.open('Sources/RosettaWidget/RosettaParsingLiveActivity.swift', 'r', 'utf-8') as f:
    widget = f.read()
widget = widget.replace('Text(context.state.status)', 'Text(context.state.status)\n                    .privacySensitive()')
with codecs.open('Sources/RosettaWidget/RosettaParsingLiveActivity.swift', 'w', 'utf-8') as f:
    f.write(widget)