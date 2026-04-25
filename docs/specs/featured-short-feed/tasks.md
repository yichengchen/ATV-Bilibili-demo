# Implementation Tasks: featured-short-feed

- Spec: `docs/specs/featured-short-feed/spec.md`
- Status: Done
- Owner: Codex + project maintainers
- Last updated: 2026-04-04

## Working Agreements

- Keep each task independently reviewable.
- Prefer one focused code change per task.
- Update this file as tasks move from Todo to In progress to Done.
- Record validation next to the task that introduced the change.

## Task 1: TabBar and settings migration

- Status: Done
- Goal: 新增 `精选` Tab、放宽导航栏上限到 9，并为老用户提供 schema 迁移。
- Files likely to change:
  - `BilibiliLive/Module/Tabbar/TabBarPage.swift`
  - `BilibiliLive/Module/Tabbar/TabBarPageFactory.swift`
  - `BilibiliLive/Module/Tabbar/Settings+TabBar.swift`
  - `BilibiliLive/Module/Personal/TabBarCustomizationViewController.swift`
  - `BilibiliLive/Component/Settings.swift`
  - `BilibiliLive/Module/Personal/SettingsViewController.swift`
- Risks or dependencies:
  - 不能打乱已自定义导航用户的已有顺序。
  - 需要避免默认导航仍停留在 8 个 Tab。
- Definition of done:
  - `精选` 出现在可配置页面中。
  - 默认配置用户看到 `推荐 / 精选` 连续出现。
  - 老自定义配置用户不会被强行改写头部顺序。
  - 设置页新增“精选视频时长上限”。
- Validation:
  - `xcodebuild ... build` 通过。

## Task 4: Featured preview audio cleanup

- Status: Done
- Goal: 修复 `精选` 从正式播放退出后仍有后台声音的问题，并确保浏览态预览清理正确。
- Files likely to change:
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `BilibiliLive/Component/Player/CommonPlayerViewController.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewModel.swift`
  - `BilibiliLive/Component/Video/Plugins/BVideoPlayPlugin.swift`
  - `docs/specs/featured-short-feed/spec.md`
- Risks or dependencies:
  - 预览播放器是子控制器，移除时必须主动清理 `AVPlayer`，否则可能继续在后台持有音频。
  - 不能影响详情页和普通点播的有声播放行为。
- Definition of done:
  - 浏览态预览不会残留后台声音。
  - 进入正式播放前会停掉并销毁预览播放器。
  - 从正式播放返回 `精选` 后，不会残留后台声音。
  - 返回浏览态时仍能恢复当前项预览。
- Validation:
  - `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build` 通过。
  - 本地未安装 `fastlane`，未执行 `fastlane build_simulator`。

## Task 5: Feed-flow action ordering and labels

- Status: Done
- Goal: 保持精选播放态沿用系统信息面板交互，同时修复面板中“上一条 / 下一条”顺序与方向认知不一致的问题，并让按钮文案显式表达方向。
- Files likely to change:
  - `BilibiliLive/Component/Video/Plugins/VideoPlayListPlugin.swift`
  - `docs/specs/featured-short-feed/spec.md`
  - `docs/specs/featured-short-feed/tasks.md`
- Risks or dependencies:
  - 需要保持精选短视频流和详情页/合集复用同一插件时的行为一致。
  - 不能把 `playerDidEnd()` 的自动下一条语义改反。
- Definition of done:
  - 系统信息面板仍保留“从头开始”默认入口。
  - 系统动作面板优先展示“下一条”，其次才是“上一条”。
  - 按钮标题显式带有方向前缀，不再只显示视频名。
  - 面板动作与用户对“下一条 / 上一条”的方向认知保持一致。
- Validation:
  - `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build` 通过。

## Task 2: Featured browser and short-video filtering

- Status: Done
- Goal: 实现 `精选` 左列表右预览页面，并基于推荐流按时长筛选短视频。
- Files likely to change:
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `BilibiliLive/Request/ApiRequest.swift`
  - `BilibiliLive/Module/ViewController/FeedViewController.swift`
