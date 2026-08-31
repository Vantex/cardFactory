# Task 10 queue prerequisite closure fix

Base: `f5e3cd7`

## RED

Tests were updated before production code. The first TestProgression run reached the test suite and failed only on the newly required behavior:

- cancelling `factory_foundations` with queued dependent `fluid_handling` incorrectly returned success and changed state;
- the same path emitted cancellation/queue events;
- removing queued `factory_foundations` left dependent `fluid_handling` without its prerequisite;
- queue removal left a stale wait reason;
- the old Main/UI regression expected the newly-invalid queue to remain after cancellation.

The initial test run also exposed a duplicate local observer name in the test fixture; that test-only parse issue was corrected before the RED run was accepted.

## GREEN

`TechnologySystem` now preflights the remaining queue with `_research_queue_closure_is_valid` before `cancel_research` and `remove_from_queue`. The helper walks completed technologies, an optional current technology, and queue entries in order, checking each prerequisite without calling the persistence validator as domain control flow. Rejected commands return before mutation or event emission. Successful queue removal assigns the preflighted queue and clears `research_queue_wait_reason`.

Tests cover real `TechnologySystem`, `GameStateCodec`, and `GameStateValidator` behavior, including validator-valid payloads after successful cancel/remove and digest/event invariance on rejected commands.

## Verification

- TestProgression: PASS (`PROGRESSION TESTS PASSED`), focused run after implementation.
- TestStatePersistence: PASS (`STATE PERSISTENCE TESTS PASSED`), focused run after implementation.
- Full `tools/run_tests.ps1`: PASS (all configured suites emitted their success markers and exited zero; runner reported no script/parse errors, leaks, or failure markers).
- Main 120-frame run: PASS (Godot exited zero; no SCRIPT ERROR, Parse Error, ObjectDB leak, or resource leak).
- `git diff --check`: PASS.
