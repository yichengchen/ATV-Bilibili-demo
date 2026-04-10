# Implementation Tasks: tv-ott-recommend-feed

- Spec: `docs/specs/tv-ott-recommend-feed/spec.md`
- Status: In progress
- Owner: Codex
- Last updated: 2026-04-09 23:00 CST

## Working Agreements

- 保持请求层、页面层和 Tab 迁移分步提交，便于单独 review。
- TV 签名和请求逻辑必须限制在新增文件内，不修改现有 `ApiRequest` / `WebRequest` 公共链路。
- 本功能无自动化测试，验证以 `fastlane build_simulator` 和手工播放生命周期检查为准。

## Task 1: 补齐规范文档与实现边界

- Status: Done
- Goal: 记录独立 Tab、TV 请求层、空态/错误态、焦点和播放生命周期的预期行为。
- Files likely to change:
  - `docs/specs/tv-ott-recommend-feed/spec.md`
  - `docs/specs/tv-ott-recommend-feed/tasks.md`
- Risks or dependencies:
  - 需要明确 v1 不做 fallback 和混排，以免实现范围漂移。
- Definition of done:
  - spec 与 tasks 已创建，并覆盖用户流、tvOS 交互、接口与迁移约束。
- Validation:
  - 文档与已批准计划一致。

## Task 2: 实现独立的 TV OTT 请求与模型

- Status: Done
- Goal: 新增 `TvOTTSigner` 和 `TvOTTApiRequest`，接通 `x/ott/autonomy/index` 并提供最小可用的解码模型。
- Files likely to change:
  - `BilibiliLive/Request/TvOTTSigner.swift`
  - `BilibiliLive/Request/TvOTTApiRequest.swift`
- Risks or dependencies:
  - TV APP 签名参数需要与 `android_tv_yst` 对齐。
  - 接口可能返回无 UGC 的合法空结果。
- Definition of done:
  - 代码可请求接口，能把响应解码为卡片模型，并在 `DEBUG` 下输出关键调试日志。
- Validation:
  - 本地命令行已按 `android_tv_yst` APP 签名验证 `x/ott/autonomy/index` 可返回 `code == 0`。
  - Xcode 构建验证受 SwiftPM 依赖拉取阻塞，待补。

## Task 3: 新增页面并接入独立 Tab

- Status: In progress
- Goal: 新建 `TVRecommendBrowserViewController` 与 `TVRecommendFeedFlowDataSource`，并把 `tvRecommend` 接入 Tab 工厂和设置迁移。
- Files likely to change:
  - `BilibiliLive/Module/ViewController/TVRecommendBrowserViewController.swift`
  - `BilibiliLive/Module/Tabbar/TabBarPage.swift`
  - `BilibiliLive/Module/Tabbar/TabBarPageFactory.swift`
  - `BilibiliLive/Module/Tabbar/Settings+TabBar.swift`
- Risks or dependencies:
  - 需要保证旧默认布局和自定义布局迁移行为不同。
  - `cid` 为空时预览与播放必须依赖现有 resolver 补齐。
- Definition of done:
  - 导航栏出现 `TV推荐`，页面可展示 OTT UGC 流或对应空态/错误态。
  - `loadMoreItems()` 返回空数组，不伪造分页。
- Validation:
  - 代码已接入，待 `fastlane build_simulator`
  - 待手工检查 Tab 顺序、页面焦点、预览与播放生命周期。
