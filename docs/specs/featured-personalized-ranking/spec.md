# Feature Spec: featured-personalized-ranking

## Metadata

- Status: Implemented
- Owner: Codex + project maintainers
- Related issue: review hardening for uncommitted personalized-ranking patch
- Related ADR: N/A
- Target build / release: next nightly after 2026-04-05

## Summary

为 `精选` 页面增加可开关的智能排序能力。系统会基于历史记录和当前会话内的正向观看信号，对拉取到的精选候选集做轻量重排；当历史请求失败、画像不可用或样本不足时，页面必须自动回退到原始精选顺序，不能阻塞加载或错误归因播放信号。

## Problem Statement

当前精选页按推荐源原始顺序展示短视频，缺少面向个人兴趣的轻量排序能力。新增排序后，如果历史记录请求失败会直接卡住精选页，而播放信号如果在播放器切换和退出时序中采集错误，则会污染画像，导致排序结果越来越偏离真实兴趣。

## Goals

- 为 `精选` 提供可开关的个性化重排，不改动默认关闭时的行为。
- 基于历史记录和会话内正向观看信号生成轻量兴趣画像。
- 历史请求失败、缓存缺失或样本不足时自动回退到原始精选顺序，不能阻塞页面。
- 观看信号只归因到真实播放过的 item，并覆盖切换上一条/下一条和直接退出播放器两种路径。

## Non-goals

- 不引入新的推荐后端接口。
- 不对 `推荐`、`热门`、`排行榜` 等其他页面做个性化排序。
- 不新增服务端埋点或账号同步画像。

## User Flow

1. 用户在设置页打开“精选智能排序”。
2. 用户进入 `精选`，页面优先读取本地 feed 快照和兴趣画像缓存。
3. 若需要刷新画像，则后台请求历史记录；成功时构建画像并重排候选集，失败时直接沿用原始精选顺序继续加载。
4. 用户进入正式播放态并上下切换视频，系统在真实播放项结束或切换时记录正向观看信号。
5. 用户按 `Back / Menu` 退出播放器后返回 `精选`，列表和后续补量继续使用当前会话增强后的画像，但不会因退出时序漏记或错记。

## tvOS Interaction

- Initial focus: 不改变 `精选` 既有默认焦点行为。
- Directional navigation: 浏览态和播放态沿用 `精选` 现有方向键语义。
- Primary action: 浏览态确认键进入正式播放态，不改变现有 handoff。
- Back / Menu behavior: 退出正式播放时应先记录当前真实播放项的观看时长，再清理播放器并回到浏览态。
- App background behavior: 沿用现有 `精选` 浏览态/播放态生命周期，不引入后台播放语义。
- Play / Pause behavior: 智能排序不改变 AVPlayer 的播放控制语义。
- Long press or context menu behavior: 不新增。
- Accessibility or readability notes: 不改变现有 UI 文案和视觉层级，仅新增设置项开关。

## UX States

- Loading: `精选` 首屏或静默刷新时可后台刷新画像，但不能因为画像接口失败一直停在 loading。
- Empty: 继续沿用 `精选` 原有空态。
- Error: 历史画像请求失败时不弹新错误，页面继续展示原始精选顺序；精选源本身失败时沿用原有错误态。
- Success: 开关开启且画像可用时应用重排；画像不可用或样本不足时展示原始顺序但页面仍然正常可用。

## Data and API Considerations

- Endpoints touched: `https://api.bilibili.com/x/v2/history`、`ApiRequest.getFeeds(lastIdx:)`。
- Auth, signing, or token refresh implications: 沿用现有请求层和 cookie/session 机制，不新增签名流程。
- Pagination or caching implications:
  - 个性化 feed 快照需要按账号、开关状态和排序算法版本隔离。
  - 兴趣画像缓存需要按账号和排序算法版本隔离，并带 TTL。
  - 历史接口失败时必须回退，不能让 continuation 永久挂起。
- Logging or debug visibility: 沿用现有请求失败日志，不新增埋点。

## Technical Approach

- Existing modules and components to reuse:
  - `FeaturedBrowserViewController`
  - `FeaturedFeedCache`
  - `VideoPlayerViewController`
  - `WebRequest.requestHistory`
- New types or files to add:
  - `FeaturedInterestProfile.swift`
  - `FeaturedInterestProfileCache.swift`
  - `FeaturedRanker.swift`
- Migration or compatibility concerns:
  - 新增 `Settings.featuredPersonalizedRankingEnabled`，默认 `false`。
  - 旧 feed 快照和旧画像缓存需要兼容缺省字段或自然失效。

## Impacted Areas

- `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
- `BilibiliLive/Module/ViewController/FeaturedFeedCache.swift`
- `BilibiliLive/Module/ViewController/FeaturedInterestProfile.swift`
- `BilibiliLive/Module/ViewController/FeaturedInterestProfileCache.swift`
- `BilibiliLive/Module/ViewController/FeaturedRanker.swift`
- `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
- `BilibiliLive/Request/WebRequest.swift`
- Settings / persistence:
  - `Settings.featuredPersonalizedRankingEnabled`
  - featured feed snapshot cache
  - featured interest profile cache
- Build / CI / release:
  - 无新增依赖，继续使用现有 Xcode / fastlane 流程。

## Risks and Open Questions

- 历史记录样本较少时，排序只能做弱个性化，需避免过度抖动原始顺序。
- 会话增强信号目前只使用正向观看时长，不包含负反馈，后续若扩展要确保与当前缓存版本兼容。

## Acceptance Criteria

- [x] 设置页提供“精选智能排序”开关，默认关闭时不改变既有精选行为。
- [x] 开关开启时，精选可以使用历史画像和会话信号对候选集重排。
- [x] 历史画像请求失败时，精选页不会卡在 loading，而是自动回退到原始顺序继续展示。
- [x] 样本不足或画像不可用时，不应用重排但页面仍正常可用。
- [x] 播放态切换上一条 / 下一条时，观看时长只归因到真实播放过的旧 item。
- [x] 直接退出播放态时，当前真实播放项的观看时长会在播放器清理前记录。
- [x] 画像缓存和 feed 快照按账号、开关状态和算法版本隔离，不串账号和旧排序版本。
- [x] 现有精选预览、正式播放、返回落点和播放器清理行为不回归。

## Manual Validation

- [x] `fastlane build_simulator`
- [ ] Validate in tvOS Simulator or on device
- [ ] 在关闭“精选智能排序”时验证精选顺序与改动前一致
- [ ] 在开启“精选智能排序”且有历史样本时验证首屏会发生轻量重排
- [ ] 模拟历史接口失败，确认精选仍能完成加载并展示原始顺序
- [ ] 在播放态快速 `上 / 下` 连跳后退出，确认只记录真实播放项，不出现错位归因
- [ ] 在播放首条后直接 `Back / Menu` 退出，确认退出路径也能记录观看信号
- [ ] Verify dismiss / Back / Menu, switching away from the page, and Home / app background do not leave audio or player instances running unless the spec explicitly allows background playback
