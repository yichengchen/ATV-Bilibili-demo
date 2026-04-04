# Feature Spec: featured-short-feed

## Metadata

- Status: Implemented
- Owner: Codex + project maintainers
- Related issue: N/A
- Related ADR: `docs/adr/0001-featured-short-feed.md`
- Target build / release: next nightly after 2026-04-04

## Summary

保留现有 `推荐` 网格页，同时在其后新增 `精选` Tab。`精选` 定位为短视频浏览和连续播放入口，全屏视频做背景、左侧列表悬浮在视频上方，焦点停留 1 秒后自动开始有声预览，进入播放后支持遥控器上下切换上一条 / 下一条，并在播放链路中补上预热和一次自动重试。

## Problem Statement

当前 `推荐` 页是标准网格流，适合逛卡片，但不适合快速刷视频。项目内原有的点播序列更多服务于分 P 和合集，只支持单向 next，无法表达“过滤后短视频列表”这一类双向连续流，也缺少针对卡顿的轻量预热能力。

## Goals

- 保留现有 `推荐` 页，不破坏已有入口和导航习惯。
- 新增 `精选` Tab，建立和 `推荐` 明确区分的短视频定位。
- `精选` 浏览态采用左列表右预览，按确认键进入正式短视频流。
- 正式短视频流支持遥控器 `上 / 下` 切换上一条 / 下一条。
- 上下切换序列严格使用过滤后的短视频列表，不混入长视频和详情相关推荐。
- 增加预览预热、上一条 / 下一条预热，以及一次自动重试。
- 预览链路优先秒开，允许为平滑度降低画质上限和高成本流能力。

## Non-goals

- 不替换或重写现有 `推荐` 网格页。
- 不新增新的推荐后端接口。
- 不把 `热门`、`排行榜` 等页面一起改成短视频流。
- 不重写现有 DASH 播放器和插件体系。

## User Flow

1. 用户进入头部导航中的 `精选`。
2. 页面连续拉取推荐源数据，并按时长阈值过滤出短视频列表。
3. 初始焦点落在左侧第一项，全屏显示封面，停留约 1 秒后开始有声预览，视频做全屏背景并带有 crossfade 过渡。
4. 焦点切到新 item 时，立即停止旧预览并切换封面（crossfade），重新计时 1 秒后才开始新预览。快速切换时只看到封面切换、不会出声。
5. 用户按确认键，从当前左侧项进入正式短视频流，同时销毁浏览态预览，避免后台继续出声。
6. 在正式播放态中，用户按下键调出系统信息面板，并从面板中选择“从头开始 / 下一条 / 上一条”等动作。
7. 用户在正式播放态中通过 `上 / 下` 或系统信息面板切换到上一条 / 下一条后，当前播放项立即成为短视频流的新当前位置。
8. 用户按 `Menu / Back` 退出播放，回到 `精选`，列表焦点、当前项视觉状态和滚动位置都对齐到最后播放的视频，并按 1 秒规则恢复该项的有声预览。

## tvOS Interaction

- Initial focus: `精选` 首屏焦点落在左侧列表第一项。
- Directional navigation: 浏览态中 `上 / 下` 在左侧列表中移动；播放态保持系统播放器默认方向键行为。
- Info panel actions: 播放态下滑出的系统动作面板优先展示“下一条”，其后才是“上一条”，并显式带上方向前缀，和 `下 / 上` 切换方向保持一致。
- Primary action: 浏览态的确认键进入正式短视频流；播放态的确认键保留给系统播放器控制层。
- Back / Menu behavior: 播放态退出回 `精选` 浏览页；浏览态遵循 TabBar 正常返回行为。
- Play / Pause behavior: 浏览态预览为有声自动播放（焦点停留 1 秒后触发）；正式播放态沿用系统播放器默认行为。
- Long press or context menu behavior: v1 不新增长按交互。
- Accessibility or readability notes: 全屏视频背景上叠加左侧渐变 scrim 和底部渐变 scrim，右下角保留标题、UP 主、提示文案，确保远距阅读。左侧列表 cell 保持 blur 背景，不再显示 `当前` 文案，时长固定展示在缩略图左下角。

## UX States

- Loading: 首屏加载和预览切换期间显示 loading，占位图持续可见，直到视频真正开始播放或失败回退。
- Empty: 多页过滤后仍无足够短视频时显示“当前精选短视频较少”。
- Error: 推荐加载失败时展示错误文案；预览失败仅回退到封面和提示，不阻塞进入播放。
- Success: 左侧列表、右侧预览、正式播放和上下切换均正常工作，退出正式播放后不会残留后台声音，且浏览态能准确回到最后播放项；切回 `精选` 时不会因为异步补数和索引恢复的时序问题触发列表越界崩溃。

## Data and API Considerations

