# 个人健身 app 实现计划

日期：2026-10-11
设计文档：`docs/superpowers/specs/2026-10-11-fitness-app-design.md`

## 总体思路

云端没有 Xcode，写出来的 iOS / watchOS 代码只能在你的 Mac 上编译。为了减少「写完才发现编译不过」，代码分成两层：

1. **FitnessCore**（Swift Package，只依赖 Foundation）：数据模型、JSON 读取、加重规则、A/B 交替、手表训练流程状态机、iPhone 和手表之间的消息格式。这一层在云端 Linux 上就能 `swift test`，逻辑问题在云端解决。
2. **App 层**（iPhone app + 手表 app）：SwiftUI 页面、SwiftData、WatchConnectivity、HealthKit。只做「把 Core 接到系统 API 上」，代码尽量薄，在 Mac 上编译和调试。

Xcode 工程用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成，工程文件不进 git。这样云端改代码、加文件都不用碰 `.pbxproj`，你在 Mac 上 `git pull && xcodegen` 就行。

## 目录结构

```
personal-fitness-app/
├── project.yml                     # XcodeGen 配置
├── Packages/FitnessCore/
│   ├── Package.swift
│   ├── Sources/FitnessCore/
│   │   ├── Models.swift            # Exercise, Plan, WorkoutTemplate 等
│   │   ├── Catalog.swift           # 读取 exercises.json / plan.json
│   │   ├── PlanEngine.swift        # A/B 交替 + 加重规则
│   │   ├── WorkoutFlow.swift       # 手表做组 / 休息流程状态机
│   │   ├── Messages.swift          # WatchPlan / CompletedWorkout
│   │   └── Resources/
│   │       ├── exercises.json
│   │       └── plan.json
│   └── Tests/FitnessCoreTests/
├── FitnessApp/                     # iPhone
│   ├── FitnessApp.swift
│   ├── Persistence/                # SwiftData 模型
│   ├── Sync/PhoneSync.swift
│   ├── Views/
│   └── Assets.xcassets/ExerciseImages/  # 60 张 jpg（asset catalog）
├── FitnessWatch/                   # 手表
│   ├── FitnessWatchApp.swift
│   ├── Sync/WatchSync.swift
│   ├── Sync/PendingStore.swift
│   ├── Health/WorkoutManager.swift
│   └── Views/
└── scripts/
    ├── fetch_images.py             # 从 Workout Guide 下载示范图
    └── validate_data.py            # 检查 JSON 和图片对得上
```

## 关键决定

- **部署版本**：iOS 18 / watchOS 11
- **Swift 语言模式**：App 层用 Swift 5 模式（`SWIFT_VERSION: 5.0`），避开 Swift 6 严格并发检查在 WatchConnectivity / HealthKit 回调上的大量报错。FitnessCore 用 Swift 6
- **手表 app**：watchOS 单 target 结构（不再有 WatchKit Extension），作为 iPhone app 的伴随 app 一起安装
- **重量单位**：磅（lb），全部按磅存储和显示，不做单位换算
- **表冠调重量**：每格 2.5 lb；调次数每格 1 次
- **自重动作**（平板支撑、卷腹等）：`increment` 为 0，手表上不显示重量
- **动作 id**：直接用 free-exercise-db 的 id（如 `Leg_Press`），方便以后对照原数据

### 计划里的动作对应 free-exercise-db

| 设计文档 | free-exercise-db id | 加重步长（lb） |
|---|---|---|
| 腿举 | `Leg_Press` | 10 |
| 坐姿器械推胸 | `Leverage_Chest_Press` | 10 |
| 高位下拉 | `Wide-Grip_Lat_Pulldown` | 10 |
| 坐姿哑铃推肩 | `Dumbbell_Shoulder_Press` | 5 |
| 平板支撑 | `Plank` | 0（按秒） |
| 高脚杯深蹲 | `Goblet_Squat` | 5 |
| 坐姿绳索划船 | `Seated_Cable_Rows` | 10 |
| 哑铃卧推 | `Dumbbell_Bench_Press` | 5 |
| 哑铃罗马尼亚硬拉 | `Stiff-Legged_Dumbbell_Deadlift` | 5 |
| 卷腹 | `Crunches` | 0 |

