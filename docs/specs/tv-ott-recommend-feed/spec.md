# Feature Spec: tv-ott-recommend-feed

## Metadata

- Status: In progress
- Owner: Codex
- Related issue:
- Related ADR:
- Target build / release: next development build

## Summary

新增一个独立 Tab `TV推荐`，复用现有 feed-flow 浏览、预览和播放框架，接入云视听小电视首页接口 `x/ott/autonomy/index`，将 `small_popular_ugc` 卡片映射成类似精选的推荐流。

## Problem Statement

当前项目只有 iPhone/iPad 推荐流接口驱动的 `精选` 页面，没有一个可直接调试云视听小电视首页推荐接口的独立入口。要验证 OTT 首页推荐内容和现有精选体验的差异，需要一个隔离的调试页面，并且不能污染现有 iPhone/web 请求签名链路。

## Goals

- 提供一个独立 Tab 暴露的 `TV推荐` 页面。
- 复用现有 feed-flow 列表、预览和播放体验。
- 新增独立的 TV/OTT 请求与签名层，请求 `https://app.bilibili.com/x/ott/autonomy/index`。
- 仅消费 `small_popular_ugc` 且 `jump_id > 0` 的条目，并映射为 `FeedFlowItem`。
- 为旧用户补 Tab 迁移逻辑，避免升级后丢失入口或打乱自定义布局。

## Non-goals

- 不还原云视听首页 5 大卡 + 20 小卡的混排布局。
- 不接 `x/v2/show` 兜底接口。
- 不接 `x/web-interface/wbi/index/top/feed/rcmd` 刷新流。
- 不做持久化缓存、自动刷新、时长过滤或内容安全过滤。

## User Flow

1. 用户在导航栏进入 `TV推荐` Tab。
2. 页面显示 loading，并请求 OTT 首页推荐接口。
3. 成功时展示可播放的 UGC 列表；停留可自动预览，按确认键进入视频流。
4. 如果接口成功但没有 UGC，展示 empty state；如果请求或解码失败，展示 error state。
5. 返回、切换 Tab 或 App 进入后台时，页面沿用 feed-flow 的预览和播放器清理行为，不保留残余音频或活动实例。

## tvOS Interaction

- Initial focus: 列表首项。
- Directional navigation: 左右在 Tab 间切换；页面内上下滚动列表；和 `精选` 页面一致。
- Primary action: 选中条目后进入 feed-flow 视频流。
- Back / Menu behavior: 返回上级导航或关闭当前播放，不保留预览或播放音频。
- App background behavior: 页面进入后台时中止预览与暖启动任务，不保留活跃播放器。
- Play / Pause behavior: 进入播放后沿用现有 `VideoPlayerViewController` 行为。
- Long press or context menu behavior: 本页不新增长按行为。
- Accessibility or readability notes: 标题和错误文案沿用 feed-flow 大字号布局。

## UX States

- Loading: 显示 “正在加载TV推荐...”
- Empty: 显示接口成功但无 `small_popular_ugc` 时的空态说明。
- Error: 请求失败、签名失败或解码失败时显示错误文案。
- Success: 展示 OTT UGC 列表，支持预览和播放。

## Data and API Considerations

- Endpoints touched: `GET https://app.bilibili.com/x/ott/autonomy/index`
- Auth, signing, or token refresh implications: 独立的 TV/OTT 参数补全和 APP 签名，不复用现有 `ApiRequest` / `WebRequest` 签名链路；登录态下可带 `access_key`，但不修改现有登录刷新逻辑。
- Pagination or caching implications: 第 1 版只请求一次接口，不分页，不做持久化缓存。
- Logging or debug visibility: `DEBUG` 下记录请求 endpoint、总卡片数、UGC 卡片数和失败码，便于调试接口返回。

## Technical Approach

- Existing modules and components to reuse: `FeedFlowBrowserViewController`、`FeedFlowDataSource`、`PlayInfoResolver`、现有 TabBar 工厂与设置迁移框架。
- New types or files to add:
  - `BilibiliLive/Request/TvOTTSigner.swift`
  - `BilibiliLive/Request/TvOTTApiRequest.swift`
  - `BilibiliLive/Module/ViewController/TVRecommendBrowserViewController.swift`
- Migration or compatibility concerns:
  - `TabBarPage` 新增 `tvRecommend`
  - `Settings+TabBar` schema 版本升级，并为旧默认布局插入 `TV推荐`
  - 为保持导航栏 9 项上限，旧默认布局升级时会把 `搜索` 调整回 personal 区
  - 已自定义布局的用户不改变现有顺序，只把新页面放到 personal 区

## Impacted Areas

- `BilibiliLive/Module/Tabbar/...`
- `BilibiliLive/Module/ViewController/...`
- `BilibiliLive/Request/...`
- Settings / persistence: Tab placement schema version 与迁移逻辑
- Build / CI / release: 需要通过 `fastlane build_simulator`

## Risks and Open Questions

- `x/ott/autonomy/index` 在部分场景下可能只返回大卡而没有 `small_popular_ugc`，v1 会直接进入 empty state。
- OTT 接口依赖 TV 风格 APP 签名；如果未来服务端签名规则变化，影响范围应局限在新增的 TV 请求层。

## Acceptance Criteria

- [ ] 导航栏出现独立 Tab `TV推荐`
- [ ] 页面可请求 `x/ott/autonomy/index` 并展示 `small_popular_ugc` 条目
- [ ] 接口无 UGC 时进入空态，失败时进入错误态，不崩溃
- [ ] 焦点、预览、播放与现有 `精选` 页面行为一致
- [ ] Dismiss、切 Tab 和 App 后台切换不会留下残余音频或活跃播放器
- [ ] TV 请求签名链路与现有 iPhone/web 请求链路隔离
- [ ] Tab 迁移兼容新安装、旧默认布局和已自定义布局三种情况

## Manual Validation

- [ ] `fastlane build_simulator`
- [ ] 新安装时默认导航顺序包含 `直播 -> 推荐 -> 精选 -> TV推荐 -> 热门`
- [ ] 已升级用户默认布局会自动在 `精选` 后插入 `TV推荐`，同时 `搜索` 回到 personal 区以维持 9 个导航项
- [ ] 已自定义布局用户升级后原顺序不变，`TV推荐` 出现在 personal 区
- [ ] 未登录进入 `TV推荐` 时可正确显示 loading / empty / error / success 中的实际状态
- [ ] 登录态进入 `TV推荐` 时请求参数可附带 `access_key`
- [ ] 在 `TV推荐` 中停留触发预览、确认键进入播放、Back / Menu 退出、切换 Tab、App 后台切换后无残余音频或活跃播放器