- Endpoints touched: `ApiRequest.getFeeds(lastIdx:)`、`WebRequest.requestCid`、`requestPlayUrl`、`requestPcgPlayUrl`、`requestPlayerInfo`、`requestDetailVideo`。
- Auth, signing, or token refresh implications: 继续沿用现有请求层和签名逻辑，不引入新签名流程。
- Pagination or caching implications:
  - `精选` 按 `idx` 分页。
  - 初次进入最多扫描 5 页推荐源数据，以收集至少 12 条符合阈值的视频。
  - 剩余条目少于 8 条时继续后台补页。
  - 新增按模式区分的 `PlayContextCache`：预览缓存低成本 `cid / playUrl / playerInfo`，正式播放缓存完整 `cid / playUrl / playerInfo / detail`。
  - 预览播放请求使用单独的低成本配置，优先 SDR、降低画质上限、关闭高成本能力；正式播放继续保留最高画质请求能力。
  - 新增 `PlayerMediaWarmupManager`，在浏览态和播放态预热当前 / 下一条 / 上一条的正式播放媒体，并支持取消和淘汰。
  - `SidxDownloader` 升级为跨预览 / 正式播放共享的有限容量缓存。
  - `精选` 持久化最近一次成功过滤后的 feed 快照（含 `lastSourceIdx` 和时长阈值），命中缓存时先展示旧结果，再后台静默刷新。
- Logging or debug visibility: 沿用现有播放器和请求日志，新增流程不引入额外埋点系统。

## Technical Approach

- Existing modules and components to reuse:
  - `FeedViewController` 继续作为旧 `推荐` 页。
  - `VideoPlayerViewController`、`VideoPlayerViewModel`、`CommonPlayerViewController` 继续承担正式播放职责。
  - `ApiRequest.getFeeds()` 继续作为 `精选` 的内容来源。
- New types or files to add:
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `BilibiliLive/Component/Video/PlayContextCache.swift`
  - `BilibiliLive/Component/Video/PlayerMediaWarmup.swift`
  - `BilibiliLive/Module/ViewController/FeaturedFeedCache.swift`
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
- 媒体级预热如果在弱网下抢占带宽，优先保障当前正式播放和当前预览，后台预热允许被取消。
- `精选` 目前仍基于推荐流过滤短视频，推荐源里短视频密度不足时会出现“结果较少”。
- 自动重试只做一次，未覆盖更复杂的 CDN / 码率回退策略。

## Acceptance Criteria

- [x] 保留现有 `推荐` 网格页。
- [x] 头部导航新增 `精选`，默认位于 `推荐` 之后。
- [x] 已自定义导航的老用户升级后不会被强制改写头部顺序。
- [x] `精选` 页面为全屏视频背景 + 左侧列表悬浮结构，带左侧和底部渐变 scrim。
- [x] 左侧列表仅包含符合当前时长阈值的短视频。
- [x] 左侧列表不显示 `当前` 文案，视频时长以角标形式固定在缩略图左下角。
- [x] 设置页修改“精选视频时长上限”后，返回 `精选` 会按新阈值重建列表。
- [x] 浏览态焦点停留约 1 秒后启动有声预览，预览以全屏背景视频呈现并带有 crossfade 过渡。
- [x] 焦点切到新 item 时立即停止旧预览（音频立即中断），封面以 crossfade 切换，重新计时。
- [x] 预览播放请求默认使用低成本配置，不复用正式播放的最高画质请求。
- [x] 进入正式播放或离开 `精选` 时，会停止并销毁当前预览播放器，不保留后台声音。
- [x] 播放态按下键会打开系统信息面板，并保留系统默认的“从头开始”入口。
- [x] 播放态系统动作面板中的“下一条 / 上一条”顺序和文案与 `下 / 上` 切换方向一致。
- [x] 播放态通过系统动作面板切换序列时，只在过滤后列表内移动。
- [x] 播放态通过 `上 / 下` 或系统动作面板切到新视频后退出，浏览态会把焦点、当前项视觉状态和滚动位置同步到最后播放项。
- [x] `精选` 在异步重建列表或补数期间切回页面时，不会因为恢复当前索引而选中越界项。
- [x] 当前视频开始播放后，会后台预热当前条、下一条和上一条，并优先复用正式播放链路。
- [x] `SidxDownloader` 在预览和正式播放之间共享缓存，不再为同一条流重复解析索引。
- [x] `精选` 命中短 TTL feed 缓存时先展示旧列表，再后台静默刷新；时长阈值变更后缓存自动失效。
- [x] 播放卡住或加载失败时，会自动重试一次；仍失败再给出重试 / 下一条。
- [x] 现有详情页、旧推荐页和其他导航页不回归。

## Manual Validation

- [ ] `fastlane build_simulator`
- [x] `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build`
- [ ] Validate in tvOS Simulator or on device
- [ ] Exercise loading, success, empty, and error states
- [ ] Verify cold-entering `精选` with cached data shows the old list immediately and refreshes in background without focus jumps
- [ ] Verify focus movement, back navigation, immersive preview with audio after 1s dwell, no audio bleed on fast switching, and player info panel behavior
- [ ] Verify preview uses a lower-cost stream while formal playback still exposes full quality options
- [ ] Verify entering formal playback from the current featured item feels faster after a short dwell
- [ ] Verify the playback info panel lists `下一条` before `上一条` and uses the correct direction labels
- [ ] Verify `下键` in featured playback first opens the system info panel and still shows `从头开始`
- [ ] Verify exiting featured playback never leaves background audio running
- [ ] Verify switching to `上一条 / 下一条` in featured playback and exiting returns focus, current-item highlight, and scroll position to the last played item
- [ ] Verify repeated preview -> formal playback -> next item switching reuses warmup without regressions after cache eviction
- [ ] Verify the featured list no longer shows the `当前` text and that duration stays at the thumbnail bottom-left
- [ ] Verify switching back to `精选` while the list is reloading never crashes with an out-of-bounds selection assertion
- [ ] Verify old `推荐` page,详情页,分 P / 合集播放 do not regress
