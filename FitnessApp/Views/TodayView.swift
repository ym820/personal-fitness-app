import SwiftUI
import FitnessCore

struct TodayView: View {
    @Environment(PhoneSync.self) private var sync
    private let catalog = Catalog.bundled

    var body: some View {
        NavigationStack {
            List {
                if let plan = sync.plan {
                    Section {
                        ForEach(plan.workout.exercises, id: \.exerciseId) { target in
                            if let exercise = catalog.exercise(target.exerciseId) {
                                NavigationLink(value: exercise) {
                                    TargetRow(exercise: exercise, target: target)
                                }
                            }
                        }
                    } header: {
                        Text("每组之间休息 \(plan.restSeconds) 秒")
                    } footer: {
                        Text("在手表上打开「健身」开始训练。所有组都做到最高次数，下次会自动加重。")
                    }
                }

                if !sync.isWatchAppInstalled {
                    Section {
                        Label("手表上还没装好 app，训练计划会在装好后自动同步过去。", systemImage: "applewatch.slash")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(title)
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
        }
    }

    private var title: String {
        guard let id = sync.plan?.workout.templateId else { return "今天" }
        return "下次：" + (catalog.template(id)?.nameZh ?? id)
    }
}

private struct TargetRow: View {
    let exercise: Exercise
    let target: TargetExercise

    var body: some View {
        HStack(spacing: 12) {
            ExerciseThumbnail(exercise: exercise)
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.nameZh).font(.headline)
                Text(exercise.nameEn).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text("\(target.sets) 组 × \(Format.target(min: target.targetMin, max: target.targetMax, unit: exercise.unit))")
                    weightText
                }
                .font(.footnote)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var weightText: some View {
        if !exercise.isWeighted {
            EmptyView()
        } else if let weight = target.weightLb {
            HStack(spacing: 2) {
                Text(Format.weight(weight))
                if target.suggestIncrease {
                    Label("加重", systemImage: "arrow.up")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.green)
                }
            }
        } else {
            Text("首次，在手表上输入重量").foregroundStyle(.orange)
        }
    }
}
