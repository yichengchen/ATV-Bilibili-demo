# Implementation Tasks: info-panel-focus-hook-crash

- Spec: `docs/specs/info-panel-focus-hook-crash/spec.md`
- Status: Implemented
- Owner: Codex + project maintainers
- Last updated: 2026-04-05

## Working Agreements

- Keep each task independently reviewable.
- Prefer one focused code change per task.
- Update this file as tasks move from Todo to In progress to Done.
- Record validation next to the task that introduced the change.
- For playback or audio-related work, make teardown and lifecycle cleanup explicit in either a task goal, risk, or definition of done.

## Task 1: Document the crash and compatibility boundary

- Status: Done
- Goal: 记录 `UITabBarButton swizz_didUpdateFocusIn:with:` 崩溃根因，以及信息面板 Hook 的兼容性边界。
- Files likely to change:
  - `docs/specs/info-panel-focus-hook-crash/spec.md`
  - `docs/specs/info-panel-focus-hook-crash/tasks.md`
- Risks or dependencies:
  - 需要准确说明 inherited method swizzle 为什么会污染到 `UIView` 级别实现。
- Definition of done:
  - Spec 清楚描述根因、目标、降级策略和手动验证范围。
- Validation:
  - 基于崩溃栈与 Hook 代码完成根因分析。

## Task 2: Localize the swizzle to AV info-panel cell classes

- Status: Done
- Goal: 将 Hook 改为仅对 AVKit 信息面板相关 cell 做 class-local swizzle，并保留标题提取兜底。
- Files likely to change:
  - `BilibiliLive/Extensions/AVInfoPanelCollectionViewThumbnailCell+Hook.swift`
- Risks or dependencies:
  - 不能再次交换到 `UIView` 继承链上。
  - 不能破坏旧运行时上依赖 `setTitle:` 的标题采集。
- Definition of done:
  - Hook 只处理运行时发现的 AV info-panel cell 类。
  - 原方法来自父类时也只在目标 class 上生成覆盖实现。
  - 无匹配类时安全跳过。
- Validation:
  - 代码审查确认不再对 `UICollectionViewCell` 直接做全局 `method_exchangeImplementations`。

## Task 3: Build verification and residual risk capture

- Status: Done
- Goal: 完成最相关的构建验证并记录仍需手测的焦点路径。
- Files likely to change:
  - `docs/specs/info-panel-focus-hook-crash/spec.md`
  - `docs/specs/info-panel-focus-hook-crash/tasks.md`
- Risks or dependencies:
  - 仓库无自动化测试，仍需模拟器补充焦点手测。
- Definition of done:
  - 至少完成一次相关构建验证，或明确记录为什么未能执行。
  - 文档保留 TabBar 与播放器信息面板的剩余手测风险。
- Validation:
  - `fastlane build_simulator` 在沙箱内失败，原因是无法访问 CoreSimulator 与 SwiftPM/clang 缓存目录。
  - `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build` 通过。

## Task 4: Support late-loaded AV info panel classes on device

- Status: Done
- Goal: 让 Hook 在真机上遇到 AVKit 私有类懒加载时仍能后补安装，并增强焦点标题提取以兼容更深的私有子视图层级。
- Files likely to change:
  - `BilibiliLive/Extensions/AVInfoPanelCollectionViewThumbnailCell+Hook.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
  - `docs/specs/info-panel-focus-hook-crash/spec.md`
  - `docs/specs/info-panel-focus-hook-crash/tasks.md`
- Risks or dependencies:
  - 重复 swizzle 不能把实现交换回去。
  - 祖先扫描不能误命中整个信息面板里其他 action 的文本。
- Definition of done:
  - Hook 支持重复调用并只对未处理类生效。
  - 播放器在相关焦点更新时可触发一次延迟补装。
  - 标题提取可从焦点视图向上回溯到合适的祖先 cell / 容器。
- Validation:
  - `fastlane build_simulator` 通过。
  - 真机补充手测待验证。
