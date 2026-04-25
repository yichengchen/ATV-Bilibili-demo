# Feature Spec: tv-ott-recommend-feed

## Metadata

- Status: In progress
- Owner: Codex
- Related issue:
- Related ADR:
- Target build / release: next development build

## Summary

保留独立 Tab `TV推荐` 和现有 `FeedFlow` 浏览、预览、播放框架，但将数据源切换为 web 首页推荐接口 `x/web-interface/wbi/index/top/feed/rcmd`，并支持连续翻页加载。

## Problem Statement

当前 `TV推荐` 仍基于旧的 OTT 首页接口 `x/ott/autonomy/index` 和 `/x/v2/show` 兜底。这套接口返回内容偏旧、分页能力差，和当前云视听推荐页的实际视频流不匹配，也无法满足“像精选一样持续往下刷推荐视频”的目标。

## Goals

- 保持独立 Tab `TV推荐` 的入口和现有 `FeedFlow` 交互不变。
- 改用 `https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd` 提供推荐视频流。
- 支持在 `FeedFlow` 中连续翻页，接近尾部时自动拉取下一页。
- 仅展示可播放视频卡片，复用接口返回的 `aid/cid` 直接进入预览和播放。
- 不改动 `精选`、播放器架构、Tab 结构或现有 WBI 之外的请求签名链路。

## Non-goals

- 不还原云视听首页的沉浸式布局或栏目页结构。
- 不展示直播、边栏、OGV、广告或其他非普通视频卡片。
- 不新增“换一换”按钮、持久化缓存、自动刷新、时长过滤或内容安全过滤。
- 不删除已存在的 `TvOTTApiRequest` / `TvOTTSigner` 文件，只停止 `TV推荐` 对它们的依赖。

## User Flow

1. 用户在导航栏进入 `TV推荐` Tab。
2. 页面显示 loading，并请求 web 首页推荐接口第一页。
3. 成功时展示推荐视频列表；停留可自动预览，按确认键进入视频流。
4. 当焦点接近尾部或播放链路需要更多条目时，页面自动请求下一页推荐视频。
5. 如果接口成功但没有可展示视频，展示 empty state；如果请求、签名或解码失败，展示 error state。
6. 返回、切换 Tab 或 App 进入后台时，页面沿用现有 `FeedFlow` 的预览和播放器清理行为，不保留残余音频或活动实例。

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

- Loading: 显示“正在加载推荐视频...”
- Empty: 接口成功但当前无可展示推荐视频时显示通用空态说明。
- Error: 请求失败、WBI 失败或解码失败时显示错误文案。
- Success: 展示 web 推荐视频列表，支持预览、播放和连续翻页。

## Data and API Considerations

- Endpoint touched: `GET https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd`
- Auth, signing, or token refresh implications: 复用现有 `WebRequest` 和 `WebRequest+WbiSign`；登录态使用当前 Cookie 获取个性化推荐，游客态也允许获取匿名推荐，不引入新的 token 或 appkey 签名链路。
- Pagination or caching implications:
  - 请求参数固定为 `fresh_type=4`
  - `ps=12`
  - `fresh_idx=pageIndex`
  - `fresh_idx_1h=pageIndex`
  - `brush=pageIndex`
  - `fetch_row=1 + (pageIndex - 1) * 12`
  - `web_location=1430650`
  - 不做持久化缓存；分页耗尽条件为“接口返回空 item”或“过滤去重后没有新视频”
- Logging or debug visibility: `DEBUG` 下记录请求页号、原始条目数、过滤后可展示视频数和累计去重数，便于排查翻页行为。

## Technical Approach

- Existing modules and components to reuse: `FeedFlowBrowserViewController`、`FeedFlowDataSource`、`VideoSequenceProvider`、`PlayInfoResolver`、现有 TabBar 工厂与设置迁移逻辑。
- New or changed request types:
  - `WebRequest.requestTopFeedRecommend(pageIndex:pageSize:)`
  - `WebTopFeedRecommendResponse`
- `TVRecommendFeedFlowDataSource` 维护独立分页状态：
  - `nextPageIndex`
  - `hasMore`
  - `seenItemKeys`
  - `items`
- 数据过滤规则：
  - 仅接受 `goto == "av"`
  - `id > 0`
  - `cid > 0`
  - 标题非空
- 数据映射规则：
  - `aid = id`
  - `cid = cid`
  - `title = title`
  - `ownerName = owner.name`
  - `coverURL = pic`
  - `avatarURL = owner.face`
  - `duration = duration`
  - `durationText = TimeInterval(duration).timeString()`
  - `viewCountText = stat.view.numberString()`
  - `danmakuCountText = stat.danmaku.numberString()`
  - `reasonText = rcmd_reason.content`
  - `identityKey = aid`

## Impacted Areas

- `BilibiliLive/Request/WebRequest.swift`
- `BilibiliLive/Module/ViewController/TVRecommendBrowserViewController.swift`
- `docs/specs/tv-ott-recommend-feed/...`
- Build / CI / release: 需要通过 `fastlane build_simulator`

## Risks and Open Questions

- 该接口虽然当前匿名态前多页都返回普通视频，但文档允许混入直播和 OGV；本页会直接过滤这些内容。
- 接口没有显式 `has_more`，当前实现以“空页或无新视频”作为分页终止条件。
- 如果 WBI key 或 `w_webid` 获取链路失效，会直接影响该页加载，但影响范围应局限在 `WebRequest` 的 web 请求层。

## Acceptance Criteria

- [ ] `TV推荐` 继续作为独立 Tab 暴露
- [ ] 页面改用 `x/web-interface/wbi/index/top/feed/rcmd`
- [ ] 首屏能展示推荐视频，且条目使用接口自带 `cid` 进入预览和播放
- [ ] 接近尾部时能自动翻到下一页，至少连续拿到前 3 页且无重复
- [ ] 非视频卡片不会出现在 `TV推荐` 页面
- [ ] 接口空结果时进入空态，失败时进入错误态，不崩溃
- [ ] 焦点、预览、播放与现有 `精选` 页面行为一致
- [ ] Dismiss、切 Tab 和 App 后台切换不会留下残余音频或活跃播放器
- [ ] `精选` 的接口与行为不受影响

## Manual Validation

- [ ] `fastlane build_simulator`
- [ ] 未登录进入 `TV推荐` 时，首屏能加载约 12 条推荐视频
- [ ] 在 `TV推荐` 中连续向下移动，页面会自动翻页并连续拿到前 3 页，无重复条目
- [ ] 登录态进入 `TV推荐` 时可正常加载，不再出现 OTT `-663` 鉴权错误
- [ ] 在 `TV推荐` 中停留触发预览、确认键进入播放、上下切下一条、Back / Menu 退出、切换 Tab、App 后台切换后无残余音频或活跃播放器
- [ ] 断网或接口失败时能稳定显示错误态
- [ ] `精选` 页面入口、列表、预览和播放行为保持原样
