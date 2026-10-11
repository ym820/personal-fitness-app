import SwiftUI
import FitnessCore

/// 做组页：显示动作和目标，用表冠调实际次数和重量，点「完成」。
struct SetView: View {
    let flow: WorkoutFlow
    @Environment(TrainingModel.self) private var model

    private enum Field { case value, weight }

    @State private var value: Double
    @State private var weight: Double
    @State private var showEndConfirm = false
    @FocusState private var focus: Field?
    private let needsWeightInput: Bool

    init(flow: WorkoutFlow) {
        self.flow = flow
        _value = State(initialValue: Double(flow.defaultValue()))
        _weight = State(initialValue: flow.defaultWeight() ?? 0)
        needsWeightInput = flow.defaultWeight() == nil
    }

    var body: some View {
        if let target = flow.current, let position = flow.position,
           let exercise = Catalog.bundled.exercise(target.exerciseId) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 6) {
                        VStack(spacing: 0) {
                            Text(exercise.nameZh).font(.headline).lineLimit(1)
                            Text(exercise.nameEn).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Text("第 \(position.setIndex + 1)/\(target.sets) 组 · 目标 \(Format.target(min: target.targetMin, max: target.targetMax, unit: exercise.unit))")
                            .font(.caption2)

                        HStack(spacing: 6) {
                            NumberBox(
                                title: Format.unitZh(exercise.unit),
                                text: "\(Int(value))",
                                isFocused: focus == .value
                            )
                            .focusable()
                            .focused($focus, equals: .value)
                            .digitalCrownRotation($value, from: 0, through: 300, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                            .onTapGesture { focus = .value }

                            if exercise.isWeighted {
                                NumberBox(
                                    title: "lb",
                                    text: Format.number(weight),
                                    isFocused: focus == .weight
                                )
                                .focusable()
                                .focused($focus, equals: .weight)
                                .digitalCrownRotation($weight, from: 0, through: 1000, by: 2.5, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                                .onTapGesture { focus = .weight }
                            }
                        }

                        if exercise.isWeighted && needsWeightInput && weight == 0 {
                            Text("第一次做，点重量转表冠输入")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        } else if target.suggestIncrease && position.setIndex == 0 {
                            Text("上次全部做满，已加重")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }

                        Button("完成") {
                            model.completeSet(value: Int(value), weightLb: exercise.isWeighted ? weight : 0)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("结束", systemImage: "xmark") { showEndConfirm = true }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HeartRateLabel()
                    }
                }
                .confirmationDialog("结束训练？已完成的组会保存。", isPresented: $showEndConfirm) {
                    Button("结束训练", role: .destructive) { model.endEarly() }
                    Button("继续", role: .cancel) {}
                }
                .onAppear {
                    focus = exercise.isWeighted && needsWeightInput ? .weight : .value
                }
            }
        }
    }
}

private struct NumberBox: View {
    let title: String
    let text: String
    let isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.green : Color.gray.opacity(0.4), lineWidth: isFocused ? 2 : 1)
        )
    }
}

struct HeartRateLabel: View {
    @Environment(TrainingModel.self) private var model

    var body: some View {
        if let heartRate = model.health.heartRate {
            Label("\(Int(heartRate))", systemImage: "heart.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
