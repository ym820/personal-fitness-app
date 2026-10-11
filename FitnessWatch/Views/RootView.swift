import SwiftUI
import FitnessCore

struct RootView: View {
    @Environment(TrainingModel.self) private var model

    var body: some View {
        content
            // 做组 ↔ 休息切换时短暂淡入淡出，避免画面突然跳变；不做位移，看表时不晃眼
            .animation(.easeOut(duration: 0.2), value: model.flow?.phase)
    }

    @ViewBuilder private var content: some View {
        if let flow = model.flow {
            switch flow.phase {
            case .doingSet(let position):
                SetView(flow: flow)
                    .id(position)
                    .transition(.opacity)
            case .resting:
                RestView(flow: flow)
                    .transition(.opacity)
            case .finished:
                SummaryView(setCount: flow.completedSets.count)
                    .transition(.opacity)
            }
        } else if let plan = model.sync.plan {
            StartView(plan: plan)
                .transition(.opacity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "iphone")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("请先在 iPhone 上打开 app")
                    .multilineTextAlignment(.center)
            }
        }
    }
}
