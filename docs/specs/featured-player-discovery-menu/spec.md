# Feature Spec: featured-player-discovery-menu

## Metadata

- Status: Implemented
- Owner: Codex + project maintainers
- Related issue: N/A
- Related ADR: N/A
- Target build / release: next nightly after 2026-04-05

## Summary

在 `精选` 播放态的系统信息面板中，新增两个独立发现页签：`博主视频` 与 `推荐视频`。每个页签最多展示 6 个横向视频卡片，选中后不改写原始精选短视频队列，而是把选中的视频作为当前槽位的临时覆盖项播放；用户通过 `上 / 下`、自动播完或直接退出播放器时，仍以原始精选队列为准恢复前后关系和浏览态落点。
同时，`精选` 播放态不再依赖播放器表层直接拦截 `上 / 下` 键切视频；切换入口收敛到 `简介` 中的 `上一条 / 下一条` 动作，焦点到达即触发，而 `博主视频`、`推荐视频` 等自定义内容内的方向键只用于页签导航。

## Problem Statement

当前 `精选` 播放态只有“上一条 / 下一条 / 查看详情”等基础动作。用户如果想继续探索当前博主的其他视频或与当前视频相关的推荐内容，必须先退出播放或跳详情页，路径过长，也会打断正在进行的短视频流浏览。

## Goals

- 仅在 `精选` 播放态提供 `博主视频` / `推荐视频` 两个发现页签。
- 菜单点击后立即播放选中视频，同时不污染原始精选队列。
- 支持连续从临时视频再次选择临时视频。
- 退出播放器后，精选页仍回到原始精选项而不是临时视频。

## Non-goals

- 不改详情页、分 P、合集或普通视频播放模式。
- 不把临时视频真正插入精选列表或持久化到缓存中。
- 不新增推荐后端接口或新的排序策略。

## User Flow

1. 用户从 `精选` 页面进入正式播放态。
2. 用户按下键打开系统信息面板，在顶部页签中看到 `博主视频` 和 `推荐视频`。
3. 任一页签内横向展示最多 6 个视频卡片，卡片尺寸与系统 `简介 / 章节` 内容区保持接近。
4. 用户选中其中一条后，播放器立即切到该视频播放，但精选原始队列位置保持不变。
5. 用户可在临时视频中再次打开任一发现页签，继续跳转新的临时视频。
6. 用户按 `上 / 下` 或当前临时视频自然播完后，播放器清空临时覆盖链，返回原始精选队列的上一条 / 下一条。
7. 用户直接退出播放器时，精选页焦点回到原始精选项。

## tvOS Interaction

- Initial focus: 不改变 `精选` 浏览态和播放态默认焦点。
- Directional navigation: 播放器主画面的 `上 / 下` 不再作为切视频主路径；临时视频播放期间，`简介` 中的 `上一条 / 下一条` 仍沿用原始精选队列，不遍历临时链。
- Directional navigation in info panel: 当焦点进入 `简介` 中的 `上一条 / 下一条` 动作时立即切换视频；当焦点进入自定义发现页签内容时，方向键仅驱动当前页签焦点移动，不触发精选序列切换。
- Primary action: 在 `博主视频` 或 `推荐视频` 页签里选中某条视频后立即播放该视频。
- Back / Menu behavior: 从临时视频退出播放器后，浏览态回原始精选项。
- App background behavior: 沿用现有 `精选` 播放态行为，不新增后台播放语义。
- Play / Pause behavior: 沿用现有播放器能力，不新增特殊暂停逻辑。
- Long press or context menu behavior: v1 不新增长按交互。
- Accessibility or readability notes: 页签标题直接区分 `博主视频` 与 `推荐视频`，避免单页签内混合来源带来的理解成本。

## UX States

- Loading: `推荐视频` 可立即显示；`博主视频` 异步加载成功后刷新对应页签，不展示 loading 占位项。
- Empty: 若当前视频没有可用候选，则对应页签展示空态文案。
- Error: 博主视频请求失败时仅让 `博主视频` 页签显示空态，不阻塞当前播放和 `推荐视频` 页签显示。
- Success: `博主视频` 与 `推荐视频` 作为两个独立页签展示单行横向滚动卡片，卡片尺寸与系统 `简介 / 章节` 内容区保持接近，临时播放和回原队列行为符合预期。

## Data and API Considerations

