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
                    VStack(spacing: 8) {
                        VStack(spacing: 1) {
                            Text(exercise.nameZh)
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(exercise.nameEn)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text("动作 \(position.exerciseIndex + 1)/\(flow.workout.exercises.count) · 第 \(position.setIndex + 1)/\(target.sets) 组")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        // 数字跟着表冠立刻变，不加动画：直接操作必须零延迟
                        HStack(spacing: 6) {
                            NumberBox(
                                text: "\(Int(value))",
                                unit: Format.unitZh(exercise.unit),
                                isFocused: focus == .value
                            )
                            .focusable()
                            .focused($focus, equals: .value)
                            .digitalCrownRotation($value, from: 0, through: 300, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                            .onTapGesture { focus = .value }

                            if exercise.isWeighted {
                                NumberBox(
                                    text: Format.number(weight),
                                    unit: "lb",
                                    isFocused: focus == .weight
                                )
                                .focusable()
                                .focused($focus, equals: .weight)
                                .digitalCrownRotation($weight, from: 0, through: 1000, by: 2.5, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                                .onTapGesture { focus = .weight }
                            }
                        }

                        hint(target: target, exercise: exercise, position: position)
                            .font(.caption2)
                            .multilineTextAlignment(.center)

                        Button("完成") {
                            model.completeSet(value: Int(value), weightLb: exercise.isWeighted ? weight : 0)
                        }
                        .buttonStyle(.borderedProminent)
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

    /// 只显示一条最要紧的提示
    @ViewBuilder
    private func hint(target: TargetExercise, exercise: Exercise, position: WorkoutFlow.Position) -> some View {
        if exercise.isWeighted && needsWeightInput && weight == 0 {
            Text("第一次做，转表冠输入重量")
                .foregroundStyle(.orange)
        } else if target.suggestIncrease && position.setIndex == 0 {
            Label("上次全部做满，已加重", systemImage: "arrow.up")
                .foregroundStyle(.green)
        } else {
            Text("目标 \(Format.target(min: target.targetMin, max: target.targetMax, unit: exercise.unit))")
                .foregroundStyle(.secondary)
        }
    }
}

/// 一个可以用表冠调的数字。选中时填充绿色，一眼看出表冠在调哪个。
private struct NumberBox: View {
    let text: String
    let unit: String
    let isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isFocused ? Color.green.opacity(0.22) : Color.gray.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isFocused ? Color.green : Color.clear, lineWidth: 1.5)
        )
    }
}

struct HeartRateLabel: View {
    @Environment(TrainingModel.self) private var model

    var body: some View {
        if let heartRate = model.health.heartRate {
            Label("\(Int(heartRate))", systemImage: "heart.fill")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.red)
        }
    }
}
