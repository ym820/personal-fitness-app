import SwiftUI
import SwiftData
import FitnessCore

struct TodayView: View {
    @Environment(PhoneSync.self) private var sync
    @Query(sort: \WorkoutLog.startDate, order: .reverse) private var logs: [WorkoutLog]
    private let catalog = Catalog.bundled

    var body: some View {
        NavigationStack {
            List {
                if let plan = sync.plan {
                    Section {
                        PlanHeader(plan: plan, lastLog: logs.first)
                    }

                    Section {
                        ForEach(plan.workout.exercises, id: \.exerciseId) { target in
                            if let exercise = catalog.exercise(target.exerciseId) {
                                NavigationLink(value: exercise) {
                                    TargetRow(exercise: exercise, target: target)
                                }
                            }
                        }
                    } header: {
                        Text("动作")
                    } footer: {
                        Text("每组之间休息 \(plan.restSeconds) 秒。所有组都做到最高次数，下次会自动加重。")
                    }
                }

                if !sync.isWatchAppInstalled {
                    Section {
                        Label("手表上还没装好 app，装好后训练计划会自动同步过去。", systemImage: "applewatch.slash")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("今天")
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
        }
    }
}

/// 今天页最上面：下次练什么、要多久、上次是哪天
private struct PlanHeader: View {
    let plan: WatchPlan
    let lastLog: WorkoutLog?
    private let catalog = Catalog.bundled

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("下次训练")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(catalog.template(plan.workout.templateId)?.nameZh ?? plan.workout.templateId)
                .font(.largeTitle.bold())
            Text("\(plan.workout.exercises.count) 个动作 · \(plan.workout.totalSets) 组 · \(Format.approxMinutes(plan.workout.estimatedDuration(restSeconds: plan.restSeconds)))")
                .font(.subheadline)
            Group {
                if let lastLog {
                    Text("上次：\(lastLog.startDate.formatted(.dateTime.month().day().weekday())) \(catalog.template(lastLog.templateId)?.nameZh ?? lastLog.templateId)")
                } else {
                    Text("第一次训练，在手表上打开「健身」开始")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct TargetRow: View {
    let exercise: Exercise
    let target: TargetExercise

    var body: some View {
        HStack(spacing: 12) {
            ExerciseThumbnail(exercise: exercise)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.nameZh).font(.headline)
                Text(exercise.nameEn).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text("\(target.sets) × \(Format.target(min: target.targetMin, max: target.targetMax, unit: exercise.unit))")
                        .monospacedDigit()
                    weightTag
                }
                .font(.footnote)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var weightTag: some View {
        if !exercise.isWeighted {
            EmptyView()
        } else if let weight = target.weightLb {
            Text(Format.weight(weight)).monospacedDigit()
            if target.suggestIncrease {
                Tag(text: "加重", systemImage: "arrow.up", color: .green)
            }
        } else {
            Tag(text: "首次，手表上输入重量", systemImage: nil, color: .orange)
        }
    }
}

/// 小标签：颜色放在实底上，文字保持清晰
struct Tag: View {
    let text: String
    let systemImage: String?
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15), in: Capsule())
    }
}
