# Feature Spec: <feature-name>

## Metadata

- Status: Draft
- Owner:
- Related issue:
- Related ADR:
- Target build / release:

## Summary

Describe the change in one short paragraph.

## Problem Statement

What user or system problem are we solving? Why is the current behavior not good enough?

## Goals

- Goal 1
- Goal 2

## Non-goals

- Out of scope item 1
- Out of scope item 2

## User Flow

1. Entry point
2. Main navigation steps
3. Exit or completion condition

## tvOS Interaction

- Initial focus:
- Directional navigation:
- Primary action:
- Back / Menu behavior:
- Play / Pause behavior:
- Long press or context menu behavior:
- Accessibility or readability notes:

## UX States

- Loading:
- Empty:
- Error:
- Success:

## Data and API Considerations

- Endpoints touched:
- Auth, signing, or token refresh implications:
- Pagination or caching implications:
- Logging or debug visibility:

## Technical Approach

- Existing modules and components to reuse:
- New types or files to add:
- Migration or compatibility concerns:

## Impacted Areas

- `BilibiliLive/Module/...`
- `BilibiliLive/Component/...`
- `BilibiliLive/Request/...`
- Settings / persistence:
- Build / CI / release:

## Risks and Open Questions

- Risk or unknown 1
- Risk or unknown 2

## Acceptance Criteria

- [ ] The user-facing goal is met
- [ ] Focus behavior and remote navigation are correct
- [ ] Loading, empty, error, and success states are handled
- [ ] API requests remain correctly signed when applicable
- [ ] Existing navigation and playback flows do not regress

## Manual Validation

- [ ] `fastlane build_simulator`
- [ ] Validate in tvOS Simulator or on device
- [ ] Exercise loading, success, empty, and error states
- [ ] Verify focus movement, back navigation, and player behavior when relevant
- [ ] If auth or request code changed, verify login and token refresh paths
