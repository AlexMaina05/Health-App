import codecs
import re

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/Vault/FamilyVaultView.swift', 'r', 'utf-8') as f:
    text = f.read()

text = re.sub(r'    func updateUIViewController\(_ uiViewController: UIActivityViewController, context: Context\) \{\}\n\}', '', text)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/Vault/FamilyVaultView.swift', 'w', 'utf-8') as f:
    f.write(text)