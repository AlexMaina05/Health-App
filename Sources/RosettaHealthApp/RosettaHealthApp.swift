import SwiftUI

@main
@available(iOS 17.0, *)
struct RosettaHealthApp: App {
    
    init() {
        BackgroundTaskManager.shared.registerTasks(modelContext: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
        }
    }
}
