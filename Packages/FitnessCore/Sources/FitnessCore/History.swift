import Foundation

/// 完成的一组。
public struct HistorySet: Codable, Hashable, Sendable {
    public let exerciseId: String
    public let setIndex: Int
    /// 次数，或平板支撑这类动作的秒数
    public let value: Int
    public let weightLb: Double

    public init(exerciseId: String, setIndex: Int, value: Int, weightLb: Double) {
        self.exerciseId = exerciseId
        self.setIndex = setIndex
        self.value = value
        self.weightLb = weightLb
    }
}

/// 一次训练的记录，PlanEngine 的输入。iPhone 端从 SwiftData 记录转换过来。
public struct HistoryWorkout: Hashable, Sendable {
    public let date: Date
    public let templateId: String
    public let sets: [HistorySet]

    public init(date: Date, templateId: String, sets: [HistorySet]) {
        self.date = date
        self.templateId = templateId
        self.sets = sets
    }
}
