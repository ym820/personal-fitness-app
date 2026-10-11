import Foundation

/// iPhone → 手表：下次训练的内容。用 `updateApplicationContext` 发送。
/// 动作名称等静态数据手表自己从 Catalog 读。
public struct WatchPlan: Codable, Hashable, Sendable {
    public let workout: NextWorkout
    public let restSeconds: Int
    public let generatedAt: Date

    public init(workout: NextWorkout, restSeconds: Int, generatedAt: Date) {
        self.workout = workout
        self.restSeconds = restSeconds
        self.generatedAt = generatedAt
    }

    public static func make(catalog: Catalog, history: [HistoryWorkout], now: Date = Date()) -> WatchPlan {
        WatchPlan(
            workout: PlanEngine.next(catalog: catalog, history: history),
            restSeconds: catalog.plan.restSeconds,
            generatedAt: now
        )
    }
}

/// 手表 → iPhone：一次完成的训练。用 `transferUserInfo` 发送，iPhone 按 `id` 去重。
public struct CompletedWorkout: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let templateId: String
    public let startDate: Date
    public let endDate: Date
    public let sets: [HistorySet]

    public init(id: UUID = UUID(), templateId: String, startDate: Date, endDate: Date, sets: [HistorySet]) {
        self.id = id
        self.templateId = templateId
        self.startDate = startDate
        self.endDate = endDate
        self.sets = sets
    }

    public var history: HistoryWorkout {
        HistoryWorkout(date: startDate, templateId: templateId, sets: sets)
    }
}

/// WatchConnectivity 字典里只放 JSON 编码后的 `Data`。
public enum MessageCodec {
    public static let planKey = "plan"
    public static let workoutKey = "workout"

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
