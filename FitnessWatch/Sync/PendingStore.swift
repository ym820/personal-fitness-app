import Foundation
import FitnessCore

/// 还没确认送到 iPhone 的训练，存成 Documents 下的一个 JSON 文件。
/// 手表 app 在发送途中被关掉也不会丢，下次启动重新发送。
struct PendingStore {
    private let url = URL.documentsDirectory.appending(path: "pending-workouts.json")

    func load() -> [CompletedWorkout] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? MessageCodec.decode([CompletedWorkout].self, from: data)) ?? []
    }

    func add(_ workout: CompletedWorkout) {
        var all = load()
        guard !all.contains(where: { $0.id == workout.id }) else { return }
        all.append(workout)
        save(all)
    }

    func remove(id: UUID) {
        save(load().filter { $0.id != id })
    }

    private func save(_ workouts: [CompletedWorkout]) {
        do {
            try MessageCodec.encode(workouts).write(to: url, options: .atomic)
        } catch {
            print("保存待发送训练失败：\(error)")
        }
    }
}
