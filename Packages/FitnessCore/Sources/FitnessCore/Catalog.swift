import Foundation

/// 打包在 app 里的静态数据：动作库和新手计划。
public struct Catalog: Sendable {
    public let exercises: [Exercise]
    public let plan: Plan
    private let exercisesById: [String: Exercise]

    public init(exercises: [Exercise], plan: Plan) {
        self.exercises = exercises
        self.plan = plan
        self.exercisesById = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func exercise(_ id: String) -> Exercise? {
        exercisesById[id]
    }

    public func template(_ id: String) -> WorkoutTemplate? {
        plan.templates.first { $0.id == id }
    }

    public static func decode(exercisesJSON: Data, planJSON: Data) throws -> Catalog {
        let decoder = JSONDecoder()
        return Catalog(
            exercises: try decoder.decode([Exercise].self, from: exercisesJSON),
            plan: try decoder.decode(Plan.self, from: planJSON)
        )
    }

    /// FitnessCore 自带的数据。JSON 打包在 app 里，读取失败说明打包出了问题，直接崩溃。
    public static let bundled: Catalog = {
        do {
            return try load()
        } catch {
            fatalError("读取 exercises.json / plan.json 失败：\(error)")
        }
    }()

    /// 读取 FitnessCore 自带的 exercises.json 和 plan.json。
    public static func load() throws -> Catalog {
        try load(bundle: .module)
    }

    public static func load(bundle: Bundle) throws -> Catalog {
        try decode(
            exercisesJSON: try resource("exercises", in: bundle),
            planJSON: try resource("plan", in: bundle)
        )
    }

    private static func resource(_ name: String, in bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(name).json"])
        }
        return try Data(contentsOf: url)
    }
}
