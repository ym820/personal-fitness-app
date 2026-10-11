import Foundation
import Observation
import WatchConnectivity
import FitnessCore

/// 手表端和 iPhone 的同步：
/// - 接收 iPhone 用 updateApplicationContext 发来的下次训练
/// - 训练结束后用 transferUserInfo 把记录发回 iPhone（系统排队，iPhone 不在旁边也不会丢）
@MainActor
@Observable
final class WatchSync: NSObject {
    private(set) var plan: WatchPlan?

    private let pending = PendingStore()
    private var started = false

    func start() {
        guard !started, WCSession.isSupported() else { return }
        started = true
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ workout: CompletedWorkout) {
        pending.add(workout)
        transfer(workout)
    }

    private func transfer(_ workout: CompletedWorkout) {
        let session = WCSession.default
        guard session.activationState == .activated,
              let data = try? MessageCodec.encode(workout) else { return }
        session.transferUserInfo([MessageCodec.workoutKey: data])
    }

    /// 重新发送还没确认送达、也不在系统发送队列里的训练
    private func resendPending() {
        let queued = Set(WCSession.default.outstandingUserInfoTransfers.compactMap { Self.workoutId(in: $0.userInfo) })
        for workout in pending.load() where !queued.contains(workout.id) {
            transfer(workout)
        }
    }

    private func update(_ newPlan: WatchPlan) {
        if let plan, plan.generatedAt > newPlan.generatedAt { return }
        plan = newPlan
    }

    nonisolated private static func plan(in context: [String: Any]) -> WatchPlan? {
        guard let data = context[MessageCodec.planKey] as? Data else { return nil }
        return try? MessageCodec.decode(WatchPlan.self, from: data)
    }

    nonisolated private static func workoutId(in userInfo: [String: Any]) -> UUID? {
        guard let data = userInfo[MessageCodec.workoutKey] as? Data else { return nil }
        return (try? MessageCodec.decode(CompletedWorkout.self, from: data))?.id
    }
}

extension WatchSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let plan = Self.plan(in: session.receivedApplicationContext)
        Task { @MainActor in
            if let plan { self.update(plan) }
            self.resendPending()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let plan = Self.plan(in: applicationContext) else { return }
        Task { @MainActor in
            self.update(plan)
        }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        guard error == nil, let id = Self.workoutId(in: userInfoTransfer.userInfo) else { return }
        Task { @MainActor in
            self.pending.remove(id: id)
        }
    }
}
