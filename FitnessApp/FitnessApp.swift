import SwiftUI
import FitnessCore

@main
struct FitnessApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Hello \(FitnessCore.version)")
        }
    }
}