动作库另外 20 个（都已确认库里有两张图）：`Leg_Extensions`、`Seated_Leg_Curl`、`Dumbbell_Lunges`、`Standing_Calf_Raises`、`Single_Leg_Glute_Bridge`、`Hyperextensions_Back_Extensions`、`Leverage_Shoulder_Press`、`Side_Lateral_Raise`、`Reverse_Flyes`、`Butterfly`、`Pushups`、`Incline_Push-Up`、`Close-Grip_Front_Lat_Pulldown`、`Bent_Over_Two-Dumbbell_Row`、`One-Arm_Dumbbell_Row`、`Dumbbell_Bicep_Curl`、`Alternate_Hammer_Curl`、`Triceps_Pushdown_-_Rope_Attachment`、`Cable_Crunch`、`Dead_Bug`。

## 任务列表

每个任务结束都 commit 一次。标「☁️」的在云端完成并验证，标「💻」的需要你在 Mac 上操作。

---

### 任务 0 ☁️：云端装 Swift 工具链

目的：在云端跑 FitnessCore 的单元测试。

- 下载 swift.org 的 Linux 版 Swift 6.x 工具链，解压到 `~/swift`，加到 PATH
- 验证：`swift --version`
- 可选：写一个 SessionStart hook，以后的云端会话自动装好（用 session-start-hook skill）

不产生 commit（除非加了 hook）。

---

### 任务 1 ☁️：工程骨架

文件：

- `.gitignore`：忽略 `*.xcodeproj`、`DerivedData/`、`.build/`、`xcuserdata/`、`.DS_Store`
- `Packages/FitnessCore/Package.swift`：
  ```swift
  // swift-tools-version: 6.0
  import PackageDescription

  let package = Package(
      name: "FitnessCore",
      platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v15)],
      products: [.library(name: "FitnessCore", targets: ["FitnessCore"])],
      targets: [
          .target(name: "FitnessCore", resources: [.process("Resources")]),
          .testTarget(name: "FitnessCoreTests", dependencies: ["FitnessCore"]),
      ]
  )
  ```
- `project.yml`：
  ```yaml
  name: FitnessApp
  options:
    bundleIdPrefix: com.ym820.fitness
    deploymentTarget:
      iOS: "18.0"
      watchOS: "11.0"
  settings:
    base:
      SWIFT_VERSION: "5.0"
      DEVELOPMENT_TEAM: ""          # 在 Mac 上填你的 Team ID
      CODE_SIGN_STYLE: Automatic
  packages:
    FitnessCore:
      path: Packages/FitnessCore
  targets:
    FitnessApp:
      type: application
      platform: iOS
      sources: [FitnessApp]
      dependencies:
        - package: FitnessCore
        - target: FitnessWatch
      info:
        path: FitnessApp/Info.plist
        properties:
          CFBundleDisplayName: 健身
          UILaunchScreen: {}
      settings:
        base:
          PRODUCT_BUNDLE_IDENTIFIER: com.ym820.fitness
    FitnessWatch:
      type: application
      platform: watchOS
      sources: [FitnessWatch]
      dependencies:
        - package: FitnessCore
      entitlements:
        path: FitnessWatch/FitnessWatch.entitlements
        properties:
          com.apple.developer.healthkit: true
      info:
        path: FitnessWatch/Info.plist
        properties:
          CFBundleDisplayName: 健身
          WKApplication: true
          WKCompanionAppBundleIdentifier: com.ym820.fitness
          WKBackgroundModes: [workout-processing]
          NSHealthShareUsageDescription: 读取心率和卡路里，显示在训练总结里
          NSHealthUpdateUsageDescription: 把力量训练保存到健康 app
      settings:
        base:
          PRODUCT_BUNDLE_IDENTIFIER: com.ym820.fitness.watchkitapp
  ```
- `FitnessApp/FitnessApp.swift`、`FitnessWatch/FitnessWatchApp.swift`：各一个显示「Hello」的空页面
- `Packages/FitnessCore/Sources/FitnessCore/Models.swift`：先放一个占位类型，测试里断言 `1 + 1 == 2`，确认 `swift test` 能跑
- `README.md`：Mac 上的构建步骤

