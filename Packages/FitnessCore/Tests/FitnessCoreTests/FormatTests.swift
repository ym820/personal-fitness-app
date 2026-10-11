import Testing
@testable import FitnessCore

@Suite struct FormatTests {
    @Test func weight() {
        #expect(Format.weight(100) == "100 lb")
        #expect(Format.weight(102.5) == "102.5 lb")
        #expect(Format.weight(0) == "0 lb")
    }

    @Test func valueAndTarget() {
        #expect(Format.value(12, unit: .reps) == "12 次")
        #expect(Format.value(30, unit: .seconds) == "30 秒")
        #expect(Format.target(min: 8, max: 12, unit: .reps) == "8-12 次")
        #expect(Format.target(min: 20, max: 40, unit: .seconds) == "20-40 秒")
    }

    @Test func duration() {
        #expect(Format.duration(59) == "0:59")
        #expect(Format.duration(65) == "1:05")
        #expect(Format.duration(3_725) == "1:02:05")
    }

    @Test func bodyParts() {
        #expect(BodyPart.allCases.map(\.rawValue) == ["legs", "chest", "back", "shoulders", "arms", "core"])
        #expect(BodyPart.legs.nameZh == "腿和臀")
    }

    @Test func everyBundledExerciseHasKnownBodyPartAndMuscleNames() throws {
        for exercise in Catalog.bundled.exercises {
            #expect(BodyPart(rawValue: exercise.bodyPart) != nil, "\(exercise.id)")
            for muscle in exercise.primaryMuscles {
                #expect(Format.muscleZh(muscle) != muscle, "\(muscle)")
            }
        }
    }
}

@Suite struct EstimateTests {
    @Test func estimatedDurationCountsSetsAndRests() {
        let workout = NextWorkout(templateId: "A", exercises: [
            TargetExercise(exerciseId: "X", sets: 3, targetMin: 8, targetMax: 12, weightLb: nil, suggestIncrease: false),
            TargetExercise(exerciseId: "Y", sets: 2, targetMin: 8, targetMax: 12, weightLb: nil, suggestIncrease: false),
        ])
        #expect(workout.totalSets == 5)
        // 5 组 × 45 秒 + 4 次休息 × 90 秒
        #expect(workout.estimatedDuration(restSeconds: 90) == 585)
        #expect(NextWorkout(templateId: "A", exercises: []).estimatedDuration(restSeconds: 90) == 0)
    }

    @Test func approxMinutesRoundsToFive() {
        #expect(Format.approxMinutes(1_935) == "约 30 分钟")
        #expect(Format.approxMinutes(585) == "约 10 分钟")
        #expect(Format.approxMinutes(60) == "约 5 分钟")
    }

    @Test func bundledPlanIsAboutHalfAnHour() throws {
        let next = PlanEngine.next(catalog: .bundled, history: [])
        #expect(Format.approxMinutes(next.estimatedDuration(restSeconds: 90)) == "约 30 分钟")
    }
}
