import SwiftUI
import FitnessCore

@main
struct FitnessWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Hello \(FitnessCore.version)")
        }
    }
}
