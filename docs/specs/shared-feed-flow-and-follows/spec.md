# Feature Spec: shared-feed-flow-and-follows

## Metadata

- Status: Implemented
- Owner:
- Related issue:
- Related ADR: `docs/adr/0002-shared-feed-flow-browser.md`
- Target build / release:

## Summary

将 `精选` 的刷视频浏览态抽象为可复用的 `FeedFlowBrowserViewController` 与 `FeedFlowDataSource` 架构，并让 `关注` 成为首个复用方。`关注` 默认以刷视频布局打开，但用户可以在设置里关闭并回退到原有网格页；`精选` 继续保留时长过滤、内容安全过滤、个性化排序、缓存，并沿用播放器统一装配的信息面板页签能力。

## Problem Statement

当前 `精选` 的刷视频能力全部堆在单个控制器里，后续页面无法低成本复用同一套浏览、预览、正式播放、返回落点与生命周期清理逻辑。与此同时，`关注` 仍停留在标准网格浏览路径，和 `精选` 的沉浸式刷视频体验割裂，也缺少一个用户可控的开关来决定是否采用新布局。

## Goals

- 抽出通用的 feed-flow 浏览框架，复用预览、正式播放、上下切换、落点恢复与清理逻辑。
- 保持 `精选` 的特有能力不回归，包括过滤、排序、缓存，以及播放器统一信息页签中的发现/互动能力。
- 为 `关注` 提供默认开启的刷视频模式，并允许在设置页动态切回旧网格。
- 保持 `关注` tab 标识稳定，不因布局切换重建 tab 项。

## Non-goals

- 不把 `精选` 的个性化排序、内容安全过滤或缓存自动推广给其他页面。
- 不重做 `关注` 旧网格页的视觉设计或详情页链路。
- 不在本期为 `关注` 新模式新增独立缓存层。

## User Flow

1. 用户进入 `精选` 或 `关注` tab。
2. 页面以左侧列表 + 背景预览的 feed-flow 浏览态展示内容；焦点停留后自动开始预览。
3. 用户按确认键进入正式播放态，并可在播放器中继续按现有 feed-flow 规则切换上一条 / 下一条。
4. 用户按 `Back / Menu` 退出播放器后，页面恢复到最后播放项并重新建立浏览态预览。
5. 用户可在设置页打开或关闭 `关注刷视频模式`；切换后返回 `关注` 时使用对应布局。

## tvOS Interaction

- Initial focus: `精选` 和 `关注` 的 feed-flow 首屏焦点都落在左侧列表当前项。
- Directional navigation: 浏览态沿用左列表纵向焦点移动；正式播放态沿用 feed-flow 既有上一条 / 下一条逻辑。
- Primary action: 浏览态确认键进入正式播放；设置页确认开关后立即切换 `关注` 布局模式。
- Back / Menu behavior: 播放态退出回浏览态；`关注` 关闭刷视频模式后恢复旧网格和详情页行为。
- App background behavior: 浏览态和播放态进入后台时都必须停止预览 / 播放并清理播放器，不允许残留声音。
- Play / Pause behavior: 沿用现有播放器行为，不新增后台播放语义。
- Long press or context menu behavior: 不新增 feed-flow 专属长按菜单。
- Accessibility or readability notes: 沿用左侧 / 底部渐变 scrim 保证动态背景上的可读性。

## UX States

- Loading: `精选` 显示“正在加载精选短视频...”；`关注` 显示“正在加载关注视频...”。
- Empty: `精选` 保留“当前精选短视频较少”；`关注` 显示“当前关注区暂无可播放视频”。
- Error: 两个页面都显示页面级错误文案，若已有内容则保留现有列表并提示后台刷新失败。
- Success: 浏览态可预览、可进入正式播放、可在退出后恢复落点。

## Data and API Considerations

