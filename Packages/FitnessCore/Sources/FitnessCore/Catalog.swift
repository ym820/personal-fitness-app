import Foundation

/// 打包在 app 里的静态数据：动作库和新手计划。
public struct Catalog: Sendable {
    public let exercises: [Exercise]
    public let plan: Plan
    /// 动作 id → 示范视频，来自 videos.json。没有视频的动作不在里面
    public let videosByExercise: [String: [ExerciseVideo]]
    private let exercisesById: [String: Exercise]

    public init(exercises: [Exercise], plan: Plan, videos: [String: [ExerciseVideo]] = [:]) {
        self.exercises = exercises
        self.plan = plan
        self.videosByExercise = videos
        self.exercisesById = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func exercise(_ id: String) -> Exercise? {
        exercisesById[id]
    }

    public func videos(for exerciseId: String) -> [ExerciseVideo] {
        videosByExercise[exerciseId] ?? []
    }

    public func template(_ id: String) -> WorkoutTemplate? {
        plan.templates.first { $0.id == id }
    }

    public static func decode(exercisesJSON: Data, planJSON: Data, videosJSON: Data? = nil) throws -> Catalog {
        let decoder = JSONDecoder()
        return Catalog(
            exercises: try decoder.decode([Exercise].self, from: exercisesJSON),
            plan: try decoder.decode(Plan.self, from: planJSON),
            videos: try videosJSON.map { try decoder.decode([String: [ExerciseVideo]].self, from: $0) } ?? [:]
        )
    }

    /// FitnessCore 自带的数据。JSON 打包在 app 里，读取失败说明打包出了问题，直接崩溃。
    public static let bundled: Catalog = {
        do {
            return try load()
        } catch {
            fatalError("读取 exercises.json / plan.json / videos.json 失败：\(error)")
        }
    }()

    /// 读取 FitnessCore 自带的 exercises.json、plan.json 和 videos.json。
    public static func load() throws -> Catalog {
        try load(bundle: .module)
    }

    public static func load(bundle: Bundle) throws -> Catalog {
        try decode(
            exercisesJSON: try resource("exercises", in: bundle),
            planJSON: try resource("plan", in: bundle),
            videosJSON: try resource("videos", in: bundle)
        )
    }

    private static func resource(_ name: String, in bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(name).json"])
        }
        return try Data(contentsOf: url)
    }
}
