import Foundation
import Observation
import SwiftData
import WatchConnectivity
import FitnessCore

/// iPhone 端和手表的同步：
/// - 算出下次训练，用 updateApplicationContext 发给手表（手表不在线也会在下次连上时收到最新一份）
/// - 收到手表用 transferUserInfo 发回的训练，存进 SwiftData，再算下一次
@MainActor
@Observable
final class PhoneSync: NSObject {
    private(set) var plan: WatchPlan?
    private(set) var isWatchAppInstalled = false

    private let context: ModelContext
    private let catalog: Catalog
    private var started = false

    init(context: ModelContext, catalog: Catalog = .bundled) {
        self.context = context
        self.catalog = catalog
        super.init()
    }

    func start() {
        guard !started else { return }
        started = true
        refreshPlan()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// 历史有变化（新训练、删除记录）或回到前台时调用
    func refreshPlan() {
        let history = (try? context.allHistory()) ?? []
        plan = WatchPlan.make(catalog: catalog, history: history)
        sendPlan()
    }

    private func sendPlan() {
        guard let plan, WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        do {
            try session.updateApplicationContext([MessageCodec.planKey: MessageCodec.encode(plan)])
        } catch {
            print("发送计划失败：\(error)")
        }
    }

    private func receive(_ workout: CompletedWorkout) {
        do {
            try context.saveWorkout(workout)
        } catch {
            print("保存训练失败：\(error)")
        }
        refreshPlan()
    }
}

extension PhoneSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            self.isWatchAppInstalled = installed
            self.sendPlan()
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            self.isWatchAppInstalled = installed
            self.sendPlan()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // 换了一块手表，重新激活以连上新手表
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[MessageCodec.workoutKey] as? Data,
              let workout = try? MessageCodec.decode(CompletedWorkout.self, from: data) else { return }
        Task { @MainActor in
            self.receive(workout)
        }
    }
}
