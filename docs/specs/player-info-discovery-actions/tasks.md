# Implementation Tasks: player-info-discovery-actions

- Spec: `docs/specs/player-info-discovery-actions/spec.md`
- Status: Implemented
- Owner: Codex + project maintainers
- Last updated: 2026-04-06

## Working Agreements

- Keep each task independently reviewable.
- Prefer one focused code change per task.
- Update this file as tasks move from Todo to In progress to Done.
- Record validation next to the task that introduced the change.
- For playback or audio-related work, make teardown and lifecycle cleanup explicit in either a task goal, risk, or definition of done.

## Task 1: 通用化播放器发现页签

- Status: Done
- Goal: 将原先仅服务于 `精选` 的发现页签插件扩展为普通视频播放器通用插件，并统一文案为 `相关视频`。
- Files likely to change: `BilibiliLive/Component/Video/Plugins/VideoPlayerInfoTabsPlugin.swift`
- Risks or dependencies: 发现候选切播必须兼容“有原始序列时临时覆盖、无原始序列时直接切播”两种场景。
- Definition of done: `博主视频` / `相关视频` 页签在插件层可独立渲染、加载并触发切播，不依赖 `精选` 专属装配。
- Validation: 通过播放器构建验证与发现页签手工场景验证。

## Task 2: 新增互动页签与状态管理

- Status: Done
- Goal: 在播放器信息面板新增 `互动` 页签，提供关注博主、点赞视频、收藏视频三项能力。
- Files likely to change: `BilibiliLive/Component/Video/Plugins/VideoPlayerInfoTabsPlugin.swift`
- Risks or dependencies: 点赞 / 收藏状态为异步补齐；收藏夹选择与取消收藏必须沿用详情页现有语义。
- Definition of done: 互动页签可展示三张动作卡片，确认键触发对应动作，状态和计数更新符合预期。
- Validation: 通过播放器构建验证与互动页签手工场景验证。

## Task 3: 统一播放器接入并移除精选专属注入

- Status: Done
- Goal: 在所有普通视频播放器统一挂载通用页签插件，并移除 `精选` 的专属插件注入，避免重复页签。
- Files likely to change: `BilibiliLive/Component/Video/VideoPlayerViewModel.swift`, `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
- Risks or dependencies: bangumi/PGC 必须继续排除；`精选` 原有的发现切播语义不能回归。
- Definition of done: 非预览、非 bangumi/PGC 的普通视频播放器统一具备三页签，`精选` 中不出现重复页签。
- Validation: 通过播放器构建验证与 `精选` / 非精选双入口手工场景验证。

## Task 4: 文档与验证收尾

- Status: Done
- Goal: 更新 spec/tasks 并完成最相关构建验证，记录剩余手工验证风险。
- Files likely to change: `docs/specs/player-info-discovery-actions/spec.md`, `docs/specs/player-info-discovery-actions/tasks.md`
- Risks or dependencies: 仓库没有自动化测试，播放器信息面板与收藏弹窗仍需在 tvOS 模拟器或真机手工确认。
- Definition of done: 新 spec/tasks 与实际行为一致，并完成 `fastlane build_simulator` 或明确记录阻塞原因。
- Validation: `fastlane build_simulator` passed on 2026-04-06; manual tvOS simulator / device verification still pending.
