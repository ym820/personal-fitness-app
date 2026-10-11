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
        Image(exercise.images.first ?? "")
            .resizable()
            .scaledToFill()
            .frame(width: 64, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
