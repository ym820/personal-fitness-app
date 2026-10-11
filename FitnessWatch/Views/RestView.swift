import SwiftUI
import WatchKit
import FitnessCore

/// 休息页：倒计时，时间到震动并自动进入下一组。
struct RestView: View {
    let flow: WorkoutFlow
    @Environment(TrainingModel.self) private var model
    @State private var showEndConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("休息").font(.headline)
                if let restEnd = model.restEnd {
                    Text(timerInterval: Date()...max(restEnd, Date()), countsDown: true)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                }
                if let target = flow.current, let position = flow.position,
                   let exercise = Catalog.bundled.exercise(target.exerciseId) {
                    Text("下一组：\(exercise.nameZh) 第 \(position.setIndex + 1)/\(target.sets) 组")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                HStack {
                    Button("+30 秒") { model.extendRest(by: 30) }
                    Button("跳过") { model.finishRest() }
                        .tint(.green)
                }
                Button("结束训练", role: .destructive) { showEndConfirm = true }
                    .font(.footnote)
            }
        }
        .confirmationDialog("结束训练？已完成的组会保存。", isPresented: $showEndConfirm) {
            Button("结束训练", role: .destructive) { model.endEarly() }
            Button("继续", role: .cancel) {}
        }
        .task(id: model.restEnd) {
            guard let restEnd = model.restEnd else { return }
            let remaining = restEnd.timeIntervalSinceNow
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled, model.restEnd == restEnd else { return }
            WKInterfaceDevice.current().play(.notification)
            model.finishRest()
        }
    }
}
