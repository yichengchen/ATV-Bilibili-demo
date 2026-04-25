# Implementation Tasks: tv-ott-recommend-feed

- Spec: `docs/specs/tv-ott-recommend-feed/spec.md`
- Status: In progress
- Owner: Codex
- Last updated: 2026-04-11 00:30 CST

## Working Agreements

- 保持改动范围限制在 `TV推荐` 页面、`WebRequest` 新接口和对应文档，不碰 `精选` 业务逻辑。
- 复用现有 `WebRequest+WbiSign`，不新增新的 web 签名链路。
- 本功能无自动化测试，验证以 fresh build、接口探测和手工播放生命周期检查为准。

## Task 1: 同步 spec 到 web 推荐流与翻页语义

- Status: Done
- Goal: 将文档从旧 OTT 首页接口描述改写为 web 首页推荐流，并明确翻页、过滤和非目标范围。
- Files likely to change:
  - `docs/specs/tv-ott-recommend-feed/spec.md`
  - `docs/specs/tv-ott-recommend-feed/tasks.md`
- Risks or dependencies:
  - 需要清楚写明“保留 TV 推荐入口，但不再使用 OTT 接口”，避免后续实现偏离。
- Definition of done:
  - spec 和 tasks 已准确描述 `x/web-interface/wbi/index/top/feed/rcmd`、翻页策略、过滤规则和验证要求。
- Validation:
  - 文档内容与已批准计划一致。

## Task 2: 在 WebRequest 增加首页推荐请求与响应模型

- Status: Done
- Goal: 新增 `requestTopFeedRecommend(pageIndex:pageSize:)` 和 `WebTopFeedRecommendResponse`，固定分页参数并复用 WBI 签名。
- Files likely to change:
  - `BilibiliLive/Request/WebRequest.swift`
- Risks or dependencies:
  - 需要确保请求走默认 Cookie 会话，以支持登录态个性化推荐。
  - 接口允许混入非视频内容，模型需要覆盖过滤所需字段。
- Definition of done:
  - 代码可请求第一页和后续页，并解码 `item[].id/cid/goto/title/pic/owner/stat/rcmd_reason`。
- Validation:
  - 命令行探测已确认匿名态前 10 页可返回连续视频流，参数组合为 `fresh_idx/fresh_idx_1h/brush/fetch_row`。
  - `fastlane build_simulator` 已通过。

## Task 3: 将 TV 推荐数据源改为 web 推荐流并支持翻页

- Status: Done
- Goal: 重写 `TVRecommendFeedFlowDataSource`，使用 web 首页推荐接口驱动 `FeedFlow` 的首屏和 trailing prefetch。
- Files likely to change:
  - `BilibiliLive/Module/ViewController/TVRecommendBrowserViewController.swift`
- Risks or dependencies:
  - 接口没有显式 `has_more`，需要用“空页或无新视频”作为终止条件。
  - 需要严格过滤 `goto != av` 或缺少 `aid/cid` 的条目，避免把非视频内容喂给播放器。
- Definition of done:
  - `refreshFromStart()` 与 `loadMoreItems()` 都走新接口。
  - 页面文案改为通用推荐语义，不再出现“云视听首页”提示。
  - 预览和播放直接使用接口返回的 `cid`。
- Validation:
  - `fastlane build_simulator` 已通过。
  - 待手工检查首屏加载、连续翻页、预览、播放和页面退出清理行为。
