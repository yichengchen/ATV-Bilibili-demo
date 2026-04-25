# Specs

This repository uses lightweight spec-driven development for non-trivial work.

## When to create a spec

Create a spec before coding when a change affects one or more of these areas:

- User-visible behavior or navigation
- tvOS focus interactions or remote control behavior
- Player plugins, playback, danmaku, or masking
- Playback / preview lifecycle, including teardown on dismiss, page switch, or app background
- Request signing, authentication, token refresh, or API contracts
- Cross-module refactors or new persistence/settings behavior

## Workflow

1. Copy [`docs/specs/_template/spec.md`](./_template/spec.md) and [`docs/specs/_template/tasks.md`](./_template/tasks.md) into `docs/specs/<feature-slug>/`.
2. Fill in the spec first. Keep it short, concrete, and testable.
3. Review the spec before implementation. Resolve open questions early.
4. Implement from `tasks.md` one slice at a time.
5. Link the spec from the pull request and record manual validation.

For any playback or audio-related change, the spec and validation checklist should explicitly cover how audio, players, observers, and async work are cleaned up on dismiss, navigation away, and Home / app background.

Specs can be written in either Chinese or English. Keep file names and paths ASCII.
