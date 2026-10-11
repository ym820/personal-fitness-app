import Foundation
import HealthKit
import Observation

/// 用 HKWorkoutSession 记录一次「传统力量训练」：实时心率、卡路里，结束后保存到健康 app。
/// 没有权限或出错时不影响训练本身，只是不记录到健康。
@MainActor
@Observable
final class WorkoutManager: NSObject {
    struct Summary {
        let duration: TimeInterval
        let averageHeartRate: Double?
        let activeEnergy: Double?
        let savedToHealth: Bool
    }

    private(set) var heartRate: Double?
    private(set) var activeEnergy: Double?
    private(set) var isRecording = false

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var startDate = Date()

    nonisolated private static var heartRateUnit: HKUnit { HKUnit.count().unitDivided(by: .minute()) }

    func start() async {
        startDate = Date()
        heartRate = nil
        activeEnergy = nil
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
        ]
        do {
            try await healthStore.requestAuthorization(toShare: share, read: read)
        } catch {
            print("健康授权失败：\(error)")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)
            isRecording = true
        } catch {
            print("开始健康训练失败：\(error)")
            reset()
        }
    }

    func end() async -> Summary {
        let endDate = Date()
        let duration = endDate.timeIntervalSince(startDate)
        guard isRecording, let session, let builder else {
            reset()
            return Summary(duration: duration, averageHeartRate: nil, activeEnergy: nil, savedToHealth: false)
        }

        session.end()
        var saved = false
        do {
            try await builder.endCollection(at: endDate)
            saved = try await builder.finishWorkout() != nil
        } catch {
            print("保存健康训练失败：\(error)")
        }

        let summary = Summary(
            duration: duration,
            averageHeartRate: builder.statistics(for: HKQuantityType(.heartRate))?
                .averageQuantity()?.doubleValue(for: Self.heartRateUnit),
            activeEnergy: builder.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie()),
            savedToHealth: saved
        )
        reset()
        return summary
    }

    private func reset() {
        session = nil
        builder = nil
        isRecording = false
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("健康训练出错：\(error)")
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heartRate = workoutBuilder.statistics(for: HKQuantityType(.heartRate))?
            .mostRecentQuantity()?.doubleValue(for: Self.heartRateUnit)
        let energy = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())
        Task { @MainActor in
            if let heartRate { self.heartRate = heartRate }
            if let energy { self.activeEnergy = energy }
        }
    }
}
