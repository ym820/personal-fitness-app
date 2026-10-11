import SwiftUI

@main
struct FitnessWatchApp: App {
    @State private var model = TrainingModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { model.sync.start() }
        }
    }
}
