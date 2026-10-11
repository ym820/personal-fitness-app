import SwiftUI
import FitnessCore

struct StartView: View {
    let plan: WatchPlan
    @Environment(TrainingModel.self) private var model
    private let catalog = Catalog.bundled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(catalog.template(plan.workout.templateId)?.nameZh ?? plan.workout.templateId)
                        .font(.title2.bold())
                    Text("\(plan.workout.exercises.count) 个动作 · \(plan.workout.totalSets) 组 · \(Format.approxMinutes(plan.workout.estimatedDuration(restSeconds: plan.restSeconds)))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("开始") {
                    model.begin(plan)
                }
                .buttonStyle(.borderedProminent)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(plan.workout.exercises.enumerated()), id: \.element.exerciseId) { index, target in
                        if let exercise = catalog.exercise(target.exerciseId) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.footnote.bold())
                                    .foregroundStyle(.green)
                                    .monospacedDigit()
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(exercise.nameZh).font(.headline)
                                    Text(exercise.nameEn).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
