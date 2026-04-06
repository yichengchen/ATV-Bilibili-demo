# Feature Spec: player-info-discovery-actions

## Metadata

- Status: Implemented
- Owner: Codex + project maintainers
- Related issue: N/A
- Related ADR: N/A
- Target build / release: next nightly after 2026-04-06

## Summary

将播放器系统信息面板中的发现能力从 `精选` 播放态扩展为普通视频播放器通用能力，并新增 `互动` 页签。普通 AV/UGC 视频播放时固定提供 `博主视频`、`相关视频`、`互动` 三个页签；发现项点击后沿用现有临时覆盖播放语义，不污染原始播放序列；互动页签复用详情页已有关注、点赞、收藏接口与状态逻辑。

## Problem Statement

当前 `博主视频` / `推荐视频` 只在 `精选` 播放态可见，普通视频播放中用户若想继续探索当前博主视频或相关视频，仍需退出播放进入详情页。与此同时，播放态缺少与详情页一致的轻量互动入口，导致关注、点赞、收藏必须跳详情页才能完成。

## Goals

- 在所有非预览、非 bangumi/PGC 的普通视频播放器中统一提供 `博主视频` / `相关视频` / `互动` 三个页签。
- 发现页签在存在原始序列时继续采用临时覆盖播放，不改写原始序列。
- 互动页签复用详情页已有接口和视觉风格，支持关注博主、点赞视频、收藏视频。

## Non-goals

- 不覆盖 bangumi/PGC 播放器。
- 不把发现页签选中的视频真正插入原始播放队列。
- 不新增接口、设置项、持久化结构或后台播放能力。

## User Flow

1. 用户从 `精选`、视频详情页、分 P、合集等普通视频入口进入播放器。
2. 用户打开系统信息面板，在顶部看到 `博主视频`、`相关视频`、`互动` 页签。
3. 用户在发现页签中选中视频后立即切换播放；若当前播放器带原始序列，则切换仅作为临时覆盖。
4. 用户在 `互动` 页签中按确认键执行关注、点赞或收藏操作。
5. 用户按 Back/Menu 退出播放器后，仍回到原始详情页或原始 feed 项。

## tvOS Interaction

- Initial focus: 保持播放器和信息面板现有默认焦点，不新增自动触发动作。
- Directional navigation: 页签内容内方向键只驱动各自 collection view 焦点，不触发互动动作。
- Primary action: 发现页签确认键切视频；互动页签确认键执行对应动作。
- Back / Menu behavior: 沿用现有播放器退出逻辑，不新增中间确认页。
- App background behavior: 沿用现有播放器清理和后台行为，不新增后台播放语义。
- Play / Pause behavior: 沿用现有播放器逻辑。
- Long press or context menu behavior: v1 不新增长按交互。
- Accessibility or readability notes: 文案统一使用 `相关视频`，避免与详情页或旧实现混用 `推荐视频`。

## UX States

- Loading: `相关视频` 立即使用当前详情数据；`博主视频` 异步加载成功后刷新对应页签；`互动` 初始先展示详情返回的计数，再异步补齐点赞/收藏状态。
- Empty: `博主视频` 或 `相关视频` 无可用候选时，各自显示空态文案。
- Error: 博主视频请求失败时仅影响 `博主视频` 页签；点赞状态 / 收藏状态请求失败时回落到默认未选中态；收藏夹列表请求失败时不更新 UI。
- Success: 三个页签均可在普通视频播放器中稳定展示，发现切播与互动状态更新符合预期。

## Data and API Considerations

- Endpoints touched: `requestDetailVideo`、`ApiRequest.requestUpSpaceVideo(mid:lastAid:pageSize:)`、`requestLikeStatus`、`requestLike`、`requestFavoriteStatus`、`requestFavVideosList`、`requestFavorite`、`removeFavorite`、`follow`。
- Auth, signing, or token refresh implications: 继续复用现有鉴权和签名逻辑。
- Pagination or caching implications:
  - 博主视频只请求首页候选并截取最多 6 条。
  - 相关视频直接使用当前 `VideoDetail.Related`，不新增缓存层。
  - 临时覆盖项继续仅保存在内存中的 `VideoSequenceProvider.temporaryOverrides`。
- Logging or debug visibility: 沿用现有播放器与请求日志。

## Technical Approach

- Existing modules and components to reuse:
  - `VideoPlayerViewModel` 统一装配播放器插件。
  - `VideoSequenceProvider` 继续承担原始播放序列和临时覆盖能力。
  - `RelatedVideoCell` 复用于 `博主视频` / `相关视频` 页签。
  - 详情页现有关注、点赞、收藏接口与状态语义直接复用。
- New types or files to add:
  - 新增 spec 与 tasks 文档。
  - 在现有播放器信息页签插件文件内扩展通用发现页签和互动页签实现。
- Migration or compatibility concerns:
  - 旧的精选专用发现插件改为通用插件，不再由 `FeaturedFeedFlowDataSource` 单独注入。
  - bangumi/PGC 保持现状，不显示新增页签。

## Impacted Areas

- `BilibiliLive/Component/Video/VideoPlayerViewModel.swift`
- `BilibiliLive/Component/Video/Plugins/...`
- `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
- `BilibiliLive/Base.lproj/Main.storyboard`
- Settings / persistence: 无新增设置或迁移。
- Build / CI / release: 继续使用 `fastlane build_simulator` 验证。

## Risks and Open Questions

- 收藏操作仍沿用“取消时从所有当前收藏夹中移除”的详情页旧语义，用户无法在播放态选择保留部分收藏夹。
- 点赞与收藏状态的单独状态请求是异步补齐，短时间内可能先看到默认未选中态，再刷新为真实状态。
- 普通单视频播放器没有原始序列时，发现项切播后退出播放器仍会回到原始详情页，而不是切到新视频详情页。

## Acceptance Criteria

- [ ] 非预览、非 bangumi/PGC 的普通视频播放器中出现 `博主视频`、`相关视频`、`互动` 三个页签。
- [ ] `博主视频` 与 `相关视频` 页签各最多显示 6 条横向卡片。
- [ ] 发现页签点选后立即切换播放，且存在原始序列时不会污染原始序列。
- [ ] 普通单视频播放器点选发现项后可直接切换到新视频继续播放。
- [ ] `互动` 页签可执行关注、点赞、收藏，状态与详情页语义保持一致。
- [ ] 焦点移动不会自动触发互动动作。
- [ ] 播放器退出、切页、Home / 后台时不留下残余音频或悬挂播放器实例。
- [ ] bangumi/PGC 播放器不显示新增页签，现有行为不回归。

## Manual Validation

- [x] `fastlane build_simulator`
- [ ] Validate in tvOS Simulator or on device
- [ ] 从 `精选` 进入播放器，验证 `博主视频` / `相关视频` / `互动` 三个页签出现
- [ ] 从普通视频详情页进入播放器，验证同样出现这三个页签
- [ ] 从分 P 或合集进入播放器，点发现项后验证切播成功，且 `上一条 / 下一条` 仍走原序列
- [ ] 从普通单视频播放器点发现项后验证直接切换到新视频播放
- [ ] 验证 `互动` 页签中的关注、点赞、收藏状态与详情页一致
- [ ] 验证收藏夹选择弹窗可正常打开并完成收藏
- [ ] 验证 Back/Menu、切后台、Home 后无残余音频或悬挂播放器实例
- [ ] 验证 bangumi/PGC 播放不显示新增页签