验证：云端 `cd Packages/FitnessCore && swift test` 通过。

---

### 任务 2 💻：第一次在 Mac 上跑起来（风险检查点）

这一步提前做，是为了尽早发现工程配置和签名的问题，不要等代码写完。

1. `brew install xcodegen`
2. `git pull && xcodegen`，打开 `FitnessApp.xcodeproj`
3. 两个 target 的 Signing & Capabilities 里选你的 Apple ID（Personal Team）
4. 选 iPhone 模拟器跑 `FitnessApp`，再选配对的手表模拟器跑 `FitnessWatch`，都能看到「Hello」
5. **确认免费账号能不能签 HealthKit**：手表 target 带了 HealthKit entitlement，如果签名报错，把报错发给我
6. 可选：真机装一次，确认 iPhone 和手表都能装上

把 Team ID 告诉我（或你自己填进 `project.yml` 后 push），之后生成工程就不用每次手动选。

---

### 任务 3 ☁️：动作数据

文件：

- `scripts/fetch_images.py`：按 `scripts/workout_guide_frames.json` 从 [Workout Guide](https://github.com/bryllim/workout-guide)（CC BY-SA 4.0）下载 SVG 线条图到 asset catalog，存成模板图，在 app 里按系统颜色染色。（最初用的是 free-exercise-db 的照片，后来换掉了）
- `Packages/FitnessCore/Sources/FitnessCore/Resources/exercises.json`：30 个动作，格式：
  ```json
  {
    "id": "Leg_Press",
    "nameZh": "腿举",
    "nameEn": "Leg Press",
    "equipmentZh": "腿举机",
    "equipmentEn": "Leg Press Machine",
    "bodyPart": "legs",
    "primaryMuscles": ["quadriceps"],
    "images": ["Leg_Press_0", "Leg_Press_1"],
    "tipsZh": [
      "背和臀部全程贴紧靠垫",
      "双脚与肩同宽，放在踏板中间",
      "下放到膝盖约 90 度，不要让臀部离开座椅",
      "推起时膝盖不要完全锁死"
    ],
    "unit": "reps",
    "increment": 10
  }
  ```
  `bodyPart` 取值：`legs`、`chest`、`back`、`shoulders`、`arms`、`core`，用于动作库分组。`unit` 取值：`reps` 或 `seconds`
- `plan.json`：
  ```json
  {
    "restSeconds": 90,
    "templates": [
      {
        "id": "A",
        "nameZh": "训练 A",
        "exercises": [
          { "exerciseId": "Leg_Press", "sets": 3, "targetMin": 8, "targetMax": 12 },
          { "exerciseId": "Plank", "sets": 3, "targetMin": 20, "targetMax": 40 }
        ]
      }
    ]
  }
  ```
- `scripts/validate_data.py`：检查每个动作都有 2 张图、`plan.json` 引用的 id 都在 `exercises.json` 里、`tipsZh` 有 3 到 5 条、`unit` 和 `increment` 合法

中文名和要点根据 free-exercise-db 的英文 `instructions` 翻译精简。图片一共约 60 张，直接进 git。

验证：`python3 scripts/validate_data.py` 通过。

---

### 任务 4 ☁️：Core 模型和数据读取（TDD）

`Models.swift`：

```swift
public enum ExerciseUnit: String, Codable, Sendable { case reps, seconds }

public struct Exercise: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let nameZh: String
    public let nameEn: String
    public let equipmentZh: String
    public let equipmentEn: String
    public let bodyPart: String
    public let primaryMuscles: [String]
    public let images: [String]
    public let tipsZh: [String]
    public let unit: ExerciseUnit
    public let increment: Double
    public var isWeighted: Bool { increment > 0 }
}

public struct PlanItem: Codable, Hashable, Sendable {
    public let exerciseId: String
    public let sets: Int
    public let targetMin: Int
    public let targetMax: Int
}

public struct WorkoutTemplate: Codable, Identifiable, Hashable, Sendable {
    public let id: String          // "A" 或 "B"
    public let nameZh: String
    public let exercises: [PlanItem]
}

public struct Plan: Codable, Sendable {
    public let restSeconds: Int
    public let templates: [WorkoutTemplate]
}
```

`Catalog.swift`：

```swift
public struct Catalog: Sendable {
    public let exercises: [Exercise]
    public let plan: Plan
    public func exercise(_ id: String) -> Exercise?
    public func template(_ id: String) -> WorkoutTemplate?
    public static func load(bundle: Bundle = .module) throws -> Catalog
    public static func decode(exercisesJSON: Data, planJSON: Data) throws -> Catalog
}
```

测试：

- 打包的 JSON 能解析，正好 30 个动作，模板 A 和 B 各 5 个动作
- 模板引用的每个 `exerciseId` 都能找到
- id 没有重复

---

### 任务 5 ☁️：PlanEngine（TDD）

输入用纯数据，不依赖 SwiftData，iPhone 端负责把数据库记录转换过来。

```swift
public struct HistorySet: Hashable, Sendable {
    public let exerciseId: String
    public let setIndex: Int
    public let value: Int          // 次数或秒数
    public let weightLb: Double
}

public struct HistoryWorkout: Sendable {
    public let date: Date
    public let templateId: String
    public let sets: [HistorySet]
}

public struct TargetExercise: Codable, Hashable, Sendable {
    public let exerciseId: String
    public let sets: Int
    public let targetMin: Int
    public let targetMax: Int
    public let weightLb: Double?   // nil 表示第一次做，需要用户输入；自重动作为 0
    public let suggestIncrease: Bool
}

public struct NextWorkout: Codable, Hashable, Sendable {
    public let templateId: String
    public let exercises: [TargetExercise]
}

public enum PlanEngine {
    public static func nextTemplateId(history: [HistoryWorkout]) -> String
    public static func next(catalog: Catalog, history: [HistoryWorkout]) -> NextWorkout
}
```

规则：

- `nextTemplateId`：按日期找最后一次训练，是 A 就返回 B，否则返回 A；没有记录返回 A
- 某个动作的目标重量：找最近一次包含这个动作的训练（不限 A/B），取那次各组重量的最大值
  - 没找到：自重动作返回 0，否则返回 nil
  - 那次完成的组数 ≥ 计划组数，且每组 `value ≥ targetMax`：重量 + `increment`，`suggestIncrease = true`
  - 否则沿用原重量
  - 自重动作永远不提示加重

测试用例：

- 没有历史 → A，所有负重动作 `weightLb == nil`，平板支撑和卷腹为 0
- 最后一次是 A → B；最后一次是 B → A；历史乱序时按日期判断
- 腿举 3 组都 12 次 @ 100 lb → 110 lb，提示加重
- 腿举 12、12、11 次 → 100 lb，不提示
- 腿举只做了 2 组且都 12 次（中途结束）→ 不加重
- 哑铃卧推全部做满 @ 20 lb → 25 lb
- 平板支撑全部 40 秒 → 不提示加重

---

### 任务 6 ☁️：WorkoutFlow 状态机（TDD）

手表上「做组 → 休息 → 下一组 → 下一个动作 → 结束」的逻辑放在 Core 里，手表页面只负责显示当前状态。

```swift
public struct WorkoutFlow: Sendable {
    public enum Phase: Equatable, Sendable {
        case doingSet(exerciseIndex: Int, setIndex: Int)
        case resting(next: Position)
        case finished
    }

    public init(workout: NextWorkout, restSeconds: Int)
    public private(set) var phase: Phase
    public private(set) var completedSets: [HistorySet]

    public var current: TargetExercise?          // 正在做或即将做的动作
    public func defaultValue() -> Int            // 预填次数：targetMax
    public func defaultWeight() -> Double?       // 本动作上一组的实际重量，没有就用目标重量

    public mutating func completeSet(value: Int, weightLb: Double)
    public mutating func finishRest()            // 跳过休息或倒计时结束
    public mutating func endEarly()
}
```

规则：

- 完成最后一个动作的最后一组后直接 `finished`，不进休息
- 同一个动作里，用户改过的重量带到下一组
- `endEarly` 保留已完成的组

测试：完整走一遍 A（15 组，14 次休息）；改重量后下一组预填新重量；中途结束保留已完成组；空训练直接 finished。

---

### 任务 7 ☁️：消息格式（TDD）

```swift
public struct WatchPlan: Codable, Sendable {
    public let workout: NextWorkout
    public let restSeconds: Int
    public let generatedAt: Date      // 动作名称等静态数据手表自己从 Catalog 读
}

public struct CompletedWorkout: Codable, Identifiable, Sendable {
    public let id: UUID            // iPhone 端用它去重
    public let templateId: String
    public let startDate: Date
    public let endDate: Date
    public let sets: [HistorySet]  // HistorySet 补上 Codable
}

public enum MessageCodec {
    public static let planKey = "plan"
    public static let workoutKey = "workout"
    public static func encode<T: Encodable>(_ value: T) throws -> Data
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}
```

WatchConnectivity 的字典里只放 `Data`（JSON），日期用 ISO 8601。

测试：两种消息 encode / decode 往返一致。

---

### 任务 8 ☁️：iPhone 数据和同步

`FitnessApp/Persistence/Models.swift`（SwiftData）：

```swift
@Model final class WorkoutLog {
    @Attribute(.unique) var id: UUID
    var templateId: String
    var startDate: Date
    var endDate: Date
    @Relationship(deleteRule: .cascade) var sets: [SetLog]
}

@Model final class SetLog {
    var exerciseId: String
    var setIndex: Int
    var value: Int
    var weightLb: Double
}
```

加上 `WorkoutLog.toHistory() -> HistoryWorkout` 和 `WorkoutLog(from: CompletedWorkout)`。

`FitnessApp/Sync/PhoneSync.swift`：

- `@Observable final class PhoneSync: NSObject, WCSessionDelegate`
- 启动时 `WCSession.default.activate()`
- `didReceiveUserInfo`：解出 `CompletedWorkout`，切到主线程，按 `id` 去重后存入 SwiftData，然后调用 `pushPlan()`
- `pushPlan()`：查全部 `WorkoutLog` → `PlanEngine.next` → 组装 `WatchPlan` → `updateApplicationContext`
- app 启动、激活完成、回到前台时都调用一次 `pushPlan()`
- 必须实现的 iOS 回调：`sessionDidBecomeInactive`、`sessionDidDeactivate`（里面重新 `activate()`）

---

### 任务 9 ☁️：iPhone 页面

`TabView` 三个 tab：

1. **今天** `TodayView`：标题「下次：训练 A」，列出 5 个动作卡片（中英文名、组数 x 次数、目标重量；第一次做显示「首次，手表上输入重量」；要加重的显示「↑ 加重」标记）。点卡片进动作详情
2. **动作库** `LibraryView`：按 `bodyPart` 分 6 组（腿、胸、背、肩、手臂、核心），带搜索（中英文都能搜）。`ExerciseDetailView`：两张示范图左右滑动、中英文名、器材、主要肌群、要点列表
3. **历史** `HistoryView`：`@Query` 按日期倒序，每行显示日期、训练 A/B、时长。`WorkoutDetailView`：按动作分组列出每组的次数和重量

图片在 asset catalog 里，直接 `Image("Leg_Press_0")`。

---

### 任务 10 ☁️：手表同步和本地暂存

`FitnessWatch/Sync/WatchSync.swift`：

- `@Observable final class WatchSync: NSObject, WCSessionDelegate`
- `var plan: WatchPlan?`：启动时从 `WCSession.default.receivedApplicationContext` 读，之后在 `didReceiveApplicationContext` 更新
- `send(_ workout: CompletedWorkout)`：先存进 `PendingStore`，再 `transferUserInfo`
- `didFinish userInfoTransfer, error == nil`：从 `PendingStore` 删掉这条
- 激活完成后：把 `PendingStore` 里所有没在 `outstandingUserInfoTransfers` 中的记录重新发送

`FitnessWatch/Sync/PendingStore.swift`：把 `[CompletedWorkout]` 存成 Documents 下的一个 JSON 文件。

---

### 任务 11 ☁️：手表 HealthKit

`FitnessWatch/Health/WorkoutManager.swift`：

- `@Observable final class WorkoutManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate`
- `requestAuthorization()`：写 `HKObjectType.workoutType()`，读 `heartRate`、`activeEnergyBurned`
- `start()`：`HKWorkoutConfiguration(activityType: .traditionalStrengthTraining, locationType: .indoor)`，创建 session 和 builder，`builder.dataSource = HKLiveWorkoutDataSource(...)`，`startActivity` + `beginCollection`
- 实时属性：`heartRate`、`activeEnergy`、`elapsed`（`didCollectDataOf` 里更新）
- `end() async -> Summary`：`session.end()`、`endCollection`、`finishWorkout`，返回时长、平均心率、卡路里
- 权限被拒或出错：`start()` 不抛错，`isHealthAvailable = false`，训练照常进行，结束页显示「未记录到健康」

---

### 任务 12 ☁️：手表页面

根视图 `RootView` 根据状态切换：

1. **没有计划**：「请先在 iPhone 上打开 app」
2. **开始页** `StartView`：大字「训练 A」，下面列动作英文名，「开始」按钮 → `WorkoutManager.start()` + 创建 `WorkoutFlow`
3. **做组页** `SetView`：
   - 顶部：中文名 + 英文名，「第 2 / 3 组」
   - 中间两个数字：次数（或秒数）和重量，点哪个就用表冠调哪个（`.digitalCrownRotation`，重量步长 2.5 lb，次数步长 1）。自重动作只显示次数
   - 首次做负重动作（目标重量为 nil）：重量默认 0 并高亮提示「请输入重量」
   - 「完成」按钮 → `flow.completeSet`
   - 右上角显示实时心率
4. **休息页** `RestView`：90 秒倒计时（`TimelineView`），下一组是什么动作；「跳过」和「+30 秒」；到 0 时 `WKInterfaceDevice.current().play(.notification)` 震动并自动 `finishRest()`
5. **结束页** `SummaryView`：时长、平均心率、卡路里、完成组数；「完成」按钮 → 发送 `CompletedWorkout`，回到开始页
6. 做组页和休息页都能长按或下滑出「结束训练」→ `flow.endEarly()` → 结束页

休息倒计时在 app 退到后台时也要准：用「结束时间点」计算剩余秒数，不用累减计时器。训练进行中 `HKWorkoutSession` 会让 app 保持前台运行。

---

### 任务 13 💻：模拟器完整测试

1. `git pull && xcodegen`，编译两个 target，把所有编译错误发给我（或截图）
2. iPhone 模拟器打开 app → 今天页显示训练 A
3. 手表模拟器打开 → 显示训练 A → 走完一次训练（可以把休息跳过）
4. 回到 iPhone → 历史里有记录，今天页变成训练 B，做满的动作显示加重
5. 再走一次训练 B，中途结束，确认已完成的组保存了

模拟器的 HealthKit 心率是假的或没有，这一步不用管心率。

---

### 任务 14 💻：真机和健身房实测

1. 真机安装 iPhone 和手表 app，首次打开手表 app 时授权健康
2. 在健身房完整练一次，只看手表
3. 回家检查：iPhone 历史、Apple 健康里有一条「传统力量训练」带心率和卡路里、健身记录圆环有增加
4. 记下用起来别扭的地方，下一轮改

免费 Apple ID 签名的 app 7 天后会打不开，到时在 Mac 上重新运行一次即可。

## 风险和应对

| 风险 | 应对 |
|---|---|
| XcodeGen 生成的手表 app 没嵌进 iPhone app | 任务 2 就验证；不行就改 `project.yml` 的嵌入配置，或改用 Xcode 自带模板建工程 |
| 免费账号不能用 HealthKit | 任务 2 就验证；不行就先去掉 HealthKit，其他功能照做，之后再决定是否买开发者账号 |
| App 层代码没在云端编译过 | Core 逻辑都在云端测过；App 层代码保持简单，任务 13 集中修编译错误 |
| WatchConnectivity 在模拟器上不稳定 | 以真机结果为准；`updateApplicationContext` 和 `transferUserInfo` 都是排队机制，不依赖两边同时在线 |
