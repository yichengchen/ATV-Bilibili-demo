# Feature Spec: featured-short-feed

## Metadata

- Status: Implemented
- Owner: Codex + project maintainers
- Related issue: N/A
- Related ADR: `docs/adr/0001-featured-short-feed.md`
- Target build / release: next nightly after 2026-04-04

## Summary

保留现有 `推荐` 网格页，同时在其后新增 `精选` Tab。`精选` 定位为短视频浏览和连续播放入口，左侧展示过滤后的短视频列表，右侧提供静音延迟预览，进入播放后支持遥控器上下切换上一条 / 下一条，并在播放链路中补上预热和一次自动重试。

## Problem Statement

当前 `推荐` 页是标准网格流，适合逛卡片，但不适合快速刷视频。项目内原有的点播序列更多服务于分 P 和合集，只支持单向 next，无法表达“过滤后短视频列表”这一类双向连续流，也缺少针对卡顿的轻量预热能力。

## Goals

- 保留现有 `推荐` 页，不破坏已有入口和导航习惯。
- 新增 `精选` Tab，建立和 `推荐` 明确区分的短视频定位。
- `精选` 浏览态采用左列表右预览，按确认键进入正式短视频流。
- 正式短视频流支持遥控器 `上 / 下` 切换上一条 / 下一条。
- 上下切换序列严格使用过滤后的短视频列表，不混入长视频和详情相关推荐。
- 增加预览预热、上一条 / 下一条预热，以及一次自动重试。

## Non-goals

- 不替换或重写现有 `推荐` 网格页。
- 不新增新的推荐后端接口。
- 不把 `热门`、`排行榜` 等页面一起改成短视频流。
- 不重写现有 DASH 播放器和插件体系。

## User Flow

1. 用户进入头部导航中的 `精选`。
2. 页面连续拉取推荐源数据，并按时长阈值过滤出短视频列表。
3. 初始焦点落在左侧第一项，右侧在停留约 400ms 后开始静音预览。
4. 用户按确认键，从当前左侧项进入正式短视频流。
5. 在正式播放态中，用户用遥控器 `上 / 下` 在过滤后列表里切换上一条 / 下一条。
6. 用户按 `Menu / Back` 退出播放，回到 `精选`，保持当前索引和滚动位置。

## tvOS Interaction

- Initial focus: `精选` 首屏焦点落在左侧列表第一项。
- Directional navigation: 浏览态中 `上 / 下` 在左侧列表中移动；播放态中 `上 / 下` 切换上一条 / 下一条。
- Primary action: 浏览态的确认键进入正式短视频流；播放态的确认键保留给系统播放器控制层。
- Back / Menu behavior: 播放态退出回 `精选` 浏览页；浏览态遵循 TabBar 正常返回行为。
- Play / Pause behavior: 沿用系统播放器默认行为。
- Long press or context menu behavior: v1 不新增长按交互。
- Accessibility or readability notes: 右侧预览区保留标题、UP 主、提示文案，确保远距阅读。

## UX States

- Loading: 首屏加载和预览切换期间显示 loading，占位图持续可见。
- Empty: 多页过滤后仍无足够短视频时显示“当前精选短视频较少”。
- Error: 推荐加载失败时展示错误文案；预览失败仅回退到封面和提示，不阻塞进入播放。
- Success: 左侧列表、右侧预览、正式播放和上下切换均正常工作。

## Data and API Considerations

- Endpoints touched: `ApiRequest.getFeeds(lastIdx:)`、`WebRequest.requestCid`、`requestPlayUrl`、`requestPcgPlayUrl`、`requestPlayerInfo`、`requestDetailVideo`。
- Auth, signing, or token refresh implications: 继续沿用现有请求层和签名逻辑，不引入新签名流程。
- Pagination or caching implications:
  - `精选` 按 `idx` 分页。
  - 初次进入最多扫描 5 页推荐源数据，以收集至少 12 条符合阈值的视频。
  - 剩余条目少于 8 条时继续后台补页。
  - 新增内存级 `PlayContextCache` 缓存 `cid / playUrl / playerInfo / detail`。
- Logging or debug visibility: 沿用现有播放器和请求日志，新增流程不引入额外埋点系统。

## Technical Approach

- Existing modules and components to reuse:
  - `FeedViewController` 继续作为旧 `推荐` 页。
  - `VideoPlayerViewController`、`VideoPlayerViewModel`、`CommonPlayerViewController` 继续承担正式播放职责。
  - `ApiRequest.getFeeds()` 继续作为 `精选` 的内容来源。
- New types or files to add:
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `BilibiliLive/Component/Video/PlayContextCache.swift`
  - `VideoSequenceProvider`
  - `VideoPlayerMode`
- Migration or compatibility concerns:
  - TabBar schema 从 8 项升级到 9 项。
  - 老默认配置用户会自动获得 `精选`；已自定义导航的用户保持原顺序，并在 personal 区域获得 `精选`。
  - 详情页 / 分 P / 合集共用新的双向序列模型，但不改变原有进入方式。

## Impacted Areas

- `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
- `BilibiliLive/Module/Tabbar/TabBarPage.swift`
- `BilibiliLive/Module/Tabbar/Settings+TabBar.swift`
- `BilibiliLive/Module/Personal/SettingsViewController.swift`
- `BilibiliLive/Component/Video/...`
- `BilibiliLive/Request/ApiRequest.swift`
- Settings / persistence:
  - `Settings.featuredDurationLimit`
  - `Settings.tabBarPagePlacementsSchemaVersion`
- Build / CI / release:
  - 无新增依赖，继续使用现有 Xcode / fastlane 流程。

## Risks and Open Questions

- 预览和正式播放共用请求链路，但预览仍需要真实拉流，弱网下首屏预览体验可能波动。
- `精选` 目前仍基于推荐流过滤短视频，推荐源里短视频密度不足时会出现“结果较少”。
- 自动重试只做一次，未覆盖更复杂的 CDN / 码率回退策略。

## Acceptance Criteria

- [x] 保留现有 `推荐` 网格页。
- [x] 头部导航新增 `精选`，默认位于 `推荐` 之后。
- [x] 已自定义导航的老用户升级后不会被强制改写头部顺序。
- [x] `精选` 页面为左列表右预览结构。
- [x] 左侧列表仅包含符合当前时长阈值的短视频。
- [x] 设置页修改“精选视频时长上限”后，返回 `精选` 会按新阈值重建列表。
- [x] 浏览态焦点停留约 400ms 后启动静音预览。
- [x] 播放态遥控器 `上 / 下` 能切换上一条 / 下一条。
- [x] 播放态上下切换序列只在过滤后列表内移动。
- [x] 当前视频开始播放后，会后台预热上一条 / 下一条。
- [x] 播放卡住或加载失败时，会自动重试一次；仍失败再给出重试 / 下一条。
- [x] 现有详情页、旧推荐页和其他导航页不回归。

## Manual Validation

- [ ] `fastlane build_simulator`
- [x] `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build`
- [ ] Validate in tvOS Simulator or on device
- [ ] Exercise loading, success, empty, and error states
- [ ] Verify focus movement, back navigation, preview behavior, and player up/down switching
- [ ] Verify old `推荐` page,详情页,分 P / 合集播放 do not regress
