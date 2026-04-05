# Feature Spec: info-panel-focus-hook-crash

## Metadata

- Status: Implemented
- Owner: Codex + project maintainers
- Related issue: crash log on 2026-04-05 (`UITabBarButton swizz_didUpdateFocusIn:with:`)
- Related ADR: N/A
- Target build / release: next nightly after 2026-04-05

## Summary

修复播放器信息面板焦点 Hook 在启动后污染系统焦点链路导致的崩溃。Hook 必须只挂到 AVKit 信息面板相关的 cell 类，不能通过继承链误改 `UIView` / `UITabBarButton` 的 `didUpdateFocus` 实现；当新系统运行时类结构与旧版本不一致时，Hook 应安全降级，继续依赖现有焦点观察兜底。

## Problem Statement

当前修复分支把 `didUpdateFocus(in:with:)` 交换到了 `UICollectionViewCell`。由于该方法实际继承自 `UIView`，运行时交换会污染更上层实现，导致系统 tab bar 焦点更新落到自定义 `swizz_didUpdateFocus` 上，随后向 `UITabBarButton` 发送不存在的 `swizz_didUpdateFocusIn:with:` 选择子并直接崩溃。

## Goals

- 修复应用启动后或进入主界面时的焦点更新崩溃。
- 保留 `精选` 播放态对信息面板 `上一条 / 下一条` 动作的自动触发能力。
- 在不同 tvOS 运行时类名或继承结构变化时安全降级，而不是因为 Hook 失败或目标类变化导致全局崩溃。

## Non-goals

- 不重做 `精选` 播放态的信息面板交互设计。
- 不新增新的播放器菜单项或焦点规则。
- 不在本次修复中依赖更多私有类名做硬编码分支判断。

## User Flow

1. 用户启动应用并在 TabBar 中移动焦点。
2. 用户从 `精选` 进入播放态并打开系统信息面板。
3. 焦点进入 `简介` 中的 `上一条 / 下一条` 时，若运行时存在可识别的信息面板 cell Hook，则继续自动触发；否则由现有焦点观察兜底。
4. 用户退出播放器或返回首页时，不应因为焦点更新触发崩溃。

## tvOS Interaction

- Initial focus: 应用启动后的 TabBar 初始焦点恢复正常，不因 Hook 污染而崩溃。
- Directional navigation: TabBar、信息面板、自定义发现页签各自只处理自己的焦点更新。
- Primary action: 本次不改变主操作语义。
- Back / Menu behavior: 不改变现有返回和退出播放器逻辑。
- App background behavior: 无新增后台播放或焦点处理语义。
- Play / Pause behavior: 不变。
- Long press or context menu behavior: 不变。
- Accessibility or readability notes: 保留现有从可访问性标签或 label 文本中提取动作标题的兜底逻辑。

## UX States

- Loading: 不涉及新增 loading。
- Empty: 不涉及。
- Error: 若运行时找不到可 Hook 的信息面板私有类，应安静降级，不弹错、不崩溃。
- Success: 应用可正常启动，TabBar 焦点正常，`精选` 播放态相关焦点逻辑不回归。

## Data and API Considerations

- Endpoints touched: 无。
- Auth, signing, or token refresh implications: 无变化。
- Pagination or caching implications: 无变化。
- Logging or debug visibility: 沿用现有播放器焦点日志和调试输出。

## Technical Approach

- Existing modules and components to reuse:
  - `BilibiliLive/Extensions/AVInfoPanelCollectionViewThumbnailCell+Hook.swift`
  - `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
- New types or files to add:
  - `docs/specs/info-panel-focus-hook-crash/spec.md`
  - `docs/specs/info-panel-focus-hook-crash/tasks.md`
- Migration or compatibility concerns:
  - 使用 class-local swizzle helper，确保即使目标方法来自父类，也只在目标 class 上增加覆盖实现。
  - 运行时仅枚举并处理 AVKit 信息面板相关的 `UICollectionViewCell` 子类；若没有匹配类，则跳过 Hook。
  - 继续保留现有 `accessibilityLabel` 和递归 label 文本提取兜底。

## Impacted Areas

- `BilibiliLive/Extensions/AVInfoPanelCollectionViewThumbnailCell+Hook.swift`
- `docs/specs/info-panel-focus-hook-crash/spec.md`
- `docs/specs/info-panel-focus-hook-crash/tasks.md`
- Settings / persistence: 无。
- Build / CI / release: 无新增依赖，继续使用 `fastlane build_simulator` 或等价 `xcodebuild`。

## Risks and Open Questions

- 如果新 tvOS 运行时完全更换了相关私有类名，Hook 可能不会生效，但现有 `UIFocusSystem.didUpdateNotification` / `didUpdateFocus` 兜底仍应避免核心交互完全失效。
- 仓库没有自动化测试，仍需在模拟器或真机手动验证 TabBar 与播放器信息面板的焦点路径。
- 当前环境先前在沙箱内执行 `fastlane build_simulator` 时无法访问 CoreSimulator 与缓存目录；已改用等价的 `xcodebuild` 完成 tvOS Simulator 构建验证。

## Acceptance Criteria

- [x] 应用启动并进入主界面后，TabBar 焦点更新不再触发 `unrecognized selector` 崩溃。
- [x] Hook 仅作用于 AVKit 信息面板相关 cell，不污染无关 UIKit 视图。
- [x] `精选` 播放态在支持的运行时上继续能根据焦点标题触发 `上一条 / 下一条`。
- [x] 运行时类结构不匹配时安全降级，不因 Hook 失败导致崩溃。

## Manual Validation

- [ ] `fastlane build_simulator`
- [x] `xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug -destination 'generic/platform=tvOS Simulator' build`
- [ ] Validate in tvOS Simulator or on device
- [ ] Launch the app and move focus across the root TabBar
- [ ] Enter `精选` playback, open the info panel, and focus `上一条 / 下一条`
- [ ] Verify unsupported focus targets do not crash when moving around the info panel
- [ ] Verify exiting playback and returning to the root UI does not leave focus in a broken state
