import SwiftUI
import FitnessCore

/// 结束页：时长、心率、卡路里。
struct SummaryView: View {
    let setCount: Int
    @Environment(TrainingModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    // 一周只见三次的时刻，值得一点点庆祝
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: appeared)
                    Text("训练完成")
                }
                .font(.title3.bold())

                if let summary = model.summary {
                    StatRow(title: "时长", value: Format.duration(summary.duration))
                    StatRow(title: "完成", value: "\(setCount) 组")
                    StatRow(title: "平均心率", value: summary.averageHeartRate.map { "\(Int($0)) 次/分" } ?? "无数据")
                    StatRow(title: "卡路里", value: summary.activeEnergy.map { "\(Int($0)) 千卡" } ?? "无数据")
                    if !summary.savedToHealth {
                        Text("未记录到健康 app")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if setCount == 0 {
                        Text("没有完成的组，不会保存记录")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Button("完成") { model.close() }
                        .buttonStyle(.borderedProminent)
                } else {
                    ProgressView("保存中…")
                }
            }
        }
        .onAppear {
            if !reduceMotion { appeared = true }
        }
    }
}

private struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }
}
