# Implementation Tasks: featured-short-feed

- Spec: `docs/specs/featured-short-feed/spec.md`
- Status: Implemented
- Owner: Codex + project maintainers
- Last updated: 2026-04-04

## Working Agreements

- Keep each task independently reviewable.
- Prefer one focused code change per task.
- Update this file as tasks move from Todo to In progress to Done.
- Record validation next to the task that introduced the change.

## Task 1: TabBar and settings migration

- Status: Done
- Goal: 新增 `精选` Tab、放宽导航栏上限到 9，并为老用户提供 schema 迁移。
- Files likely to change:
  - `BilibiliLive/Module/Tabbar/TabBarPage.swift`
  - `BilibiliLive/Module/Tabbar/TabBarPageFactory.swift`
  - `BilibiliLive/Module/Tabbar/Settings+TabBar.swift`
  - `BilibiliLive/Module/Personal/TabBarCustomizationViewController.swift`
  - `BilibiliLive/Component/Settings.swift`
  - `BilibiliLive/Module/Personal/SettingsViewController.swift`
- Risks or dependencies:
  - 不能打乱已自定义导航用户的已有顺序。
  - 需要避免默认导航仍停留在 8 个 Tab。
- Definition of done:
  - `精选` 出现在可配置页面中。
  - 默认配置用户看到 `推荐 / 精选` 连续出现。
  - 老自定义配置用户不会被强行改写头部顺序。
  - 设置页新增“精选视频时长上限”。
- Validation:
  - `xcodebuild ... build` 通过。

## Task 2: Featured browser and short-video filtering

- Status: Done
- Goal: 实现 `精选` 左列表右预览页面，并基于推荐流按时长筛选短视频。
- Files likely to change:
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `BilibiliLive/Request/ApiRequest.swift`
  - `BilibiliLive/Module/ViewController/FeedViewController.swift`
- Risks or dependencies:
  - 推荐源里短视频比例可能不足。
  - 预览播放器与正式播放器要避免状态互相污染。
- Definition of done:
  - 左侧列表仅展示命中过滤条件的视频。
  - 右侧支持静音延迟预览和失败回退。
  - 返回 `精选` 时保持当前索引。
  - 修改时长上限后返回 `精选` 会重新构建列表。
- Validation:
  - `xcodebuild ... build` 通过。

## Task 3: Sequence playback, preloading, and recovery

- Status: Done
- Goal: 把点播 next-only 模型升级为双向序列，并补上播放预热和一次自动重试。
- Files likely to change:
  - `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewModel.swift`
  - `BilibiliLive/Component/Video/Plugins/VideoPlayListPlugin.swift`
  - `BilibiliLive/Component/Video/Plugins/BVideoPlayPlugin.swift`
  - `BilibiliLive/Component/Player/CommonPlayerViewController.swift`
  - `BilibiliLive/Component/Player/Plugins/CommonPlayerPlugin.swift`
  - `BilibiliLive/Component/Video/VideoDetailViewController.swift`
  - `BilibiliLive/Component/Video/PlayContextCache.swift`
- Risks or dependencies:
  - 播放器插件生命周期不能被预览模式破坏。
  - 详情页、分 P、合集播放也依赖播放序列。
- Definition of done:
  - 播放态 `上 / 下` 切换上一条 / 下一条。
  - 切换序列只来自过滤后列表。
  - 当前项、上一条、下一条会被预热。
  - 卡顿 / 加载失败时自动重试一次。
  - 旧详情播放链路仍能正常工作。
- Validation:
  - `xcodebuild ... build` 通过。
