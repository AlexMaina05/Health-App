import SwiftUI

@main
@available(iOS 17.0, *)
struct RosettaEdgeApp: App {
    
    init() {
        BackgroundTaskManager.shared.registerTasks(modelContainer: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
        }
    }
}
