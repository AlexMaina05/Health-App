import codecs

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/AppViewModel.swift', 'r', 'utf-8') as f:
    text = f.read()

text = text.replace('logger.notice("Referto di \\(patientInfo.name) deviato al Vault Family.")', 'logger.notice("Referto di \\(patientInfo.name, privacy: .private) deviato al Vault Family.")')

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/AppViewModel.swift', 'w', 'utf-8') as f:
    f.write(text)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/RosettaError.swift', 'r', 'utf-8') as f:
    err = f.read()

err = err.replace('Il Codice Fiscale estratto (\\(found)) non corrisponde', 'Il Codice Fiscale estratto (***) non corrisponde')

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/RosettaError.swift', 'w', 'utf-8') as f:
    f.write(err)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/MainAppView.swift', 'r', 'utf-8') as f:
    main = f.read()
    
main = main.replace('print("Aperto da Spotlight documento ID: \\(uniqueIdentifier)")', 'print("Aperto documento da Spotlight.")')

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/MainAppView.swift', 'w', 'utf-8') as f:
    f.write(main)