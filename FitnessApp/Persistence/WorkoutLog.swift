import Foundation
import SwiftData
import FitnessCore

@Model
final class WorkoutLog {
    @Attribute(.unique) var id: UUID
    var templateId: String
    var startDate: Date
    var endDate: Date
    @Relationship(deleteRule: .cascade, inverse: \SetLog.workout)
    var sets: [SetLog] = []

    init(id: UUID, templateId: String, startDate: Date, endDate: Date) {
        self.id = id
        self.templateId = templateId
        self.startDate = startDate
        self.endDate = endDate
    }

    /// SwiftData 不保证关系数组的顺序，按 `order` 排好再用
    var orderedSets: [SetLog] {
        sets.sorted { $0.order < $1.order }
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var history: HistoryWorkout {
        HistoryWorkout(
            date: startDate,
            templateId: templateId,
            sets: orderedSets.map {
                HistorySet(exerciseId: $0.exerciseId, setIndex: $0.setIndex, value: $0.value, weightLb: $0.weightLb)
            }
        )
    }
}

@Model
final class SetLog {
    /// 在整次训练里的顺序
    var order: Int
    var exerciseId: String
    var setIndex: Int
    /// 次数或秒数
    var value: Int
    var weightLb: Double
    var workout: WorkoutLog?

    init(order: Int, exerciseId: String, setIndex: Int, value: Int, weightLb: Double) {
        self.order = order
        self.exerciseId = exerciseId
        self.setIndex = setIndex
        self.value = value
        self.weightLb = weightLb
    }
}

extension ModelContext {
    /// 保存手表发来的训练。同一个 id 已经存过就跳过（transferUserInfo 可能重复送达）。
    /// 返回是否新存了一条。
    @discardableResult
    func saveWorkout(_ completed: CompletedWorkout) throws -> Bool {
        let id = completed.id
        let existing = FetchDescriptor<WorkoutLog>(predicate: #Predicate { $0.id == id })
        guard try fetchCount(existing) == 0 else { return false }

        let log = WorkoutLog(
            id: completed.id,
            templateId: completed.templateId,
            startDate: completed.startDate,
            endDate: completed.endDate
        )
        insert(log)
        for (order, set) in completed.sets.enumerated() {
            let setLog = SetLog(
                order: order,
                exerciseId: set.exerciseId,
                setIndex: set.setIndex,
                value: set.value,
                weightLb: set.weightLb
            )
            insert(setLog)
            setLog.workout = log
        }
        try save()
        return true
    }

    func allHistory() throws -> [HistoryWorkout] {
        try fetch(FetchDescriptor<WorkoutLog>()).map(\.history)
    }
}
