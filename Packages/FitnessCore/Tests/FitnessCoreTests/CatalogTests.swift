import Foundation
import Testing
@testable import FitnessCore

@Suite struct CatalogTests {
    let catalog: Catalog

    init() throws {
        catalog = try Catalog.load()
    }

    @Test func loadsBundledExercises() {
        #expect(catalog.exercises.count == 30)
        #expect(Set(catalog.exercises.map(\.id)).count == catalog.exercises.count)
    }

    @Test func planHasTwoTemplatesWithFiveExercises() {
        #expect(catalog.plan.restSeconds == 90)
        #expect(catalog.plan.templates.map(\.id) == ["A", "B"])
        for template in catalog.plan.templates {
            #expect(template.exercises.count == 5)
        }
    }

    @Test func everyPlanItemReferencesAKnownExercise() {
        for template in catalog.plan.templates {
            for item in template.exercises {
                #expect(catalog.exercise(item.exerciseId) != nil, "\(item.exerciseId)")
            }
        }
    }

    @Test func lookups() throws {
        let legPress = try #require(catalog.exercise("Leg_Press"))
        #expect(legPress.nameZh == "腿举")
        #expect(legPress.unit == .reps)
        #expect(legPress.isWeighted)

        let plank = try #require(catalog.exercise("Plank"))
        #expect(plank.unit == .seconds)
        #expect(!plank.isWeighted)

        #expect(catalog.template("B")?.nameZh == "训练 B")
        #expect(catalog.exercise("Nope") == nil)
        #expect(catalog.template("C") == nil)
    }

    @Test func decodesFromData() throws {
        let exercises = """
        [{"id":"X","nameZh":"测试","nameEn":"Test","equipmentZh":"无","equipmentEn":"None",
          "bodyPart":"core","primaryMuscles":[],"images":["X_0","X_1"],"tipsZh":["a"],
          "unit":"reps","increment":10}]
        """
        let plan = """
        {"restSeconds":60,"templates":[{"id":"A","nameZh":"训练 A",
          "exercises":[{"exerciseId":"X","sets":3,"targetMin":8,"targetMax":12}]}]}
        """
        let catalog = try Catalog.decode(exercisesJSON: Data(exercises.utf8), planJSON: Data(plan.utf8))
        #expect(catalog.exercise("X")?.increment == 10)
        #expect(catalog.plan.restSeconds == 60)
    }
}
