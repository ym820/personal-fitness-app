import SwiftUI
import WatchKit
import FitnessCore

/// 休息页：倒计时圆环，时间到震动并自动进入下一组。
struct RestView: View {
    let flow: WorkoutFlow
    @Environment(TrainingModel.self) private var model
    @State private var showEndConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let restStart = model.restStart, let restEnd = model.restEnd {
                    RestRing(start: restStart, end: restEnd)
                        .frame(width: 110, height: 110)
                }

                if let target = flow.current, let position = flow.position,
                   let exercise = Catalog.bundled.exercise(target.exerciseId) {
                    VStack(spacing: 0) {
                        Text("下一组")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(exercise.nameZh) 第 \(position.setIndex + 1)/\(target.sets) 组")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                }

                HStack {
                    Button("+30 秒") { model.extendRest(by: 30) }
                    Button("跳过") { model.finishRest() }
                        .buttonStyle(.borderedProminent)
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
            // 用户这时可能没在看表，用最明显的震动提醒
            WKInterfaceDevice.current().play(.notification)
            model.finishRest()
        }
    }
}

/// 剩余时间圆环。每秒更新一次，两次之间用匀速动画连起来（持续运动用 linear）。
private struct RestRing: View {
    let start: Date
    let end: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let total = max(1, end.timeIntervalSince(start))
            let remaining = max(0, end.timeIntervalSince(context.date))
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: remaining / total)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)
                VStack(spacing: 0) {
                    Text(Format.duration(remaining.rounded(.up)))
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                    Text("休息")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
