import Foundation
import Testing
@testable import FitnessCore

@Suite struct MessagesTests {
    let date = Date(timeIntervalSince1970: 1_791_000_000)

    @Test func watchPlanRoundTrips() throws {
        let plan = WatchPlan(
            workout: NextWorkout(templateId: "B", exercises: [
                TargetExercise(exerciseId: "Goblet_Squat", sets: 3, targetMin: 8, targetMax: 12, weightLb: nil, suggestIncrease: false),
                TargetExercise(exerciseId: "Seated_Cable_Rows", sets: 3, targetMin: 8, targetMax: 12, weightLb: 70, suggestIncrease: true),
            ]),
            restSeconds: 90,
            generatedAt: date
        )
        let decoded = try MessageCodec.decode(WatchPlan.self, from: MessageCodec.encode(plan))
        #expect(decoded == plan)
    }

    @Test func completedWorkoutRoundTrips() throws {
        let workout = CompletedWorkout(
            id: UUID(),
            templateId: "A",
            startDate: date,
            endDate: date.addingTimeInterval(2_700),
            sets: [HistorySet(exerciseId: "Leg_Press", setIndex: 0, value: 12, weightLb: 102.5)]
        )
        let decoded = try MessageCodec.decode(CompletedWorkout.self, from: MessageCodec.encode(workout))
        #expect(decoded == workout)
    }

    @Test func completedWorkoutConvertsToHistory() {
        let sets = [HistorySet(exerciseId: "Plank", setIndex: 0, value: 30, weightLb: 0)]
        let workout = CompletedWorkout(id: UUID(), templateId: "A", startDate: date, endDate: date, sets: sets)
        #expect(workout.history == HistoryWorkout(date: date, templateId: "A", sets: sets))
    }

    @Test func makePlanUsesEngine() throws {
        let catalog = try Catalog.load()
        let plan = WatchPlan.make(catalog: catalog, history: [], now: date)
        #expect(plan.workout.templateId == "A")
        #expect(plan.restSeconds == 90)
        #expect(plan.generatedAt == date)
    }
}