- Risks or dependencies:
  - 推荐源里短视频比例可能不足。
  - 预览播放器与正式播放器要避免状态互相污染。
- Definition of done:
  - 左侧列表仅展示命中过滤条件的视频。
  - 右侧支持静音延迟预览和失败回退。
  - 返回 `精选` 时保持当前索引。
  - 修改时长上限后返回 `精选` 会重新构建列表。
- Validation:
  - `xcodebuild ... build` 通过。

## Task 3: Sequence playback, preloading, and recovery

- Status: Done
- Goal: 把点播 next-only 模型升级为双向序列，并补上播放预热和一次自动重试。
- Files likely to change:
  - `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewModel.swift`
  - `BilibiliLive/Component/Video/Plugins/VideoPlayListPlugin.swift`
  - `BilibiliLive/Component/Video/Plugins/BVideoPlayPlugin.swift`
  - `BilibiliLive/Component/Player/CommonPlayerViewController.swift`
  - `BilibiliLive/Component/Player/Plugins/CommonPlayerPlugin.swift`
  - `BilibiliLive/Component/Video/VideoDetailViewController.swift`
  - `BilibiliLive/Component/Video/PlayContextCache.swift`
- Risks or dependencies:
  - 播放器插件生命周期不能被预览模式破坏。
  - 详情页、分 P、合集播放也依赖播放序列。
- Definition of done:
  - 播放态 `上 / 下` 切换上一条 / 下一条。
  - 切换序列只来自过滤后列表。
  - 当前项、上一条、下一条会被预热。
  - 卡顿 / 加载失败时自动重试一次。
  - 旧详情播放链路仍能正常工作。
- Validation:
  - `xcodebuild ... build` 通过。

## Task 6: Featured return-state sync after sequence switching

- Status: Done
- Goal: 修复 `精选` 正式播放中切到上一条 / 下一条后返回浏览页仍停留在旧项的问题，并避免列表异步重建时恢复索引触发越界崩溃。
- Files likely to change:
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `docs/specs/featured-short-feed/spec.md`
  - `docs/specs/featured-short-feed/tasks.md`
- Risks or dependencies:
  - 返回浏览态时不仅要同步索引，还要同步列表焦点、当前项视觉状态和滚动位置。
  - 不能破坏已有的预览恢复逻辑，也不能影响初次进入 `精选` 的焦点行为。
- Definition of done:
  - 播放态切到上一条 / 下一条后，退出时浏览态会对齐到最后播放项。
  - 当前项高亮和可见卡片高亮不会残留在旧项上。
  - 右侧恢复的预览与最后播放项一致。
  - 切回 `精选` 时，即使列表还在异步补数或重建，也不会因为恢复选中项导致 collection view 越界断言。
- Validation:
  - `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build` 通过。
  - 当前环境未安装 `fastlane`，因此未执行 `fastlane build_simulator`。

## Task 7: Immersive full-screen preview upgrade

- Status: Done
- Goal: 将精选页右侧卡片式预览改为全屏视频背景 + 左侧列表悬浮结构，预览延迟从 400ms 改为 1s 有声预览，补上立即停旧预览防串音。
- Files changed:
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `BilibiliLive/Component/Player/CommonPlayerViewController.swift`
  - `BilibiliLive/Component/Player/Plugins/CommonPlayerPlugin.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewModel.swift`
  - `BilibiliLive/Component/Video/Plugins/BVideoPlayPlugin.swift`
  - `docs/specs/featured-short-feed/spec.md`
  - `docs/specs/featured-short-feed/tasks.md`
