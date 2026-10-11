import SwiftUI
import FitnessCore

struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ExerciseDemo(exercise: exercise)

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.nameZh).font(.largeTitle.bold())
                    Text(exercise.nameEn).font(.title3).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(title: "器材", value: exercise.equipmentZh, detail: exercise.equipmentEn)
                    InfoRow(title: "主要练到", value: exercise.primaryMuscles.map(Format.muscleZh).joined(separator: "、"), detail: nil)
                    InfoRow(title: "计数", value: exercise.unit == .reps ? "按次数" : "按秒数", detail: nil)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("动作要点").font(.headline)
                    ForEach(Array(exercise.tipsZh.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                                .frame(width: 24, height: 24)
                                .background(Color.green.opacity(0.15), in: Circle())
                            Text(tip)
                                .fixedSize(horizontal: false, vertical: true)
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

/// 动作示范：起始和结束两张图自动来回切换，看起来像在做这个动作。
/// 这是有目的的动画（讲解动作），点一下暂停 / 继续。开了「减弱动态效果」就不自动播放，改成点一下切换。
private struct ExerciseDemo: View {
    let exercise: Exercise
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame = 0
    @State private var isPlaying = true

    private var autoPlays: Bool { isPlaying && !reduceMotion }

    var body: some View {
        ZStack {
            ForEach(Array(exercise.images.enumerated()), id: \.offset) { index, name in
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .opacity(index == frame ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topLeading) {
            Text(frame == 0 ? "起始" : "结束")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(8)
        }
        .overlay(alignment: .bottomTrailing) {
            if !reduceMotion {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if reduceMotion {
                frame = (frame + 1) % max(1, exercise.images.count)
            } else {
                isPlaying.toggle()
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(exercise.nameZh)示范图，\(frame == 0 ? "起始" : "结束")姿势")
        .accessibilityAddTraits(.isButton)
        .task(id: autoPlays) {
            guard autoPlays, exercise.images.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                // 画面上原地变化用 ease-in-out
                withAnimation(.easeInOut(duration: 0.35)) {
                    frame = (frame + 1) % exercise.images.count
                }
            }
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String
    let detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}
