import SwiftUI
import FitnessCore

@main
struct FitnessWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Hello，动作库 \((try? Catalog.load())?.exercises.count ?? 0) 个")
        }
    }
}