- Endpoints touched:
  - `ApiRequest.getFeeds()` 继续作为 `精选` 源。
  - `WebRequest.requestFollowsFeed(offset:page:)` 继续作为 `关注` 源。
  - `WebRequest.requestCid(aid:)` 与 `WebRequest.requestBangumiInfo(...)` 现在也用于 feed-flow 内对 aid-only / pgc 项补全播放信息。
- Auth, signing, or token refresh implications: 不修改现有请求签名策略，仍沿用原有请求层。
- Pagination or caching implications:
  - `精选` 缓存继续存在，但缓存 item 改为基于共享 `FeedFlowItem` 存储。
  - `关注` 首版不加缓存，直接按 offset / page 续页。
- Logging or debug visibility: 保持现有 `Logger` 输出，不新增额外埋点。

## Technical Approach

- Existing modules and components to reuse:
  - `VideoPlayerViewController` / `VideoPlayerViewModel`
  - `PlayContextCache` / `PlayerMediaWarmupManager`
  - `VideoSequenceProvider`
  - `VideoPlayerInfoTabsPlugin`
- New types or files to add:
  - `FeedFlowBrowserViewController`
  - `FeedFlowItem`
  - `FeedFlowDataSource`
  - `FeedFlowPlayerConfiguration`
  - `PlayInfoResolver`
- Migration or compatibility concerns:
  - `FeaturedRanker` 与 `FeaturedFeedCache` 适配共享 item。
  - `关注` tab 入口改成容器，但 `TabBarPageFactory` 与 tab 身份不变。
  - `PlayInfo` 需要支持在解析阶段补全 `aid / cid / seasonId`。
  - `FeedFlowPlayerConfiguration` 继续保留为页面级扩展点，但当前 `精选` 的信息面板页签由播放器统一装配，不再由 `FeaturedFeedFlowDataSource` 单独注入。

## Impacted Areas

- `BilibiliLive/Module/ViewController/FeedFlowBrowserViewController.swift`
- `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
- `BilibiliLive/Module/ViewController/FollowsViewController.swift`
- `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
- `BilibiliLive/Component/Video/VideoPlayerViewModel.swift`
- `BilibiliLive/Component/Video/PlayContextCache.swift`
- Settings / persistence: `Settings.followsFeedFlowEnabled`, `FeaturedFeedCache`
- Build / CI / release: 无额外发布改动；使用 `fastlane build_simulator` 验证

## Risks and Open Questions

- `关注` 中存在 aid-only 和 pgc 动态，必须在播放前补全 `PlayInfo`，否则会导致播放或落点恢复异常。
- `关注` 默认开启新布局后，用户切换设置返回页面时必须避免残留旧子控制器和焦点错乱。

## Acceptance Criteria

- [x] `精选` 与 `关注` 都可以复用同一套 feed-flow 浏览骨架。
- [x] `精选` 的过滤、排序、缓存，以及统一装配的信息面板页签行为保持可用。
- [x] `关注` 默认进入刷视频布局，并可通过设置开关回退到旧网格。
- [x] `关注` 布局开关切换后不需要重启 app。
- [x] feed-flow 浏览态和播放态都定义了退出、切页和后台清理行为，不残留声音或活跃播放器。
- [x] 现有 tab 导航、`精选` 播放流和 `关注` 旧网格详情链路不回归。

## Manual Validation

- [x] `fastlane build_simulator`
- [ ] 从 `精选` 验证缓存命中、预览、进入正式播放、返回落点和后台清理不回归
- [ ] 从 `精选` 打开信息面板，验证 `博主视频` / `相关视频` / `互动` 页签仍可用
- [ ] 验证 `关注` 默认进入刷视频布局，可预览、确认进入播放、上下切换并返回当前项
- [ ] 在设置页关闭 `关注刷视频模式` 后返回 `关注`，验证旧网格与详情页链路恢复
- [ ] 在设置页重新打开 `关注刷视频模式`，验证页面切换不出现重复子控制器或焦点错乱
- [ ] 验证 `精选` 与 `关注` 在 `Back / Menu`、切后台、回前台场景下都不会残留声音
