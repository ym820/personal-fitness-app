import Foundation
import Observation
import FitnessCore

/// 手表上一次训练的总控：把 WorkoutFlow（流程）、WorkoutManager（健康）和 WatchSync（同步）串起来。
@MainActor
@Observable
final class TrainingModel {
    let sync: WatchSync
    let health: WorkoutManager

    private(set) var flow: WorkoutFlow?
    /// 休息结束的时间点。用时间点而不是倒数，app 退到后台再回来也准。
    private(set) var restEnd: Date?
    private(set) var startDate: Date?
    /// 结束后等健康数据保存完才有值
    private(set) var summary: WorkoutManager.Summary?

    init(sync: WatchSync = WatchSync(), health: WorkoutManager = WorkoutManager()) {
        self.sync = sync
        self.health = health
    }

    func begin(_ plan: WatchPlan) {
        flow = WorkoutFlow(workout: plan.workout, restSeconds: plan.restSeconds)
        startDate = Date()
        restEnd = nil
        summary = nil
        Task { await health.start() }
    }

    func completeSet(value: Int, weightLb: Double) {
        guard var flow else { return }
        flow.completeSet(value: value, weightLb: weightLb)
        self.flow = flow
        switch flow.phase {
        case .resting:
            restEnd = Date().addingTimeInterval(TimeInterval(flow.restSeconds))
        case .finished:
            finish()
        case .doingSet:
            break
        }
    }

    func finishRest() {
        flow?.finishRest()
        restEnd = nil
    }

    func extendRest(by seconds: TimeInterval) {
        restEnd = restEnd?.addingTimeInterval(seconds)
    }

    func endEarly() {
        flow?.endEarly()
        restEnd = nil
        finish()
    }

    /// 结束页点「完成」，回到开始页
    func close() {
        flow = nil
        summary = nil
        startDate = nil
    }

    private func finish() {
        guard let flow, let startDate else { return }
        // 先把记录发出去（同时存到本地），不等健康数据
        if !flow.completedSets.isEmpty {
            sync.send(CompletedWorkout(
                templateId: flow.workout.templateId,
                startDate: startDate,
                endDate: Date(),
                sets: flow.completedSets
            ))
        }
        Task {
            summary = await health.end()
        }
    }
}
