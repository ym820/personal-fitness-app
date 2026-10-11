import SwiftUI
import FitnessCore

struct LibraryView: View {
    @State private var query = ""
    private let catalog = Catalog.bundled

    var body: some View {
        NavigationStack {
            List {
                ForEach(BodyPart.allCases, id: \.self) { part in
                    let exercises = filtered.filter { $0.bodyPart == part.rawValue }
                    if !exercises.isEmpty {
                        Section(part.nameZh) {
                            ForEach(exercises) { exercise in
                                NavigationLink(value: exercise) {
                                    ExerciseRow(exercise: exercise)
                                }
                            }
                        }
                    }
                }

                Section {
                    // CC BY-SA 4.0 要求注明作者和协议
                    VStack(alignment: .leading, spacing: 4) {
                        Text("动作插图来自 Workout Guide，作者 Bryl Lim，基于 Everkinetic 的作品，按 CC BY-SA 4.0 协议使用。")
                        Link("github.com/bryllim/workout-guide", destination: URL(string: "https://github.com/bryllim/workout-guide")!)
                        Link("CC BY-SA 4.0 协议", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("动作库")
            .searchable(text: $query, prompt: "中文或英文名、器材")
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
    }

    private var filtered: [Exercise] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return catalog.exercises }
        return catalog.exercises.filter { exercise in
            [exercise.nameZh, exercise.nameEn, exercise.equipmentZh, exercise.equipmentEn]
                .contains { $0.localizedCaseInsensitiveContains(text) }
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            ExerciseThumbnail(exercise: exercise)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.nameZh).font(.headline)
                Text(exercise.nameEn).font(.subheadline).foregroundStyle(.secondary)
                Text(exercise.equipmentZh).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ExerciseThumbnail: View {
    let exercise: Exercise

    var body: some View {
        // 用结束姿势：多数动作的结束姿势最有辨识度（比如推起、拉到底）
        Image(exercise.images.last ?? "")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.primary)
            .padding(3)
            .frame(width: 56, height: 56)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
