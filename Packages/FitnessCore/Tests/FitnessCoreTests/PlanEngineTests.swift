import Foundation
import Testing
@testable import FitnessCore

@Suite struct PlanEngineTests {
    let catalog: Catalog

    init() throws {
        catalog = try Catalog.load()
    }

    func day(_ n: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(n) * 86_400)
    }

    func workout(_ template: String, day n: Int, _ sets: [HistorySet] = []) -> HistoryWorkout {
        HistoryWorkout(date: day(n), templateId: template, sets: sets)
    }

    /// 现在的计划里没有自重动作，用一个只有卷腹的计划测自重
    func bodyweightCatalog() -> Catalog {
        let item = PlanItem(exerciseId: "Crunches", sets: 3, targetMin: 8, targetMax: 12)
        let templates = ["A", "B"].map { WorkoutTemplate(id: $0, nameZh: "训练 \($0)", exercises: [item]) }
        return Catalog(exercises: catalog.exercises, plan: Plan(restSeconds: 90, templates: templates))
    }

    func sets(_ id: String, _ values: [Int], weight: Double) -> [HistorySet] {
        values.enumerated().map { HistorySet(exerciseId: id, setIndex: $0.offset, value: $0.element, weightLb: weight) }
    }

    func target(_ next: NextWorkout, _ id: String) throws -> TargetExercise {
        try #require(next.exercises.first { $0.exerciseId == id })
    }

    // MARK: A/B 交替

    @Test func noHistoryStartsWithA() {
        #expect(PlanEngine.nextTemplateId(history: []) == "A")
    }

    @Test func alternatesAfterLastWorkout() {
        #expect(PlanEngine.nextTemplateId(history: [workout("A", day: 1)]) == "B")
        #expect(PlanEngine.nextTemplateId(history: [workout("A", day: 1), workout("B", day: 3)]) == "A")
    }

    @Test func usesLatestDateNotArrayOrder() {
        let history = [workout("B", day: 5), workout("A", day: 1), workout("B", day: 3)]
        #expect(PlanEngine.nextTemplateId(history: history) == "A")
    }

    // MARK: 目标重量

    @Test func firstTimeHasNoWeightForWeightedAndZeroForBodyweight() throws {
        let next = PlanEngine.next(catalog: catalog, history: [])
        #expect(next.templateId == "A")
        #expect(next.exercises.map(\.exerciseId) == catalog.template("A")!.exercises.map(\.exerciseId))
        #expect(try target(next, "Leg_Press").weightLb == nil)
        #expect(next.exercises.allSatisfy { !$0.suggestIncrease })
        #expect(try target(PlanEngine.next(catalog: bodyweightCatalog(), history: []), "Crunches").weightLb == 0)
    }

    @Test func copiesPlanTargets() throws {
        let next = PlanEngine.next(catalog: catalog, history: [])
        let legPress = try target(next, "Leg_Press")
        #expect(legPress.sets == 3)
        #expect(legPress.targetMin == 8)
        #expect(legPress.targetMax == 12)
        let pallof = try target(next, "Pallof_Press")
        #expect(pallof.targetMin == 8)
        #expect(pallof.targetMax == 12)
    }

    @Test func allSetsAtMaxIncreasesMachineBy10() throws {
        let history = [
            workout("A", day: 1, sets("Leg_Press", [12, 12, 12], weight: 100)),
            workout("B", day: 3),
        ]
        let legPress = try target(PlanEngine.next(catalog: catalog, history: history), "Leg_Press")
        #expect(legPress.weightLb == 110)
        #expect(legPress.suggestIncrease)
    }

    @Test func missingOneRepKeepsWeight() throws {
        let history = [
            workout("A", day: 1, sets("Leg_Press", [12, 12, 11], weight: 100)),
            workout("B", day: 3),
        ]
        let legPress = try target(PlanEngine.next(catalog: catalog, history: history), "Leg_Press")
        #expect(legPress.weightLb == 100)
        #expect(!legPress.suggestIncrease)
    }

    @Test func endingEarlyDoesNotIncrease() throws {
        let history = [
            workout("A", day: 1, sets("Leg_Press", [12, 12], weight: 100)),
            workout("B", day: 3),
        ]
        let legPress = try target(PlanEngine.next(catalog: catalog, history: history), "Leg_Press")
        #expect(legPress.weightLb == 100)
        #expect(!legPress.suggestIncrease)
    }

    @Test func dumbbellIncreasesBy5() throws {
        let history = [workout("B", day: 1, sets("Dumbbell_Bench_Press", [12, 12, 12], weight: 20))]
        let bench = try target(PlanEngine.next(catalog: catalog, history: history + [workout("A", day: 2)]), "Dumbbell_Bench_Press")
        #expect(bench.weightLb == 25)
        #expect(bench.suggestIncrease)
    }

    @Test func bodyweightNeverSuggestsIncrease() throws {
        let history = [
            workout("B", day: 1, sets("Crunches", [12, 12, 12], weight: 0)),
            workout("A", day: 3),
        ]
        let crunches = try target(PlanEngine.next(catalog: bodyweightCatalog(), history: history), "Crunches")
        #expect(crunches.weightLb == 0)
        #expect(!crunches.suggestIncrease)
    }

    @Test func usesHeaviestSetOfMostRecentWorkout() throws {
        let history = [
            workout("A", day: 1, sets("Leg_Press", [12, 12, 12], weight: 200)),
            workout("A", day: 5, [
                HistorySet(exerciseId: "Leg_Press", setIndex: 0, value: 10, weightLb: 90),
                HistorySet(exerciseId: "Leg_Press", setIndex: 1, value: 9, weightLb: 100),
                HistorySet(exerciseId: "Leg_Press", setIndex: 2, value: 8, weightLb: 100),
            ]),
            workout("B", day: 7),
        ]
        let legPress = try target(PlanEngine.next(catalog: catalog, history: history), "Leg_Press")
        #expect(legPress.weightLb == 100)
        #expect(!legPress.suggestIncrease)
    }

    @Test func otherExercisesUnaffected() throws {
        let history = [
            workout("A", day: 1, sets("Leg_Press", [12, 12, 12], weight: 100)),
            workout("B", day: 3),
        ]
        let next = PlanEngine.next(catalog: catalog, history: history)
        #expect(next.templateId == "A")
        #expect(try target(next, "Leverage_Chest_Press").weightLb == nil)
    }
}
