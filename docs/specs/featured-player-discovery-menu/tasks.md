# Implementation Tasks: featured-player-discovery-menu

- Spec: `docs/specs/featured-player-discovery-menu/spec.md`
- Status: Implemented
- Owner: Codex + project maintainers
- Last updated: 2026-04-05
- Superseded by: `docs/specs/player-info-discovery-actions/tasks.md` for current player-wide info panel behavior

## Working Agreements

- Keep each task independently reviewable.
- Prefer one focused code change per task.
- Update this file as tasks move from Todo to In progress to Done.
- Record validation next to the task that introduced the change.
- For playback or audio-related work, make teardown and lifecycle cleanup explicit in either a task goal, risk, or definition of done.

## Task 1: Temporary override queue semantics

- Status: Done
- Goal: Extend `VideoSequenceProvider` so featured playback can temporarily override the current item without mutating the base queue.
- Files likely to change: `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
- Risks or dependencies: `上 / 下`、播放结束和回到浏览态都必须清空临时覆盖链并保留原始 `currentIndex`。
- Definition of done: `current()` can return a temporary item while `peekPrevious` / `peekNext` and base index tracking still point to the featured queue.
- Validation: Covered by featured playback manual scenarios and build verification.

## Task 2: Featured discovery menu plugin

- Status: Done
- Goal: Add a feed-flow-only player plugin that contributes independent `博主视频` / `推荐视频` info tabs with up to 6 horizontal cards each.
- Files likely to change: `BilibiliLive/Component/Video/Plugins/VideoPlayerInfoTabsPlugin.swift`, `BilibiliLive/Component/Video/VideoPlayerViewModel.swift`
- Risks or dependencies: Uploader items require async loading and must refresh custom info tabs without blocking playback or leaving stale tasks alive.
- Definition of done: Two discovery tabs render with stable titles, async uploader refresh works, and selecting a card triggers temporary playback.
- Validation: Covered by manual menu scenarios and build verification.

## Task 3: Featured playback integration and regression hardening

- Status: Done
- Goal: Wire temporary discovery playback into featured browser/player coordination without regressing existing controls.
- Files likely to change: `BilibiliLive/Component/Video/VideoPlayerViewController.swift`, `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
- Risks or dependencies: Temporary items are not present in the featured list, so browser selection restore must continue to fall back to the original queue position.
- Definition of done: Exiting from temporary videos restores the featured list to the original base item, and existing menu / queue actions still behave correctly.
- Validation: Covered by manual focus/exit scenarios and build verification.

## Task 4: Info panel directional-input isolation

- Status: Done
- Goal: Prevent `精选` 播放态的 `上 / 下` 切视频逻辑 from firing while the system transport bar / info panel is visible and consuming focus for playback settings or discovery items.
- Files likely to change: `BilibiliLive/Component/Player/CommonPlayerViewController.swift`, `BilibiliLive/Component/Video/VideoPlayerViewController.swift`
- Risks or dependencies: The fix must preserve existing `精选` main-screen up/down switching while removing the input bleed inside `播放速度` and custom discovery lists.
- Definition of done: Pressing `上 / 下` inside `播放速度` or `博主 / 推荐` items only moves menu focus; pressing `上 / 下` on the main player surface still switches featured videos.
- Validation: `fastlane build_simulator` passed on 2026-04-05; manual tvOS menu-navigation verification still pending.

## Task 5: Remove direct player up/down switching and auto-trigger info actions

- Status: Done
- Goal: Delete the old player-surface `上 / 下` switching path and make `简介` panel `上一条 / 下一条` actions switch immediately when focused.
- Files likely to change: `BilibiliLive/Component/Video/VideoPlayerViewController.swift`, `BilibiliLive/Component/Player/CommonPlayerViewController.swift`, `BilibiliLive/Extensions/AVInfoPanelCollectionViewThumbnailCell+Hook.swift`
- Risks or dependencies: Must only auto-trigger `上一条 / 下一条`, avoid duplicate firing during focus reload, and keep `从头开始` as an explicit manual action.
- Definition of done: Direct `上 / 下` on the player surface no longer switches featured videos; focusing `上一条 / 下一条` triggers exactly one corresponding sequence switch.
- Validation: `fastlane build_simulator` plus manual tvOS focus validation.
