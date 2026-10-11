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

                let videos = Catalog.bundled.videos(for: exercise.id)
                if !videos.isEmpty {
                    VideoSection(videos: videos)
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

/// 动作示范：起始和结束两张线条图放在一起对比，中间用箭头表示先后。
/// 线条图是模板图，跟着文字颜色走，深色模式自动变白。
/// 两帧的大小和角度不完全一致，所以不做淡入淡出切换（会出现重影），直接并排更清楚。
/// 横向的图（比如腿举）上下排，竖向的图（比如深蹲）左右排，让图尽量大。
private struct ExerciseDemo: View {
    let exercise: Exercise

    private var isWide: Bool {
        guard let size = UIImage(named: exercise.images.first ?? "")?.size, size.height > 0 else { return false }
        return size.width / size.height > 1.2
    }

    var body: some View {
        let layout = isWide
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 4))

        layout {
            ForEach(Array(exercise.images.enumerated()), id: \.offset) { index, name in
                if index > 0 {
                    Image(systemName: isWide ? "arrow.down" : "arrow.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                art(name)
                    .frame(maxHeight: isWide ? 150 : nil)
            }
        }
        .frame(height: isWide ? nil : 220)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(exercise.nameZh)示范图")
    }

    private func art(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
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
