import Testing
@testable import FitnessCore

@Suite struct WorkoutFlowTests {
    let workout = NextWorkout(templateId: "A", exercises: [
        TargetExercise(exerciseId: "Leg_Press", sets: 3, targetMin: 8, targetMax: 12, weightLb: 100, suggestIncrease: false),
        TargetExercise(exerciseId: "Leverage_Chest_Press", sets: 2, targetMin: 8, targetMax: 12, weightLb: nil, suggestIncrease: false),
        TargetExercise(exerciseId: "Plank", sets: 1, targetMin: 20, targetMax: 40, weightLb: 0, suggestIncrease: false),
    ])

    func pos(_ e: Int, _ s: Int) -> WorkoutFlow.Position {
        WorkoutFlow.Position(exerciseIndex: e, setIndex: s)
    }

    @Test func startsWithFirstSet() {
        let flow = WorkoutFlow(workout: workout, restSeconds: 90)
        #expect(flow.phase == .doingSet(pos(0, 0)))
        #expect(flow.current?.exerciseId == "Leg_Press")
        #expect(flow.defaultValue() == 12)
        #expect(flow.defaultWeight() == 100)
        #expect(flow.totalSets == 6)
        #expect(flow.completedSets.isEmpty)
    }

    @Test func emptyWorkoutIsFinished() {
        let flow = WorkoutFlow(workout: NextWorkout(templateId: "A", exercises: []), restSeconds: 90)
        #expect(flow.phase == .finished)
        #expect(flow.current == nil)
    }

    @Test func completingSetGoesToRestThenNextSet() {
        var flow = WorkoutFlow(workout: workout, restSeconds: 90)
        flow.completeSet(value: 10, weightLb: 100)
        #expect(flow.phase == .resting(next: pos(0, 1)))
        #expect(flow.current?.exerciseId == "Leg_Press")
        flow.finishRest()
        #expect(flow.phase == .doingSet(pos(0, 1)))
        #expect(flow.completedSets == [HistorySet(exerciseId: "Leg_Press", setIndex: 0, value: 10, weightLb: 100)])
    }

    @Test func walksWholeWorkout() {
        var flow = WorkoutFlow(workout: workout, restSeconds: 90)
        var rests = 0
        var guardCount = 0
        while flow.phase != .finished && guardCount < 100 {
            guardCount += 1
            switch flow.phase {
            case .doingSet:
                flow.completeSet(value: flow.defaultValue(), weightLb: flow.defaultWeight() ?? 50)
            case .resting:
                rests += 1
                flow.finishRest()
            case .finished:
                break
            }
        }
        #expect(flow.phase == .finished)
        #expect(flow.completedSets.count == 6)
        #expect(rests == 5)
        #expect(flow.completedSets.map(\.exerciseId) == [
            "Leg_Press", "Leg_Press", "Leg_Press", "Leverage_Chest_Press", "Leverage_Chest_Press", "Plank",
        ])
        #expect(flow.completedSets.map(\.setIndex) == [0, 1, 2, 0, 1, 0])
    }

    @Test func restBeforeNewExercisePointsToIt() {
        var flow = WorkoutFlow(workout: workout, restSeconds: 90)
        for _ in 0..<3 {
            flow.completeSet(value: 12, weightLb: 100)
            if case .resting = flow.phase { flow.finishRest() }
        }
        #expect(flow.phase == .doingSet(pos(1, 0)))
        #expect(flow.current?.exerciseId == "Leverage_Chest_Press")
    }

    @Test func changedWeightCarriesToNextSetOfSameExercise() {
        var flow = WorkoutFlow(workout: workout, restSeconds: 90)
        flow.completeSet(value: 12, weightLb: 90)
        flow.finishRest()
        #expect(flow.defaultWeight() == 90)
    }

    @Test func firstTimeExerciseHasNoDefaultWeightUntilEntered() {
        var flow = WorkoutFlow(workout: workout, restSeconds: 90)
        for _ in 0..<3 {
            flow.completeSet(value: 12, weightLb: 100)
            flow.finishRest()
        }
        #expect(flow.defaultWeight() == nil)
        flow.completeSet(value: 10, weightLb: 40)
        flow.finishRest()
        #expect(flow.defaultWeight() == 40)
    }

    @Test func lastSetFinishesWithoutRest() {
        let single = NextWorkout(templateId: "B", exercises: [
            TargetExercise(exerciseId: "Crunches", sets: 1, targetMin: 8, targetMax: 12, weightLb: 0, suggestIncrease: false),
        ])
        var flow = WorkoutFlow(workout: single, restSeconds: 90)
        flow.completeSet(value: 12, weightLb: 0)
        #expect(flow.phase == .finished)
    }

    @Test func endEarlyKeepsCompletedSets() {
        var flow = WorkoutFlow(workout: workout, restSeconds: 90)
        flow.completeSet(value: 12, weightLb: 100)
        flow.endEarly()
        #expect(flow.phase == .finished)
        #expect(flow.completedSets.count == 1)
    }

    @Test func actionsInWrongPhaseAreIgnored() {
        var flow = WorkoutFlow(workout: workout, restSeconds: 90)
        flow.finishRest()
        #expect(flow.phase == .doingSet(pos(0, 0)))
        flow.completeSet(value: 12, weightLb: 100)
        flow.completeSet(value: 12, weightLb: 100)
        #expect(flow.completedSets.count == 1)
        flow.endEarly()
        flow.completeSet(value: 12, weightLb: 100)
        #expect(flow.completedSets.count == 1)
    }
}
