import codecs

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/AppViewModel.swift', 'r', 'utf-8') as f:
    text = f.read()

text = text.replace('logger.error("Errore CDS per \\\\(hkType.rawValue): \\\\(error.localizedDescription)")', 'logger.error("Errore CDS per \\(hkType.rawValue): \\(error.localizedDescription)")')

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/AppViewModel.swift', 'w', 'utf-8') as f:
    f.write(text)