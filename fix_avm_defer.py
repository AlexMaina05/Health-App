import codecs
import re

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/AppViewModel.swift', 'r', 'utf-8') as f:
    text = f.read()

text = re.sub(r'(// 1\. Processa XML Nativi\s+for file in pendingXMLs \{\s+)(if let xmlData = try\? Data\(contentsOf: file\) \{)', r'\1defer { try? FileManager.default.removeItem(at: file) }\n                \2', text)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/AppViewModel.swift', 'w', 'utf-8') as f:
    f.write(text)