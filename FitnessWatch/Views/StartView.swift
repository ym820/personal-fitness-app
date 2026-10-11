import SwiftUI
import FitnessCore

struct StartView: View {
    let plan: WatchPlan
    @Environment(TrainingModel.self) private var model
    private let catalog = Catalog.bundled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(catalog.template(plan.workout.templateId)?.nameZh ?? plan.workout.templateId)
                    .font(.title2.bold())
                Button("开始") {
                    model.begin(plan)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                ForEach(plan.workout.exercises, id: \.exerciseId) { target in
                    if let exercise = catalog.exercise(target.exerciseId) {
                        VStack(alignment: .leading) {
                            Text(exercise.nameZh).font(.headline)
                            Text(exercise.nameEn).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
