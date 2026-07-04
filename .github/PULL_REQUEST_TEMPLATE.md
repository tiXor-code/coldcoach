## Summary

<!-- What does this PR change, and why? -->

## Checklist

- [ ] Ran `swift run coldcoach-selftest` locally (all pass)
- [ ] New business logic lives in `ColdCoachCore` with tests in **both** the XCTest suite and the `coldcoach-selftest` runner
- [ ] `COLDCOACH_BUILD_APP=1 swift build` succeeds (if the app layer changed)
- [ ] Coaching stays deterministic (debounce on transcript time, not wall-clock)
- [ ] No secrets or API keys committed

<!--
An agentic reviewer will open a tracking issue and comment on this PR automatically.
See .github/workflows/pr-review.yml.
-->
