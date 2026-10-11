/// 手表上一次训练的流程：做组 → 休息 → 下一组 → 下一个动作 → 结束。
/// 页面只负责显示 `phase` 和调用这里的方法。
public struct WorkoutFlow: Equatable, Sendable {
    public struct Position: Hashable, Sendable {
        public let exerciseIndex: Int
        public let setIndex: Int

        public init(exerciseIndex: Int, setIndex: Int) {
            self.exerciseIndex = exerciseIndex
            self.setIndex = setIndex
        }
    }

    public enum Phase: Equatable, Sendable {
        case doingSet(Position)
        case resting(next: Position)
        case finished
    }

    public let workout: NextWorkout
    public let restSeconds: Int
    public private(set) var phase: Phase
    public private(set) var completedSets: [HistorySet] = []
    /// 本次训练里每个动作最后一次实际用的重量
    private var usedWeights: [String: Double] = [:]

    public init(workout: NextWorkout, restSeconds: Int) {
        self.workout = workout
        self.restSeconds = restSeconds
        self.phase = Self.firstPosition(in: workout).map(Phase.doingSet) ?? .finished
    }

    public var totalSets: Int {
        workout.totalSets
    }

    /// 正在做的组，或休息完要做的组
    public var position: Position? {
        switch phase {
        case .doingSet(let position), .resting(next: let position): position
        case .finished: nil
        }
    }

    public var current: TargetExercise? {
        position.map { workout.exercises[$0.exerciseIndex] }
    }

    /// 预填的次数（或秒数）
    public func defaultValue() -> Int {
        current?.targetMax ?? 0
    }

    /// 预填的重量：本次训练里这个动作上一组的重量，没有就用目标重量。nil 表示需要用户输入。
    public func defaultWeight() -> Double? {
        guard let current else { return nil }
        return usedWeights[current.exerciseId] ?? current.weightLb
    }

    public mutating func completeSet(value: Int, weightLb: Double) {
        guard case .doingSet(let position) = phase, let current else { return }
        completedSets.append(HistorySet(
            exerciseId: current.exerciseId,
            setIndex: position.setIndex,
            value: value,
            weightLb: weightLb
        ))
        usedWeights[current.exerciseId] = weightLb
        phase = nextPosition(after: position).map { .resting(next: $0) } ?? .finished
    }

    /// 休息倒计时结束或跳过休息
    public mutating func finishRest() {
        guard case .resting(let next) = phase else { return }
        phase = .doingSet(next)
    }

    public mutating func endEarly() {
        phase = .finished
    }

    private func nextPosition(after position: Position) -> Position? {
        if position.setIndex + 1 < workout.exercises[position.exerciseIndex].sets {
            return Position(exerciseIndex: position.exerciseIndex, setIndex: position.setIndex + 1)
        }
        let nextExercise = workout.exercises.indices
            .dropFirst(position.exerciseIndex + 1)
            .first { workout.exercises[$0].sets > 0 }
        return nextExercise.map { Position(exerciseIndex: $0, setIndex: 0) }
    }

    private static func firstPosition(in workout: NextWorkout) -> Position? {
        workout.exercises.firstIndex { $0.sets > 0 }.map { Position(exerciseIndex: $0, setIndex: 0) }
    }
}
