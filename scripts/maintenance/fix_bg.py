import codecs

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/BackgroundTaskManager.swift', 'r', 'utf-8') as f:
    text = f.read()

target = """        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingTaskIdentifier, using: nil) { task in
            self.handleProcessingTask(task: task as? BGProcessingTask, modelContext: modelContext)
        }"""
        
rep = """        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingTaskIdentifier, using: nil) { task in
            guard let bgTask = task as? BGProcessingTask else { return }
            self.handleProcessingTask(task: bgTask, modelContext: modelContext)
        }"""
        
text = text.replace(target, rep)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/BackgroundTaskManager.swift', 'w', 'utf-8') as f:
    f.write(text)