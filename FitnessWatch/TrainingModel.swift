import Foundation
import Observation
import WatchKit
import FitnessCore

/// 手表上一次训练的总控：把 WorkoutFlow（流程）、WorkoutManager（健康）和 WatchSync（同步）串起来。
@MainActor
@Observable
final class TrainingModel {
    let sync: WatchSync
    let health: WorkoutManager

    private(set) var flow: WorkoutFlow?
    /// 休息开始和结束的时间点。用时间点而不是倒数，app 退到后台再回来也准。
    private(set) var restStart: Date?
    private(set) var restEnd: Date?
    private(set) var startDate: Date?
    /// 结束后等健康数据保存完才有值
    private(set) var summary: WorkoutManager.Summary?

    init() {
        self.sync = WatchSync()
        self.health = WorkoutManager()
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
            // 一次训练要点十几次，用最轻的触感确认，不抢注意力
            WKInterfaceDevice.current().play(.click)
            let now = Date()
            restStart = now
            restEnd = now.addingTimeInterval(TimeInterval(flow.restSeconds))
        case .finished:
            finish()
        case .doingSet:
            break
        }
    }

    func finishRest() {
        flow?.finishRest()
        restStart = nil
        restEnd = nil
    }

    func extendRest(by seconds: TimeInterval) {
        restEnd = restEnd?.addingTimeInterval(seconds)
    }

    func endEarly() {
        flow?.endEarly()
        restStart = nil
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
        WKInterfaceDevice.current().play(.success)
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
