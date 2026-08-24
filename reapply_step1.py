import codecs

# 1. Update syncPendingDocuments and processPDF to use VaultModelActor
with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/AppViewModel.swift', 'r', 'utf-8') as f:
    text = f.read()

text = text.replace('public func syncPendingDocuments(modelContext: ModelContext?) async {', 'public func syncPendingDocuments(modelContainer: ModelContainer?) async {')
text = text.replace('public func processPDF(url: URL, modelContext: Any? = nil) async {', 'public func processPDF(url: URL, modelContainer: Any? = nil) async {')

old_vault1 = """                          // Vault Locale (SwiftData)
                          if !patientInfo.isOwner && !isProUnlocked {
                              throw RosettaError.familyVaultRequiresPro
                          }
                          if let context = modelContext {
                              let encoder = JSONEncoder()
                              if let jsonData = try? encoder.encode(bundle) {
                                  let title = bundle.type == "document" ? "Fascicolo Sanitario" : "Referto"
                                  let vaultDoc = VaultDocument(
                                      patientName: patientInfo.name,
                                      fiscalCode: patientInfo.cf,
                                      documentTitle: title,
                                      documentDate: Date(),
                                      fhirBundleJSON: jsonData,
                                      pdfData: try? Data(contentsOf: file)
                                  )
                                  context.insert(vaultDoc)
                                    if #available(iOS 17.0, *) {
                                        SpotlightManager.shared.indexDocument(
                                            id: vaultDoc.id.uuidString,
                                            title: vaultDoc.documentTitle,
                                            patientName: vaultDoc.patientName,
                                            date: vaultDoc.dateAdded
                                        )
                                    }
                                  try? context.save()
                              }
                          }"""
new_vault1 = """                          // Vault Locale (SwiftData)
                          if !patientInfo.isOwner && !isProUnlocked {
                              throw RosettaError.familyVaultRequiresPro
                          }
                          if let container = modelContainer {
                              let encoder = JSONEncoder()
                              if let jsonData = try? encoder.encode(bundle) {
                                  let title = bundle.type == "document" ? "Fascicolo Sanitario" : "Referto"
                                  let actor = VaultModelActor(modelContainer: container)
                                  try await actor.saveDocument(
                                      patientName: patientInfo.name,
                                      fiscalCode: patientInfo.cf,
                                      documentTitle: title,
                                      fhirBundleJSON: jsonData,
                                      pdfData: try? Data(contentsOf: file)
                                  )
                              }
                          }"""
text = text.replace(old_vault1, new_vault1)

old_vault2 = """                  // 2. Salvataggio nel Vault Locale (SwiftData)
                  if let context = modelContext as? SwiftData.ModelContext {
                      let encoder = JSONEncoder()
                      if let jsonData = try? encoder.encode(bundle) {
                          let title = bundle.type == "document" ? "Fascicolo Sanitario" : "Referto"
                          let vaultDoc = VaultDocument(
                              patientName: patientInfo.name,
                              fiscalCode: patientInfo.cf,
                              documentTitle: title,
                              documentDate: Date(),
                              fhirBundleJSON: jsonData,
                              pdfData: try? Data(contentsOf: url)
                          )
                          context.insert(vaultDoc)
                                    if #available(iOS 17.0, *) {
                                        SpotlightManager.shared.indexDocument(
                                            id: vaultDoc.id.uuidString,
                                            title: vaultDoc.documentTitle,
                                            patientName: vaultDoc.patientName,
                                            date: vaultDoc.dateAdded
                                        )
                                    }
                          try? context.save()
                      }
                  }"""
new_vault2 = """                  // 2. Salvataggio nel Vault Locale (SwiftData)
                  if let container = modelContainer as? SwiftData.ModelContainer {
                      let encoder = JSONEncoder()
                      if let jsonData = try? encoder.encode(bundle) {
                          let title = bundle.type == "document" ? "Fascicolo Sanitario" : "Referto"
                          let actor = VaultModelActor(modelContainer: container)
                          try await actor.saveDocument(
                              patientName: patientInfo.name,
                              fiscalCode: patientInfo.cf,
                              documentTitle: title,
                              fhirBundleJSON: jsonData,
                              pdfData: try? Data(contentsOf: url)
                          )
                      }
                  }"""
text = text.replace(old_vault2, new_vault2)
with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/AppViewModel.swift', 'w', 'utf-8') as f:
    f.write(text)

# 2. Fix BackgroundTaskManager
with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/BackgroundTaskManager.swift', 'r', 'utf-8') as f:
    text = f.read()
text = text.replace('public func registerTasks(modelContext: ModelContext? = nil) {', 'public func registerTasks(modelContainer: ModelContainer? = nil) {')
text = text.replace('self.handleProcessingTask(task: bgTask, modelContext: modelContext)', 'self.handleProcessingTask(task: bgTask, modelContainer: modelContainer)')
text = text.replace('private func handleProcessingTask(task: BGProcessingTask, modelContext: ModelContext?) {', 'private func handleProcessingTask(task: BGProcessingTask, modelContainer: ModelContainer?) {')
text = text.replace('await processPendingFilesHeadless(modelContext: modelContext)', 'await processPendingFilesHeadless(modelContainer: modelContainer)')
text = text.replace('private func processPendingFilesHeadless(modelContext: ModelContext?) async {', 'private func processPendingFilesHeadless(modelContainer: ModelContainer?) async {')
text = text.replace("""        var contextToUse = modelContext
        if contextToUse == nil {
            if let container = try? ModelContainer(for: VaultDocument.self) {
                contextToUse = container.mainContext
            }
        }""", """        var containerToUse = modelContainer
        if containerToUse == nil {
            containerToUse = try? ModelContainer(for: VaultDocument.self)
        }""")
text = text.replace('await viewModel.syncPendingDocuments(modelContext: contextToUse)', 'await viewModel.syncPendingDocuments(modelContainer: containerToUse)')
with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/BackgroundTaskManager.swift', 'w', 'utf-8') as f:
    f.write(text)

# 3. Fix RosettaHealthApp.swift
with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/RosettaHealthApp.swift', 'r', 'utf-8') as f:
    text = f.read()
text = text.replace('registerTasks(modelContext: nil)', 'registerTasks(modelContainer: nil)')
with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/RosettaHealthApp.swift', 'w', 'utf-8') as f:
    f.write(text)

# 4. Fix ContentView.swift processPDF call
with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/ContentView.swift', 'r', 'utf-8') as f:
    text = f.read()
text = text.replace('modelContext: modelContext', 'modelContainer: modelContext.container')
with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/ContentView.swift', 'w', 'utf-8') as f:
    f.write(text)