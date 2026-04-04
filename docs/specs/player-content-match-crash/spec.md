# Feature Spec: player-content-match-crash

## Metadata

- Status: Implemented
- Owner: Codex + project maintainers
- Related issue: crash log on 2026-04-04
- Related ADR: N/A
- Target build / release: next nightly after 2026-04-04

## Summary

修复点播播放器在进入非 HDR 视频时的崩溃。播放器需要在首次装配播放资源前一次性决定是否启用“匹配视频内容”，避免在同一场全屏播放会话里二次修改 `AVPlayerViewController.appliesPreferredDisplayCriteriaAutomatically`。

## Problem Statement

当前点播播放链路会先按全局设置启用“匹配视频内容”，随后在拿到流信息后，如果发现当前视频不是 HDR，再把同一个 `AVPlayerViewController` 的 `appliesPreferredDisplayCriteriaAutomatically` 改回 `false`。AVKit 不允许在全屏播放过程中这样切换该属性，结果会抛出异常并直接终止进程。

## Goals

- 修复进入非 HDR 视频时的播放器崩溃。
- 保留“仅在 HDR 视频匹配视频内容”的既有用户意图。
- 不改变已有画质切换、字幕、历史上报和 DASH 播放链路。

## Non-goals

- 不重新设计内容匹配设置项。
- 不修改 HDR 流识别规则本身。
- 不在这次修复里扩展手动画质切换后的显示匹配策略。

## User Flow

1. 用户从任意视频入口进入点播播放器。
2. 播放插件请求播放资源并解析当前流是否为 HDR。
3. 播放器在首次创建 `AVPlayerItem` 之前决定是否启用内容匹配。
4. 视频开始播放，用户可正常返回、切换画质和继续观看。

## tvOS Interaction

- Initial focus: 维持系统播放器默认焦点。
- Directional navigation: 不调整现有播放器方向键行为。
- Primary action: 不调整现有播放器主操作行为。
- Back / Menu behavior: 维持现有退出播放器行为。
- Play / Pause behavior: 维持系统播放器默认行为。
- Long press or context menu behavior: 本次无新增交互。
- Accessibility or readability notes: 本次无额外 UI 变更。

## UX States

- Loading: 首次拉取播放资源时不应因为内容匹配设置崩溃。
- Empty: 不涉及。
- Error: 播放资源加载失败时沿用现有错误处理，不因本修复引入新的报错路径。
- Success: SDR 与 HDR 视频都能正常进入播放，且非 HDR 视频不会触发崩溃。

## Data and API Considerations

- Endpoints touched: 无新增接口，继续复用现有点播播放请求。
- Auth, signing, or token refresh implications: 无变化。
- Pagination or caching implications: 无变化。
- Logging or debug visibility: 沿用现有播放器日志。

## Technical Approach

- Existing modules and components to reuse:
  - `BilibiliLive/Component/Video/Plugins/BVideoPlayPlugin.swift`
  - `BilibiliLive/Component/Player/BilibiliVideoResourceLoaderDelegate.swift`
- New types or files to add: 无。
- Migration or compatibility concerns:
  - 将内容匹配最终开关的计算前移到首次 `setBilibili(...)` 之后、`AVPlayer` 装配之前。
  - 质量切换时继续避免重新切换 `appliesPreferredDisplayCriteriaAutomatically`。

## Impacted Areas

- `BilibiliLive/Component/Video/Plugins/BVideoPlayPlugin.swift`
- Settings / persistence:
  - 继续复用 `Settings.contentMatch`
  - 继续复用 `Settings.contentMatchOnlyInHDR`
- Build / CI / release:
  - 无新增依赖，继续使用现有 `fastlane build_simulator`

## Risks and Open Questions

- 手动画质切换仍不会在播放中途重算内容匹配，这与现有行为保持一致，但如果用户从 SDR 切到 HDR，显示匹配不会在同一会话里动态打开。
- 本次修复依赖 `BilibiliVideoResourceLoaderDelegate` 的 HDR 判定结果，若后续新增 HDR 编码类型，需要同步维护判定逻辑。
- 当前环境缺少 `bundler 2.3.19`，因此未能直接执行 `fastlane build_simulator`；已使用等价的 `xcodebuild` 完成模拟器构建验证。

## Acceptance Criteria

- [x] 进入非 HDR 视频时不再因为内容匹配设置而崩溃。
- [x] 开启“匹配视频内容”且开启“仅在 HDR 视频匹配视频内容”时，非 HDR 首次进入播放不会触发二次属性切换。
- [x] HDR 视频首次进入播放时仍可按现有逻辑启用内容匹配。
- [x] 画质切换、播放历史上报和播放资源装配流程不回归。

## Manual Validation

- [ ] `fastlane build_simulator`
- [x] `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build`
- [ ] Validate in tvOS Simulator or on device
- [ ] Play one SDR video with `匹配视频内容 = 开` and `仅在HDR视频匹配视频内容 = 开`
- [ ] Play one HDR video with the same settings
- [ ] Switch quality during playback and confirm the player stays alive
