# Implementation Tasks: shared-feed-flow-and-follows

- Spec: `docs/specs/shared-feed-flow-and-follows/spec.md`
- Status: Implemented
- Owner:
- Last updated: 2026-04-06

## Working Agreements

- Keep each task independently reviewable.
- Prefer one focused code change per task.
- Update this file as tasks move from Todo to In progress to Done.
- Record validation next to the task that introduced the change.
- For playback or audio-related work, make teardown and lifecycle cleanup explicit in either a task goal, risk, or definition of done.

## Task 1: 抽出通用 feed-flow 浏览骨架

- Status: Done
- Goal: 将 `精选` 中与页面来源无关的浏览态、预览、正式播放、落点恢复、上下切换与清理逻辑抽到共享控制器中。
- Files likely to change:
  - `BilibiliLive/Module/ViewController/FeedFlowBrowserViewController.swift`
  - `BilibiliLive/Component/Video/FeedFlowPlayerConfiguration.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewModel.swift`
- Risks or dependencies:
  - 播放器扩展点必须允许页面按需注入额外 plugin，避免把 `精选` 特有发现页签泄漏给其他页面。
  - 退出、切页和后台场景仍需显式清理预览播放器与 warmup 任务。
- Definition of done:
  - `FeedFlowItem`、`FeedFlowDataSource`、`FeedFlowPlayerConfiguration` 可支撑至少两个页面来源。
  - feed-flow 播放态额外 plugin 可由页面配置，不再在播放器里硬编码 `FeaturedVideoDiscoveryPlugin`。
- Validation:
  - `fastlane build_simulator`

## Task 2: 迁移精选到共享架构

- Status: Done
- Goal: 保持 `精选` 现有过滤、排序、缓存与 discovery plugin 能力，同时让页面本身只负责组装 datasource。
- Files likely to change:
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `BilibiliLive/Module/ViewController/FeaturedFeedCache.swift`
  - `BilibiliLive/Module/ViewController/FeaturedRanker.swift`
  - `BilibiliLive/Module/ViewController/FeaturedContentSafetyFilter.swift`
- Risks or dependencies:
  - 共享 item 结构变更后，旧缓存解码必须兼容。
  - 个性化排序和内容安全过滤不能因为重构而失效。
- Definition of done:
  - `FeaturedBrowserViewController` 只保留薄包装和 `FeaturedFeedFlowDataSource`。
  - `精选` 仍可从缓存恢复、静默刷新，并继续注入 discovery plugin。
- Validation:
  - `fastlane build_simulator`

## Task 3: 为关注接入刷视频模式和动态开关

- Status: Done
- Goal: 让 `关注` 默认进入 feed-flow 布局，并在设置页提供实时开关回退旧网格。
- Files likely to change:
  - `BilibiliLive/Module/ViewController/FollowsViewController.swift`
  - `BilibiliLive/Module/Personal/SettingsViewController.swift`
  - `BilibiliLive/Component/Settings.swift`
  - `BilibiliLive/Module/Tabbar/Notification+TabBar.swift`
  - `BilibiliLive/Component/Video/PlayInfoResolver.swift`
- Risks or dependencies:
  - `关注` 数据里存在 aid-only 和 pgc 项，进入播放器前必须补全播放信息。
  - 容器切换新旧布局时必须避免旧子控制器残留和焦点异常。
- Definition of done:
  - `关注` tab 入口稳定为容器控制器。
  - 默认启用 feed-flow，关闭开关后恢复旧网格和详情页链路。
  - aid-only / pgc 项可在 feed-flow 播放态补全播放信息。
- Validation:
  - `fastlane build_simulator`
