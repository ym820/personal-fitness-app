import Foundation

public enum BodyPart: String, CaseIterable, Sendable {
    case legs, chest, back, shoulders, arms, core

    public var nameZh: String {
        switch self {
        case .legs: "腿和臀"
        case .chest: "胸"
        case .back: "背"
        case .shoulders: "肩"
        case .arms: "手臂"
        case .core: "核心"
        }
    }
}

/// 页面上的文字格式，iPhone 和手表共用。
public enum Format {
    public static func weight(_ lb: Double) -> String {
        "\(number(lb)) lb"
    }

    public static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    public static func unitZh(_ unit: ExerciseUnit) -> String {
        unit == .reps ? "次" : "秒"
    }

    public static func value(_ value: Int, unit: ExerciseUnit) -> String {
        "\(value) \(unitZh(unit))"
    }

    public static func target(min: Int, max: Int, unit: ExerciseUnit) -> String {
        "\(min)-\(max) \(unitZh(unit))"
    }

    /// 秒数 → "1:05" 或 "1:02:05"
    public static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// 估算时长，取整到 5 分钟
    public static func approxMinutes(_ seconds: TimeInterval) -> String {
        let minutes = max(5, Int((seconds / 60 / 5).rounded()) * 5)
        return "约 \(minutes) 分钟"
    }

    public static func muscleZh(_ muscle: String) -> String {
        muscleNames[muscle] ?? muscle
    }

    private static let muscleNames = [
        "abdominals": "腹肌",
        "biceps": "肱二头肌",
        "calves": "小腿",
        "chest": "胸肌",
        "forearms": "前臂",
        "glutes": "臀肌",
        "hamstrings": "大腿后侧",
        "lats": "背阔肌",
        "lower back": "下背",
        "middle back": "中背",
        "quadriceps": "大腿前侧",
        "shoulders": "肩部",
        "traps": "斜方肌",
        "triceps": "肱三头肌",
    ]
}
