# 个人健身 app

iPhone + Apple Watch 的新手力量训练 app。设计见 `docs/superpowers/specs/`，实现计划见 `docs/superpowers/plans/`。

## 在 Mac 上构建

第一次：

```sh
brew install xcodegen
```

每次拉完代码：

```sh
git pull
xcodegen
open FitnessApp.xcodeproj
```

`FitnessApp.xcodeproj` 由 `project.yml` 生成，不进 git，不要手动改工程设置（改了下次生成会被覆盖），需要改的告诉 Claude 改 `project.yml`。

签名：在 `FitnessApp` 和 `FitnessWatch` 两个 target 的 Signing & Capabilities 里选你的 Apple ID。也可以把 Team ID 填到 `project.yml` 的 `DEVELOPMENT_TEAM`。

运行：Scheme 选 `FitnessApp` + iPhone 模拟器；手表选 `FitnessWatch` + 配对的手表模拟器。

## 核心逻辑测试

不需要 Xcode 工程，Mac 或 Linux 上都能跑：

```sh
cd Packages/FitnessCore
swift test
```

## 素材来源

- 动作示范图：[Workout Guide](https://github.com/bryllim/workout-guide)，作者 Bryl Lim，基于 [Everkinetic](https://github.com/everkinetic/data)，[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)。改动：裁掉了画布四周的空白（只改 SVG 的 viewBox），在 app 里按系统颜色染色，线条本身未改。改动后的图片同样按 CC BY-SA 4.0 授权。每个动作用哪两帧见 `scripts/workout_guide_frames.json`，重新下载用 `python3 scripts/fetch_images.py`。
- 动作列表和英文说明：[free-exercise-db](https://github.com/yuhonas/free-exercise-db)（Unlicense）。中文名和动作要点是根据它的英文说明翻译精简的。
