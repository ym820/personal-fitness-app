import SwiftUI
import FitnessCore

struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TabView {
                    ForEach(Array(exercise.images.enumerated()), id: \.offset) { index, name in
                        Image(name)
                            .resizable()
                            .scaledToFit()
                            .overlay(alignment: .topLeading) {
                                Text(index == 0 ? "起始" : "结束")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(8)
                            }
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: 260)

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.nameZh).font(.largeTitle.bold())
                    Text(exercise.nameEn).font(.title3).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(title: "器材", value: "\(exercise.equipmentZh)\n\(exercise.equipmentEn)")
                    InfoRow(title: "主要练到", value: exercise.primaryMuscles.map(Format.muscleZh).joined(separator: "、"))
                    InfoRow(title: "计数", value: exercise.unit == .reps ? "按次数" : "按秒数")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("动作要点").font(.headline)
                    ForEach(Array(exercise.tipsZh.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.subheadline.bold())
                                .frame(width: 22, height: 22)
                                .background(Color.accentColor.opacity(0.15), in: Circle())
                            Text(tip)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(exercise.nameZh)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
        }
    }
}
