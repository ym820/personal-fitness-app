import SwiftUI

struct RootView: View {
    @Environment(PhoneSync.self) private var sync
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今天", systemImage: "figure.strengthtraining.traditional") }
            LibraryView()
                .tabItem { Label("动作库", systemImage: "books.vertical") }
            HistoryView()
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { sync.refreshPlan() }
        }
    }
}
