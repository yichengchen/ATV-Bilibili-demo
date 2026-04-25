# ADR 0002: Extract a shared feed-flow browser and make 关注 opt-out

## Status

Accepted

## Context

`精选` 已经具备成熟的刷视频体验，但实现集中在单个控制器中，里面同时耦合了页面来源、缓存、排序、预览、正式播放、返回落点和播放器特有扩展。这样会导致两个问题：

1. 后续页面如果想复用同类刷视频体验，只能复制 `精选` 的大块逻辑。
2. `关注` 想升级成刷视频模式时，很难在不回归 `精选` 的前提下共享同一套实现。

另外，`关注` 已经有稳定的旧网格入口，直接替换会影响一部分用户，因此新模式需要允许用户回退。

## Decision

- 新增共享的 `FeedFlowBrowserViewController`、`FeedFlowItem` 和 `FeedFlowDataSource`，把 feed-flow 浏览态与播放编排从页面来源中解耦。
- 新增 `FeedFlowPlayerConfiguration`，由页面决定是否向 feed-flow 播放态注入额外 plugin；该扩展点保留给页面定制能力，而播放器信息页签已统一通用化，不再由 `精选` 单独注入。
- `精选` 改成“薄页面 + datasource”结构，继续保留自己的过滤、排序、缓存与 discovery 行为。
- `关注` 改为稳定的 tab 容器：
  - 默认使用新的 feed-flow 子控制器。
  - 用户可通过 `Settings.followsFeedFlowEnabled` 动态切回旧网格子控制器。
- 为 feed-flow 支持的 aid-only / pgc 项补充 `PlayInfoResolver`，在进入播放链路前补全 `aid / cid / seasonId / subType`。

## Consequences

### Positive

- 后续页面可用 datasource 方式复用 feed-flow，而不是复制 `精选` 控制器。
- `精选` 特有能力继续隔离在页面侧，避免误伤其他页面。
- `关注` 可默认获得更连续的浏览体验，同时仍保留用户回退路径。

### Negative

- 浏览页与 datasource 都会维护一份 item 状态，增加了一点同步复杂度。
- `关注` feed-flow 要额外处理 aid-only / pgc 项的播放信息解析，播放链路更复杂。

## Alternatives Considered

### 1. 继续在 `FeaturedBrowserViewController` 上叠逻辑

拒绝。这样会继续扩大单控制器职责，`关注` 只能复制实现，后续其他页面仍不可复用。

### 2. 直接把 `关注` 完全替换成 feed-flow

拒绝。虽然实现简单，但缺少用户回退路径，风险高于收益。

### 3. 只抽播放器，不抽浏览页

拒绝。真正难复用的部分不仅是播放器，还包括列表焦点驱动预览、返回落点恢复和浏览态生命周期清理。
