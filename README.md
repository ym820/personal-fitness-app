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
