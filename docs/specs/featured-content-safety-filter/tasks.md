# Implementation Tasks: featured-content-safety-filter

- Spec: `docs/specs/featured-content-safety-filter/spec.md`
- Status: Done
- Owner: Codex
- Last updated: 2026-04-06

## Working Agreements

- Keep each task independently reviewable.
- Prefer one focused code change per task.
- Update this file as tasks move from Todo to In progress to Done.
- Record validation next to the task that introduced the change.
- This feature changes content visibility in `精选`, so cache compatibility must be handled in the same change.

## Task 1: Add Featured keyword safety filter

- Status: Done
- Goal: Add a dedicated Featured-only keyword blacklist with text normalization and apply it before `RecommendedVideoItem` creation.
- Files likely to change:
  - `BilibiliLive/Module/ViewController/FeaturedBrowserViewController.swift`
  - `BilibiliLive/Module/ViewController/FeaturedContentSafetyFilter.swift`
- Risks or dependencies:
  - Rules that are too broad can over-block safe content.
  - Rules that are too narrow can miss obvious variants.
- Definition of done:
  - `精选` 推荐项在进入列表前会经过关键词兜底过滤。
  - 标题、UP 主名、推荐理由、描述文案都会参与匹配。
  - 常见空格 / 符号 / 大小写绕过失效。
- Validation:
  - `fastlane build_simulator` on 2026-04-06
  - Review follow-up narrowing validated with `fastlane build_simulator` on 2026-04-06

## Task 2: Harden Featured cache against stale unsafe entries

- Status: Done
- Goal: Invalidate old `精选` cache snapshots when the keyword rule set changes, and keep cache restore aligned with the new filter behavior.
- Files likely to change:
  - `BilibiliLive/Module/ViewController/FeaturedFeedCache.swift`
- Risks or dependencies:
  - Missing a cache version check would let old unsafe entries survive until the next refresh.
- Definition of done:
  - `FeaturedFeedCacheSnapshot` stores a content filter version.
  - Old snapshots without the new version no longer load as valid cache.
- Validation:
  - `fastlane build_simulator` on 2026-04-06

## Task 3: Verify Featured behavior after filtering

- Status: Done
- Goal: Run the most relevant build verification and document residual risks if manual runtime validation is not available.
- Files likely to change:
  - `docs/specs/featured-content-safety-filter/spec.md`
  - `docs/specs/featured-content-safety-filter/tasks.md`
- Risks or dependencies:
  - The repository has no automated tests; runtime behavior still needs simulator or device checks.
- Definition of done:
  - Relevant build verification completes, or the remaining risk is recorded.
  - Spec and tasks reflect the final shipped behavior.
- Validation:
  - `fastlane build_simulator` passed on 2026-04-06
  - Remaining risk: runtime manual validation in tvOS Simulator / device is still pending
