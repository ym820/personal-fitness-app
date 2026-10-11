import SwiftUI

@main
struct FitnessWatchApp: App {
    @State private var model = TrainingModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(.green)
                .task { model.sync.start() }
        }
    }
}
