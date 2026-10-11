import SwiftUI
import SwiftData
import FitnessCore

struct HistoryView: View {
    @Query(sort: \WorkoutLog.startDate, order: .reverse) private var logs: [WorkoutLog]
    @Environment(\.modelContext) private var context
    @Environment(PhoneSync.self) private var sync

    var body: some View {
        NavigationStack {
            List {
                ForEach(logs) { log in
                    NavigationLink(value: log) {
                        HistoryRow(log: log)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("历史")
            .navigationDestination(for: WorkoutLog.self) { WorkoutDetailView(log: $0) }
            .overlay {
                if logs.isEmpty {
                    ContentUnavailableView(
                        "还没有训练记录",
                        systemImage: "dumbbell",
                        description: Text("在手表上完成一次训练后会出现在这里")
                    )
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(logs[index])
        }
        try? context.save()
        sync.refreshPlan()
    }
}

private struct HistoryRow: View {
    let log: WorkoutLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Catalog.bundled.template(log.templateId)?.nameZh ?? log.templateId)
                .font(.headline)
            HStack {
                Text(log.startDate, format: .dateTime.month().day().weekday().hour().minute())
                Spacer()
                Text("\(log.sets.count) 组 · \(Format.duration(log.duration))")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

struct WorkoutDetailView: View {
    let log: WorkoutLog
    private let catalog = Catalog.bundled

    var body: some View {
        List {
            Section {
                LabeledContent("日期", value: log.startDate.formatted(date: .long, time: .shortened))
                LabeledContent("时长", value: Format.duration(log.duration))
            }
            ForEach(groups, id: \.exerciseId) { group in
                let exercise = catalog.exercise(group.exerciseId)
                Section {
                    ForEach(group.sets) { set in
                        HStack {
                            Text("第 \(set.setIndex + 1) 组")
                            Spacer()
                            Text(setText(set, exercise: exercise))
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text(exercise.map { "\($0.nameZh)  \($0.nameEn)" } ?? group.exerciseId)
                }
            }
        }
        .navigationTitle(catalog.template(log.templateId)?.nameZh ?? log.templateId)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 按动作分组，保持训练时的顺序
    private var groups: [(exerciseId: String, sets: [SetLog])] {
        var result: [(exerciseId: String, sets: [SetLog])] = []
        for set in log.orderedSets {
            if let index = result.firstIndex(where: { $0.exerciseId == set.exerciseId }) {
                result[index].sets.append(set)
            } else {
                result.append((set.exerciseId, [set]))
            }
        }
        return result
    }

    private func setText(_ set: SetLog, exercise: Exercise?) -> String {
        let value = Format.value(set.value, unit: exercise?.unit ?? .reps)
        guard exercise?.isWeighted ?? true else { return value }
        return "\(value) × \(Format.weight(set.weightLb))"
    }
}