- Endpoints touched: `requestDetailVideo`、`ApiRequest.requestUpSpaceVideo(mid:lastAid:pageSize:)`。
- Auth, signing, or token refresh implications: 继续复用现有请求签名与鉴权流程。
- Pagination or caching implications:
  - 博主视频只请求首页候选并按现有“最新发布”顺序截取最多 6 条。
  - 临时覆盖项不写回 `VideoSequenceProvider.playSeq`，只保存在内存中的临时覆盖链。
  - `推荐视频` 直接使用当前 `VideoDetail.Related`，按现有返回顺序截取最多 6 条，不新增缓存层。
- Logging or debug visibility: 继续沿用现有播放器和请求日志。

## Technical Approach

- Existing modules and components to reuse:
  - `VideoSequenceProvider` 继续作为精选播放队列模型。
  - `VideoPlayerViewModel` 继续负责生成播放器插件和切换视频。
  - `VideoPlayListPlugin` 继续负责上一条 / 下一条 / 查看详情。
- New types or files to add:
  - `BilibiliLive/Component/Video/Plugins/FeaturedVideoDiscoveryPlugin.swift`
- Migration or compatibility concerns:
  - 仅在 `playMode == .feedFlow` 挂载新插件。
  - 不修改现有设置项和持久化结构。

## Impacted Areas

- `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
- `BilibiliLive/Component/Video/VideoPlayerViewModel.swift`
- `BilibiliLive/Component/Video/Plugins/...`
- `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
- Settings / persistence: 无新增设置或迁移。
- Build / CI / release: 无新增依赖，继续使用现有 tvOS 构建流程。

## Risks and Open Questions

- 博主视频入口依赖额外异步请求；如果用户很快打开菜单，可能先看到推荐项，随后再刷新出博主项。
- 临时视频不在精选列表中时，需要始终回退到原始 `currentIndex`，避免浏览态错误对齐到不存在的项。
- `简介` 的 action cell 需要稳定区分 `上一条 / 下一条` 与 `从头开始`，否则焦点即触发会误伤系统默认动作。

## Acceptance Criteria

- [x] 仅 `精选` 播放流新增 `博主视频` 与 `推荐视频` 两个页签，普通播放器不受影响。
- [x] `博主视频` 和 `推荐视频` 页签内各最多显示 6 条横向卡片。
- [x] 点击任一发现页签中的视频后立即播放该视频，不把它写入精选原始队列。
- [x] 临时视频中再次打开发现页签时，会按当前正在播放的视频重新计算候选。
- [x] 临时视频按 `上 / 下` 或播完后，会回到原始精选队列的前后邻居。
- [x] 从临时视频直接退出播放器后，精选页焦点仍回原始精选项。
- [x] 博主视频请求失败或候选不足时不会阻塞播放，也不会显示占位假数据。
- [x] 发现页签内容按横向卡片布局展示，视觉尺寸与系统 `简介 / 章节` 内容区保持接近。
- [x] 当焦点位于发现页签卡片内时，方向键只移动页签内焦点，不会同时切换底层精选视频。
- [x] `简介` 中的 `上一条 / 下一条` 在焦点到达时立即切换视频，不需要再次点击。
- [x] `从头开始` 保持系统默认行为，不会因为焦点移动被自动触发。
- [x] 原有 `查看详情`、`上一条 / 下一条`、倍速、画质、弹幕菜单不回归。

## Manual Validation

- [x] `fastlane build_simulator`
- [ ] Validate in tvOS Simulator or on device
- [ ] From `精选`, open the player info panel and verify `博主视频` and `推荐视频` tabs appear next to `简介`
- [ ] Verify each discovery tab shows up to 6 horizontal cards sized close to system content tabs
- [ ] Select a discovery card and verify immediate playback without changing featured queue order
- [ ] From a temporary video, reopen the discovery tabs and verify entries refresh based on the current video
- [ ] Verify focusing `简介` 里的 `上一条 / 下一条` from a temporary video goes to the original featured previous / next item
- [ ] Verify when focus is inside a discovery tab card, `上 / 下` does not switch the underlying featured video
- [ ] Verify direct `上 / 下` on the player surface no longer switches featured videos
- [ ] Verify focusing `简介` 的 `从头开始` does not auto-trigger playback restart
- [ ] Verify playback end on a temporary video advances to the original featured next item
- [ ] Verify dismissing from a temporary video returns focus to the original featured list item
- [ ] Verify uploader request failure still keeps the `推荐视频` tab available and lets `博主视频` show an empty state
- [ ] Verify existing featured playback controls and non-featured video flows do not regress
