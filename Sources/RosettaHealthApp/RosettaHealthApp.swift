import SwiftUI

@main
@available(iOS 26.0, *)
struct RosettaHealthApp: App {
    
    init() {
        BackgroundTaskManager.shared.registerTasks(modelContainer: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
        }
    }
}
