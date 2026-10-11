import Foundation

/// 下次训练里一个动作的目标。
public struct TargetExercise: Codable, Hashable, Sendable {
    public let exerciseId: String
    public let sets: Int
    public let targetMin: Int
    public let targetMax: Int
    /// nil 表示第一次做，需要在手表上输入；自重动作为 0
    public let weightLb: Double?
    /// 上次所有组都做满了，这次加了重量
    public let suggestIncrease: Bool

    public init(exerciseId: String, sets: Int, targetMin: Int, targetMax: Int, weightLb: Double?, suggestIncrease: Bool) {
        self.exerciseId = exerciseId
        self.sets = sets
        self.targetMin = targetMin
        self.targetMax = targetMax
        self.weightLb = weightLb
        self.suggestIncrease = suggestIncrease
    }
}

public struct NextWorkout: Codable, Hashable, Sendable {
    public let templateId: String
    public let exercises: [TargetExercise]

    public init(templateId: String, exercises: [TargetExercise]) {
        self.templateId = templateId
        self.exercises = exercises
    }
}

public enum PlanEngine {
    /// 和最后一次训练交替；没有记录从 A 开始。
    public static func nextTemplateId(history: [HistoryWorkout]) -> String {
        let last = history.max { $0.date < $1.date }
        return last?.templateId == "A" ? "B" : "A"
    }

    public static func next(catalog: Catalog, history: [HistoryWorkout]) -> NextWorkout {
        let templateId = nextTemplateId(history: history)
        let items = catalog.template(templateId)?.exercises ?? []
        let newestFirst = history.sorted { $0.date > $1.date }
        let targets = items.compactMap { item -> TargetExercise? in
            guard let exercise = catalog.exercise(item.exerciseId) else { return nil }
            return target(for: item, exercise: exercise, newestFirst: newestFirst)
        }
        return NextWorkout(templateId: templateId, exercises: targets)
    }

    static func target(for item: PlanItem, exercise: Exercise, newestFirst: [HistoryWorkout]) -> TargetExercise {
        func make(_ weight: Double?, increase: Bool = false) -> TargetExercise {
            TargetExercise(
                exerciseId: item.exerciseId,
                sets: item.sets,
                targetMin: item.targetMin,
                targetMax: item.targetMax,
                weightLb: weight,
                suggestIncrease: increase
            )
        }

        guard exercise.isWeighted else { return make(0) }

        let lastSets = newestFirst.lazy
            .map { $0.sets.filter { $0.exerciseId == item.exerciseId } }
            .first { !$0.isEmpty }
        guard let lastSets, let lastWeight = lastSets.map(\.weightLb).max() else { return make(nil) }

        let completedAll = lastSets.count >= item.sets && lastSets.allSatisfy { $0.value >= item.targetMax }
        return completedAll ? make(lastWeight + exercise.increment, increase: true) : make(lastWeight)
    }
}

extension NextWorkout {
    /// 每组按 45 秒估算
    static let secondsPerSet: TimeInterval = 45

    public var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets }
    }

    public func estimatedDuration(restSeconds: Int) -> TimeInterval {
        guard totalSets > 0 else { return 0 }
        return TimeInterval(totalSets) * Self.secondsPerSet + TimeInterval((totalSets - 1) * restSeconds)
    }
}
