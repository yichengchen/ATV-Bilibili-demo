# Implementation Tasks: featured-personalized-ranking

- Spec: `docs/specs/featured-personalized-ranking/spec.md`
- Status: Implemented
- Owner: Codex + project maintainers
- Last updated: 2026-04-05

## Working Agreements

- Keep each task independently reviewable.
- Prefer one focused code change per task.
- Update this file as tasks move from Todo to In progress to Done.
- Record validation next to the task that introduced the change.
- For playback or audio-related work, make teardown and lifecycle cleanup explicit in either a task goal, risk, or definition of done.

## Task 1: Add personalized ranking model and persistence

- Status: Done
- Goal: 为精选增加可开关的兴趣画像、排序器、画像缓存和 feed 快照隔离。
- Files likely to change:
  - `BilibiliLive/Component/Settings.swift`
  - `BilibiliLive/Module/Personal/SettingsViewController.swift`
  - `BilibiliLive/Module/ViewController/FeaturedFeedCache.swift`
  - `BilibiliLive/Module/ViewController/FeaturedInterestProfile.swift`
  - `BilibiliLive/Module/ViewController/FeaturedInterestProfileCache.swift`
  - `BilibiliLive/Module/ViewController/FeaturedRanker.swift`
- Risks or dependencies:
  - 需要保持默认关闭时与现有精选顺序完全兼容。
  - 需要兼容旧缓存缺少新字段的情况。
- Definition of done:
  - 设置项存在并默认关闭。
  - 画像和 feed 缓存按账号、开关和排序版本隔离。
  - 样本不足时不应用重排。
- Validation:
  - `fastlane build_simulator` 通过。
  - 手工验证待完成。

## Task 2: Keep Featured loading responsive when profile refresh fails

- Status: Done
- Goal: 历史画像请求失败时回退到原始精选顺序，不能让精选页卡住。
- Files likely to change:
  - `BilibiliLive/Request/WebRequest.swift`
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
- Risks or dependencies:
  - 不能改变已有历史页等调用方的成功路径。
  - 失败回退不能影响精选源本身的错误态展示。
- Definition of done:
  - `requestHistory` 有明确失败分支。
  - 精选页在画像请求失败时仍会完成首屏刷新。
- Validation:
  - `fastlane build_simulator` 通过。
  - 网络失败回退需手工验证。

## Task 3: Attribute watch signals to the actual playing item

- Status: Done
- Goal: 修复精选播放态在切换和退出时的观看时长归因，确保只记录真实播放项且退出前不漏报。
- Files likely to change:
  - `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
- Risks or dependencies:
  - 不能破坏现有 `onPlayInfoChanged`、返回落点和播放器销毁时序。
  - 需要兼容连续快速切换和直接退出两条路径。
- Definition of done:
  - 切换上一条 / 下一条时，旧 item 的观看时长来自真实正在播放的 item。
  - `Back / Menu` 退出时在 `super.viewDidDisappear` 清理播放器前记录当前播放项。
- Validation:
  - `fastlane build_simulator` 通过。
  - 播放链路归因需手工验证。
