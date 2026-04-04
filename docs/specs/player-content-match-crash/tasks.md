# Implementation Tasks: player-content-match-crash

- Spec: `docs/specs/player-content-match-crash/spec.md`
- Status: Implemented
- Owner: Codex + project maintainers
- Last updated: 2026-04-04

## Working Agreements

- Keep each task independently reviewable.
- Prefer one focused code change per task.
- Update this file as tasks move from Todo to In progress to Done.
- Record validation next to the task that introduced the change.

## Task 1: Reproduce and document the content-match crash

- Status: Done
- Goal: 记录崩溃触发条件、受影响设置组合和验收边界。
- Files likely to change:
  - `docs/specs/player-content-match-crash/spec.md`
  - `docs/specs/player-content-match-crash/tasks.md`
- Risks or dependencies:
  - 需要从崩溃栈准确定位到 AVKit 属性切换时机。
- Definition of done:
  - Spec 明确说明崩溃根因、受影响链路和手动验证项。
- Validation:
  - 基于崩溃日志完成根因分析。

## Task 2: Apply content-match preference only once per playback session

- Status: Done
- Goal: 在首次装配播放资源时一次性决定是否启用内容匹配，避免进入非 HDR 视频时二次写入 AVKit 属性。
- Files likely to change:
  - `BilibiliLive/Component/Video/Plugins/BVideoPlayPlugin.swift`
- Risks or dependencies:
  - 不能破坏 HDR 首次进入播放时的匹配能力。
  - 不能影响画质切换时的播放器重建流程。
- Definition of done:
  - 首次播放前根据 HDR 判定结果设置内容匹配。
  - 非 HDR 首次进入播放时不再先开后关该属性。
  - 画质切换路径继续避免在会话中途修改该属性。
- Validation:
  - 代码审查确认属性只在首次播放准备阶段写入一次。

## Task 3: Run build verification and capture residual risk

- Status: Done
- Goal: 通过最相关的构建验证确认修复可编译，并记录仍需手测的播放场景。
- Files likely to change:
  - `docs/specs/player-content-match-crash/spec.md`
  - `docs/specs/player-content-match-crash/tasks.md`
- Risks or dependencies:
  - 仓库没有自动化测试，仍需模拟器或真机补充播放验证。
- Definition of done:
  - 至少完成一次与本改动相关的构建验证。
  - 文档中记录尚未覆盖的手测风险。
- Validation:
  - `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build` 通过。
  - `bundle exec fastlane build_simulator` 未执行，当前环境缺少 `bundler 2.3.19`。
