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
