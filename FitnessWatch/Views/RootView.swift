import SwiftUI
import FitnessCore

struct RootView: View {
    @Environment(TrainingModel.self) private var model

    var body: some View {
        if let flow = model.flow {
            switch flow.phase {
            case .doingSet(let position):
                SetView(flow: flow)
                    .id(position)
            case .resting:
                RestView(flow: flow)
            case .finished:
                SummaryView(setCount: flow.completedSets.count)
            }
        } else if let plan = model.sync.plan {
            StartView(plan: plan)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "iphone")
                    .font(.largeTitle)
                Text("请先在 iPhone 上打开 app")
                    .multilineTextAlignment(.center)
            }
        }
    }
}
