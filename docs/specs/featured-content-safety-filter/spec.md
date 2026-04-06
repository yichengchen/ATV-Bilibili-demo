# Feature Spec: featured-content-safety-filter

## Metadata

- Status: Implemented
- Owner: Codex + project maintainers
- Related issue: N/A
- Related ADR: N/A
- Target build / release: next nightly after 2026-04-06

## Summary

为 `精选` 页增加标题关键词黑名单兜底过滤。在现有短视频时长过滤基础上，新增一层仅针对 `精选` 推荐源的文本安全过滤，优先拦截明显带有擦边导向词的短视频标题，并对 `UP` 名、推荐理由、描述文案做同层兜底；同时补充“高风险包装词 + 人设词 / 穿着词”的组合命中规则，并为 `精选` feed 缓存增加过滤规则版本，避免旧缓存绕过新规则。组合规则刻意避开普通穿搭词和普通 ASMR 类别词，保持高置信度兜底。

## Problem Statement

当前 `精选` 页只按时长和可播性筛选推荐源，没有对擦边导向标题做额外清洗。对于给儿童使用的场景，这会让明显不适合儿童浏览的短视频进入列表、预览和正式播放入口。

## Goals

- 在 `精选` 页过滤掉明显带有擦边导向词的推荐视频。
- 规则只影响 `精选`，不改动现有 `推荐`、`热门`、`排行榜`、搜索或详情页的其他入口。
- 保持 `精选` 现有焦点、预览、播放和缓存流程不回归。
- 对常见变体做归一化匹配，降低通过空格、符号、大小写拆词绕过的概率。
- 补一层组合命中规则，覆盖标题不露骨但组合语义明显偏擦边的条目。
- 避免把普通穿搭内容或普通环境音 / 白噪声音频仅因泛化标签误杀。

## Non-goals

- 不引入通用内容审核模型或在线审核服务。
- 不承诺识别所有擦边内容；本次只做高置信度文本黑名单兜底。
- 不新增用户可编辑的过滤设置页或家长模式开关。
- 不修改 `精选` 以外页面的内容过滤行为。

## User Flow

1. 用户进入 `精选`。
2. 页面拉取推荐源并继续按时长筛选短视频。
3. 在构建 `RecommendedVideoItem` 之前，检查标题、UP 主名、推荐理由和描述文案是否命中擦边关键词。
4. 命中的条目不会进入左侧列表、背景预览或正式播放序列。
5. 如果同一批源数据中过滤掉的条目较多，页面继续扫描后续推荐页；仍不足时沿用现有“当前精选短视频较少”空状态。
6. 命中过滤规则的旧缓存不会被复用，页面改为重建新列表。

## tvOS Interaction

- Initial focus: 不变，仍落在 `精选` 左侧列表第一项。
- Directional navigation: 不变，只在过滤后的结果内移动。
- Primary action: 不变，确认键进入当前过滤后条目的正式播放。
- Back / Menu behavior: 不变。
- App background behavior: 不变，浏览态预览进入后台时立即停止。
- Play / Pause behavior: 不变。
- Long press or context menu behavior: 不变。
- Accessibility or readability notes: 不新增 UI 元素；仅减少不合适内容曝光。

## UX States

- Loading: 不变，仍先加载 `精选` 数据并构建列表。
- Empty: 关键词过滤后若可用条目不足，沿用现有“当前精选短视频较少”文案。
- Error: 不变，仍沿用现有推荐加载失败文案。
- Success: `精选` 仅展示未命中关键词黑名单的短视频。

## Data and API Considerations

- Endpoints touched: 继续复用 `ApiRequest.getFeeds(lastIdx:)`，不新增接口。
- Auth, signing, or token refresh implications: 无新增签名和鉴权逻辑。
- Pagination or caching implications:
  - 推荐源仍按 `idx` 分页。
  - 关键词过滤发生在 `精选` 本地构建阶段。
  - `FeaturedFeedCacheSnapshot` 增加过滤规则版本；规则升级后旧缓存自动失效。
- Logging or debug visibility: 可复用现有日志体系，不新增埋点。

## Technical Approach

- Existing modules and components to reuse:
  - `FeaturedBrowserViewController`
  - `ApiRequest.FeedResp.Items.toRecommendedVideoItem`
  - `FeaturedFeedCache`
- New types or files to add:
  - `BilibiliLive/Module/ViewController/FeaturedContentSafetyFilter.swift`
- Migration or compatibility concerns:
  - 旧 `精选` 缓存缺少过滤规则版本时，视为失效并重建。

## Impacted Areas

- `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
- `BilibiliLive/Module/ViewController/FeaturedFeedCache.swift`
- `BilibiliLive/Module/ViewController/FeaturedContentSafetyFilter.swift`
- Settings / persistence:
  - `FeaturedBrowser.cachedSnapshot`
- Build / CI / release:
  - 无新增依赖，继续使用现有 Xcode / fastlane 流程。

## Risks and Open Questions

- 关键词黑名单会存在误杀和漏杀，只能作为高置信度兜底，不能替代完整的儿童模式。
- `精选` 推荐源当前可用字段有限，主要依赖标题和附带文本，无法识别纯封面型擦边内容。
- 过滤强度提升后，`精选` 某些时段可能更容易出现“结果较少”。

## Acceptance Criteria

- [x] `精选` 构建列表时，会过滤命中擦边关键词黑名单的短视频。
- [x] 过滤对空格、大小写、常见符号拆词有基本抗绕过能力。
- [x] 过滤规则至少检查标题，并对 `UP` 主名、推荐理由、描述文案做同层兜底。
- [x] 过滤规则包含“高风险包装词 + 人设词 / 穿着词”的组合命中。
- [x] 普通穿搭词和普通 ASMR 类别词不会单独导致 `精选` 条目被拦截。
- [x] 过滤后的列表、预览和正式播放序列保持一致，不会把被拦截视频混入播放流。
- [x] `精选` 命中过滤规则升级前的旧缓存时，不会继续展示旧结果。
- [x] `精选` 的现有焦点、预览、返回、后台停止预览等行为在代码路径上保持不变。
- [x] 现有请求、签名和播放链路不回归。

## Manual Validation

- [x] `fastlane build_simulator`
- [ ] Validate in tvOS Simulator or on device
- [ ] Verify entering `精选` only shows unblocked short videos
- [ ] Verify titles with inserted spaces / punctuation / mixed-case English variants are still blocked when they match the blacklist
- [ ] Verify `精选` 命中旧缓存后不会继续展示已应被拦截的条目
- [ ] Verify `精选` loading, success, empty, and error states still work
- [ ] Verify focus movement, preview start/stop, Back / Menu, and app background behavior do not regress
