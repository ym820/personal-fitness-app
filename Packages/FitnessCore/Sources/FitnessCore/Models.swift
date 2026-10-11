import Foundation

public enum ExerciseUnit: String, Codable, Sendable {
    case reps
    case seconds
}

public struct Exercise: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let nameZh: String
    public let nameEn: String
    public let equipmentZh: String
    public let equipmentEn: String
    /// legs、chest、back、shoulders、arms、core
    public let bodyPart: String
    public let primaryMuscles: [String]
    /// asset catalog 里的图片名，起始和结束各一张
    public let images: [String]
    public let tipsZh: [String]
    public let unit: ExerciseUnit
    /// 每次加重的磅数，自重动作为 0
    public let increment: Double

    public var isWeighted: Bool { increment > 0 }
}

public struct PlanItem: Codable, Hashable, Sendable {
    public let exerciseId: String
    public let sets: Int
    /// 目标次数（或秒数）范围
    public let targetMin: Int
    public let targetMax: Int
}

public struct WorkoutTemplate: Codable, Identifiable, Hashable, Sendable {
    /// "A" 或 "B"
    public let id: String
    public let nameZh: String
    public let exercises: [PlanItem]
}

public struct Plan: Codable, Sendable {
    public let restSeconds: Int
    public let templates: [WorkoutTemplate]
}
