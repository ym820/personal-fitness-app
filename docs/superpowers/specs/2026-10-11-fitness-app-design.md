# 个人健身 app 设计文档

日期：2026-10-11

## 目标

给一个健身新手自己用的 iPhone + Apple Watch app，解决三个痛点：

1. 不知道如何开始：内置新手计划，打开就知道今天练什么
2. 不认识器材/动作：动作库带示范图、中英文名、器材、动作要点
3. Apple Watch 在健身房不好用：手表上跟着计划一组一组做，组间计时，记录心率和卡路里

成功标准：去健身房时只看手表就能完成一次训练，回家后 iPhone 上能看到记录，Apple 健康里有这次力量训练。

## 范围

做：

- 一套固定的新手计划（A/B 两套全身训练交替）
- 约 30 个动作的离线动作库
- 手表端训练流程 + HealthKit 训练记录
- iPhone 端历史记录

不做（以后需要再加）：

- 自定义计划、按目标生成计划
- 账号、云同步、多设备
- 图表、统计分析
- 教学视频

## 技术选型

- SwiftUI，iOS 18 / watchOS 11
- iPhone 用 SwiftData 存训练历史
- iPhone 和手表之间用 WatchConnectivity 传数据
- 手表用 HealthKit 的 `HKWorkoutSession` + `HKLiveWorkoutBuilder`，类型为 `traditionalStrengthTraining`
- 动作图片来自 [free-exercise-db](https://github.com/yuhonas/free-exercise-db)（Unlicense，公有领域），打包进 app，离线可用
- 签名：先用免费 Apple ID（每 7 天要重新安装一次），需要时再升级付费开发者账号。HealthKit 能否用免费账号签名，要在搭项目时确认

## 新手计划

A/B 交替，每周 3 次（比如周一 A、周三 B、周五 A，下周一 B）。每个动作 3 组 x 8-12 次，组间休息 90 秒。以器械和哑铃为主，新手更容易上手、更安全。

训练 A：

| 动作 | English |
|---|---|
| 腿举 | Leg Press |
| 坐姿器械推胸 | Machine Chest Press |
| 高位下拉 | Lat Pulldown |
| 坐姿哑铃推肩 | Seated Dumbbell Shoulder Press |
| 平板支撑 | Plank |

训练 B：

| 动作 | English |
|---|---|
| 高脚杯深蹲 | Goblet Squat |
| 坐姿绳索划船 | Seated Cable Row |
| 哑铃卧推 | Dumbbell Bench Press |
| 哑铃罗马尼亚硬拉 | Dumbbell Romanian Deadlift |
| 卷腹 | Crunch |

平板支撑按秒计（3 组 x 20-40 秒），其他按次数计。具体动作在实现时以 free-exercise-db 里有图的为准，可以替换成相近动作。

加重规则：

- 第一次做某个动作时，重量由用户在手表上用表冠输入
- 之后默认用上一次的重量
- 上一次所有组都做到了最高次数（12 次 / 40 秒），这次提示加重：器械 +5 kg，哑铃 +2 kg（每只）
- 不做自动减重，用户可以随时在手表上调

下次练 A 还是 B：看最后一次训练记录，交替。没有记录就从 A 开始。

## 数据

静态数据（打包在 app 里，iPhone 和手表都带一份）：

- `exercises.json`：`id`、`nameZh`、`nameEn`、`equipmentZh`、`equipmentEn`、`primaryMuscles`、`images`（起始和结束两张）、`tipsZh`（3-5 条动作要点）、`unit`（次数或秒）、`increment`（加重步长）
- `plan.json`：训练 A 和 B，每个动作的组数和目标次数范围

中文名和动作要点由我根据 free-exercise-db 的英文说明翻译、精简，你可以随时改 JSON。

训练记录（SwiftData，只存在 iPhone）：

- `WorkoutLog`：`date`、`template`（A 或 B）、`sets`
- `SetLog`：`exerciseId`、`setIndex`、`reps`（或秒数）、`weightKg`

## 页面

iPhone：

- 今天：下次是训练 A 还是 B、每个动作的目标重量，点动作看详情
- 动作库：按部位分组的列表，点进去看示范图、中英文名、器材、要点
- 历史：按日期列出每次训练，点进去看每组的次数和重量

手表：

1. 开始页：显示「训练 A」或「训练 B」，点开始，同时开始 HealthKit 训练
2. 做组页：动作中英文名、第几组 / 共几组、目标次数和重量。表冠调实际次数和重量，点「完成」
3. 休息页：90 秒倒计时，时间到震动，可以跳过或 +30 秒；之后自动进入下一组或下一个动作
4. 结束页：全部做完或手动结束，显示时长、平均心率、卡路里；保存 HealthKit 训练，把记录发回 iPhone

手表上只显示文字，不显示示范图，图片在 iPhone 上看。

## 数据流

1. iPhone 算出下次训练（A/B + 每个动作的目标重量），用 `updateApplicationContext` 发给手表。手表不在附近也没关系，下次连上会收到最新的一份
2. 手表按这份数据带你练
3. 训练结束，手表用 `transferUserInfo` 把每组记录发回 iPhone（会排队，iPhone 没开也不会丢）
4. iPhone 收到后存入 SwiftData，再算下一次训练，回到第 1 步

## 异常处理

- 手表还没收到过计划：提示「请先在 iPhone 上打开 app」
- 用户拒绝 HealthKit 权限：照常记录组数，只是健康里没有这次训练
- 中途结束训练：保存已完成的组
- 记录发回 iPhone 前手表 app 被关：记录先存到手表本地，下次启动时重新发送

## 测试

- 单元测试：加重规则、A/B 交替、JSON 能正确解析且每个动作都有图片
- 模拟器：iPhone 和手表配对模拟器，走一遍完整训练
- 真机：在健身房实际练一次，检查健康 app 里的记录

## 开工前需要准备

- 从 App Store 安装 Xcode，然后运行 `sudo xcode-select -s /Applications/Xcode.app`
- Xcode 里登录 Apple ID