- Key changes:
  - 移除 `previewCardView`，`previewPlaceholderView` 作为 `previewHostView` 的底层封面，视频层始终在封面之上。
  - 新增 `leftGradientScrimView`（alpha 0.35 -> 0.0）和 `bottomGradientScrimView`（0.0 -> 0.55）。
  - 右侧信息改为 `infoOverlayView` 浮层（右下角）。
  - `preloadDelayNs` 从 `400_000_000` 改为 `1_000_000_000`。
  - `schedulePreview()` 在 cancel previewTask 后立即调用 `removePreviewController()` 杜绝串音。
  - 新增 `previewMuted` 参数穿透 `VideoPlayerViewController -> VideoPlayerViewModel -> BVideoPlayPlugin`。
  - `installPreviewController` 传 `previewMuted: false` 实现有声预览。
  - 预览开始前保留封面和 loading；收到真实播放开始回调后，封面淡出、视频淡入。
  - 播放器 teardown 新增 `playerWillCleanUp(playerVC:)`，并给 `BVideoPlayPlugin` 补上可取消的加载任务和 generation token，避免退出后旧任务把声音挂回来。
  - 提示文案改为"停留后自动预览"。
- Risks or dependencies:
  - 有声预览会抢占 Audio Session，和正式播放行为一致。
  - 列表在全屏视频背景上的可读性依赖渐变 scrim + blur cell，需实机确认。
- Definition of done:
  - 全屏封面 + 1s 后有声预览。
  - 快速切换不串音。
  - 焦点切走时旧预览立即停止。
  - 进入正式播放不会叠音。
  - 返回浏览态恢复预览。
  - 弱网 / 失败时保留封面不黑屏。
  - 旧推荐页、详情页不回归。
- Validation:
  - `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build` 通过。
  - 手工验证未完成，需在 tvOS Simulator 或真机确认“有画面、无串音、退出即停”。

## Task 8: Featured list metadata polish

- Status: Done
- Goal: 精简精选左侧列表的当前项文案，并把视频时长移到缩略图左下角，减少文字噪音。
- Files changed:
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `docs/specs/featured-short-feed/spec.md`
  - `docs/specs/featured-short-feed/tasks.md`
- Risks or dependencies:
  - 不能影响当前项同步逻辑，只调整列表视觉表达。
  - 时长角标需要在聚焦和未聚焦状态下都保持可读。
- Definition of done:
  - 左侧列表不再显示 `当前` 两字。
  - 标题下方元信息不再重复展示时长。
  - 视频时长固定显示在缩略图左下角。
  - 现有聚焦态和当前项同步行为不回归。
- Validation:
  - 当前环境未安装 `fastlane`，因此未执行 `fastlane build_simulator`。
  - `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build` 通过。

## Task 9: Featured playback warmup and cache layering

- Status: Done
- Goal: 为精选浏览态和正式播放态拆分播放请求策略，引入更轻量的预览链路、可复用的媒体级预热、共享 DASH 索引缓存，以及带 TTL 的精选 feed 结果缓存。
- Files changed:
  - `BilibiliLive/Request/WebRequest.swift`
  - `BilibiliLive/Component/Video/PlayContextCache.swift`
  - `BilibiliLive/Component/Video/PlayerMediaWarmup.swift`
  - `BilibiliLive/Component/Player/BilibiliVideoResourceLoaderDelegate.swift`
  - `BilibiliLive/Component/Video/Plugins/BVideoPlayPlugin.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewModel.swift`
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `BilibiliLive/Module/ViewController/FeaturedFeedCache.swift`
  - `docs/specs/featured-short-feed/spec.md`
  - `docs/specs/featured-short-feed/tasks.md`
  - `docs/adr/0001-featured-short-feed.md`
- Key changes:
  - 新增 `PlayURLRequestOptions`，让精选预览走较低画质、优先 SDR、关闭高成本能力的请求参数；正式播放保留原最高画质默认值。
  - `PlayContextCache` 按 `preview / regular` 模式缓存并发加载结果，`preview` 只缓存播放必要上下文，不再拉详情，同时把裁剪策略放宽为“小型 LRU + 当前窗口保活”。
  - 新增 `PlayerMediaWarmupManager`，在浏览态预览稳定开始后优先预热当前条、下一条、上一条的正式播放媒体，并在进入正式播放时尽量复用已准备好的 `AVURLAsset` 与 loader delegate。
  - `SidxDownloader` 改为跨预览 / 正式播放共享的有限容量缓存，避免同一 DASH 资源反复解析索引。
  - `FeaturedBrowserViewController` 新增 15 分钟 TTL 的精选 feed 快照缓存，进入页面优先展示上次成功过滤结果，再后台静默刷新；变更时长阈值后会自动失效。
  - 精选尾部补量改为增量追加，不再因为后台补数对整个列表做 `reloadData()`。
