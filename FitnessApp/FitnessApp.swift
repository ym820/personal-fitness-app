import SwiftUI
import SwiftData
import FitnessCore

@main
struct FitnessApp: App {
    let container: ModelContainer
    @State private var sync: PhoneSync

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: WorkoutLog.self, SetLog.self)
        } catch {
            fatalError("创建数据库失败：\(error)")
        }
        self.container = container
        _sync = State(initialValue: PhoneSync(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sync)
                .tint(.green)
                .task { sync.start() }
        }
        .modelContainer(container)
    }
}
