import Foundation
import BackgroundTasks
import OSLog
import UserNotifications
import SwiftData

@available(iOS 26.0, *)
public final class BackgroundTaskManager {
    public static let shared = BackgroundTaskManager()
    private let logger = Logger(subsystem: "dev.alexmaina.rosettahealth", category: "BGTasks")
    
    // Deve combaciare con l'identificativo in Info.plist (BGTaskSchedulerPermittedIdentifiers)
    public let processingTaskIdentifier = "dev.alexmaina.rosettahealth.processPDFs"
    
    private init() {}
    
    public func registerTasks(modelContainer: ModelContainer? = nil) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingTaskIdentifier, using: nil) { task in
            guard let bgTask = task as? BGProcessingTask else { return }
            self.handleProcessingTask(task: bgTask, modelContainer: modelContainer)
        }
    }
    
    public func scheduleNextProcessing() {
        let request = BGProcessingTaskRequest(identifier: processingTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true // Preferibilmente di notte quando è in carica
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Task di background schedulato con successo.")
        } catch {
            logger.error("Impossibile schedulare il task di background: \(error.localizedDescription)")
        }
    }
    
    private func handleProcessingTask(task: BGProcessingTask, modelContainer: ModelContainer?) {
        // Riprogramma per la prossima volta
        scheduleNextProcessing()
        
        // Se il sistema cancella il task (es. l'utente inizia a usare pesantemente il telefono)
        task.expirationHandler = {
            self.logger.warning("Il task di background sta per scadere!")
            // Qui dovremmo interrompere il processing, ma per semplicità lo lasciamo failare
        }
        
        Task {
            // Eseguiamo il sync usando l'AppViewModel in modo "headless"
            // Nota: AppViewModel è @MainActor, quindi potremmo dover gestire il context
            // Creiamo un'istanza headless per processare i file
            await processPendingFilesHeadless(modelContainer: modelContainer)
            task.setTaskCompleted(success: true)
        }
    }
    
    @MainActor
    private func processPendingFilesHeadless(modelContainer: ModelContainer?) async {
        let viewModel = AppViewModel()
        
        var containerToUse = modelContainer
        if containerToUse == nil {
            containerToUse = try? ModelContainer(for: VaultDocument.self)
        }
        
        // Silenzia l'output visivo e lancia il parsing
        await viewModel.syncPendingDocuments(modelContainer: containerToUse)
        
        // Invia notifica all'utente se ha processato qualcosa
        if viewModel.syncedSamplesCount > 0 || !viewModel.extractedObservations.isEmpty {
            sendWakeupNotification(title: "Referti Analizzati", body: "I PDF in coda sono stati salvati nel Vault e in Salute.")
        }
    }
    
    private func sendWakeupNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