- Risks or dependencies:
  - 预览降画质是明确取舍，需确认弱网下体感收益明显且不会影响用户对正式播放画质的预期。
  - 媒体预热若和当前播放争抢带宽，应优先保证正式播放，必要时可只保留接口级预热。
  - feed 快照缓存只用于在线体验优化，不保证离线可用；缓存 miss 或过期后必须完整回退到现有网络加载链路。
- Definition of done:
  - 浏览态预览不再复用正式播放的最高画质请求。
  - 正式播放切入和上下切换能复用邻近项的上下文或媒体预热结果。
  - 预览 / 正式播放之间可共享 DASH 索引缓存。
  - 再次进入精选时，有有效快照就先展示上次结果并后台刷新。
  - 调整“精选视频时长上限”后，不会复用旧阈值缓存。
  - 尾部补数时不会因整表刷新导致焦点抖动。
- Validation:
  - 当前环境未安装 `fastlane`，因此未执行 `fastlane build_simulator`。
  - `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build` 通过。
  - 手工验证未完成，需在 tvOS Simulator 或真机确认“缓存命中秒开、预览更快出首帧、切上下条更顺、快速切焦点不串音”。

## Task 10: Featured preview-to-playback progress handoff

- Status: Done
- Goal: 修复 `精选` 当前项预览已开始播放后，按确认键进入正式播放仍从 0 秒开始的问题，让全屏播放从预览进度无缝接续。
- Files changed:
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `BilibiliLive/Component/Player/CommonPlayerViewController.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewModel.swift`
  - `docs/specs/featured-short-feed/spec.md`
  - `docs/specs/featured-short-feed/tasks.md`
- Risks or dependencies:
  - 只应把当前预览项的进度交给正式播放，不能把旧预览或其他条目的时间错传给新视频。
  - 预览到正式播放的同会话 handoff 不能被“从上次退出的位置继续播放”设置误伤。
- Definition of done:
  - 当前项预览已开始播放时，按确认键进入正式播放会从预览秒数继续播放。
  - 当前项预览尚未真正开始时，按确认键仍从 0 秒正常进入正式播放。
  - 关闭“从上次退出的位置继续播放”后，预览到正式播放的 handoff 仍然生效。
  - 不影响详情页、合集播放和已有的历史续播逻辑。
- Validation:
  - `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build` 通过。
  - 手工验证未完成，需在 tvOS Simulator 或真机确认“预览播 2-3 秒后进入全屏从同一位置继续播放”。

## Task 11: Featured preview app-background cleanup

- Status: Done
- Goal: 修复 `精选` 浏览态预览在按 Home / 切后台离开 app 后仍继续出声的问题，并在回前台后保持现有 1 秒延迟预览行为。
- Files changed:
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `docs/specs/featured-short-feed/spec.md`
  - `docs/specs/featured-short-feed/tasks.md`
- Risks or dependencies:
  - 只能在 `精选` 浏览态处理这个自动预览生命周期，不能误伤正式播放态或切换中的 present/dismiss 时序。
  - 回前台后应恢复原有 1 秒延迟规则，不能直接无延迟出声。
- Definition of done:
  - `精选` 浏览态正在预览时按 Home / 切后台，音频会立即停止。
  - 回到前台且仍停留在 `精选` 浏览态时，当前项会按 1 秒规则恢复预览。
  - 进入正式播放或其他页面时，不会因为前后台通知把列表页预览错误恢复出来。
- Validation:
  - `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build` 通过。
  - 手工验证未完成，需在 tvOS Simulator 或真机确认“精选预览中按 Home 后立即静音，回前台 1 秒后才恢复当前项预览”。
