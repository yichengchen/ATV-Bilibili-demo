# ADR 0001: Keep 推荐 grid and add a separate 精选 short-feed flow

- Status: Accepted
- Date: 2026-04-04
- Related spec: `docs/specs/featured-short-feed/spec.md`
- Related issue: N/A

## Context

项目已有 `推荐` 网格页，适合浏览卡片，但它和“短视频连续刷”的体验目标不同。产品上希望引入更接近云视听 / 抖音流的短视频入口，同时保持旧 `推荐` 页可用。技术上，现有播放器能力较完整，但播放序列主要服务于 next-only 场景，不足以表达过滤后的双向短视频流。

## Decision

保留现有 `推荐` 网格页，并在其后新增独立的 `精选` Tab。`精选` 使用推荐接口过滤出短视频，采用独立的浏览态和正式播放态。正式播放继续复用现有 DASH 播放链路和播放器插件体系，但通过新的 `VideoSequenceProvider`、`VideoPlayerMode`、按模式区分的 `PlayContextCache`、`PlayerMediaWarmupManager` 和共享 `SidxDownloader` 支撑短视频流的上下切换、预热和失败恢复。浏览态预览明确采用低成本请求配置，优先秒开和稳定性，而不是复用正式播放的最高画质请求。

## Alternatives Considered

- 直接把现有 `推荐` 页改成短视频流:
  - 会破坏当前网格浏览入口，也让两个产品定位混在一起。
- 在详情页里硬加一个推荐流模式:
  - 容易和详情页、相关推荐、分 P / 合集职责混淆，导航和返回路径都更复杂。
- 新写一套完全独立的播放器:
  - 代价高，且会绕开现有 DASH、弹幕、画质和 SponsorBlock 能力。

## Consequences

### Positive

- `推荐` 和 `精选` 的定位清晰分离。
- 现有播放器链路被复用，减少了重写风险。
- 双向序列模型也能服务详情页的分 P / 合集播放，减少重复逻辑。
- 通过分层缓存和媒体级预热改善短视频切换与弱网场景体验。
- 通过共享 `Sidx` 缓存和 feed 快照缓存，减少重复索引解析和冷启动空白等待。

### Negative

- TabBar schema 需要迁移，导航配置逻辑更复杂。
- 预览仍依赖真实拉流，弱网时不一定完全平滑。
- 预览低画质和后台预热是明确取舍，需要接受“预览画质次于正式播放”的体验策略。
- 播放器、TabBar、设置和详情页同时受影响，联动面较广。

## Rollout and Follow-up

- Migration steps:
  - 将默认导航 schema 升级到 9 项。
  - 老默认配置用户自动获得 `精选`。
  - 已自定义导航的用户保留原顺序，并在 personal 区域获得 `精选`。
- Validation plan:
  - 先通过 `xcodebuild` / `fastlane build_simulator` 验证编译。
  - 在 tvOS Simulator 或真机上验证焦点、预览、上下切换和返回路径。
- Follow-up work:
  - 评估是否需要把媒体级预热进一步细化到更积极的码率回退和带宽预算控制。
  - 视体验需要补充更丰富的短视频信息层和可视化状态。
