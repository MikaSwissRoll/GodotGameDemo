# Test workflow

## The automated test suite is FROZEN

**Do not run it. Do not add to it. Do not wait on it.**

`tests/` was emptied on purpose. There is no runner, no suite, and no harness left
in this project, so every command this document used to give
(`.\tests\run_tests.ps1 ...`, `godot --script res://tests/<name>.gd`) now simply
fails. Any reference to a `*_smoke` or `*_playthrough` suite elsewhere in `docs/`
describes something that no longer exists.

Do not restore the suites from Git history as part of a task. If testing is wanted
again, that is the user's decision to make, not a step an agent takes on its own.

## What replaces it

Verification is manual and observational:

- read the code you changed **and** the code that calls it;
- run the project and watch the parser, runtime, and resource output;
- for visual, UI, environment and scene work, take a rendered capture and inspect
  the actual pixels — `tools/capture_visual_qa.ps1`, documented in
  `docs/visual_qa.md`;
- drive the affected flow by hand in a running build and report what you saw.

Never write "verified" next to a change because something passed. With no suite,
the only evidence is what you ran and what you observed. Say which of the two it
was.

## What the suite taught us

Kept because the traps below are properties of Godot and GDScript, not of the
deleted files. Read this before writing any new test.

### A test may assert an invariant. It may not assert luck.

Split what you are checking:

- **Invariant** — true of every run, however the dice fall. Assert it. The phase
  is always a legal one; a reward never follows anything but combat; health stays
  inside `0..max`; a room in combat keeps making progress instead of stalling.
- **Outcome** — true of *some* runs. **Report it, do not assert it.** An AI dying
  in room 2 is a measurement, not a failure. The old `roguelite_playthrough`
  printed the death, its wave composition and its health trace, then exited `0`.

If an outcome genuinely must be guaranteed, remove the randomness rather than
hoping: pin the variant or the seed, and say so in a comment. Do not leave a
"must win" assertion pointed at a randomized run.

### A failed assert does not fail the suite

This is the sharpest trap, and it silently made most of the old suite
unfalsifiable.

A failed `assert()` in Godot **returns from the current function only**. Written
directly in `_run` that is what you want: `_run` aborts, never reaches `quit(0)`,
the suite's own timeout fires and the process exits `1`. Written inside a
`_check_*` helper it does nothing of the sort — the helper aborts, `_run`
continues to the next line, prints `... PASS: ...`, and calls `quit(0)`. The
suite is green and the assertion never mattered.

Measured, both modes, same file:

```text
mode=helper  EXIT=0   PROBE REACHED quit(0) after a FALSE assert inside a helper
mode=run     EXIT=1   PROBE TIMED OUT -> exit 1
```

Consequences, if a harness is ever rebuilt:

- **The process exit code is not evidence that a suite passed.** An assert failure
  always writes `SCRIPT ERROR: Assertion failed` to stderr, so read stderr as
  well; a stderr scan is what made the old suite observable in the end.
- Prefer a failure counter and `quit(1)` at the end of `_run`, so one pass reports
  every failed check rather than only the first.
- Attach an explicit timeout in every suite. It is what turns an aborted `_run`
  into a non-zero exit instead of a hang.

### A coroutine must be awaited

A GDScript function containing `await` is a coroutine. Calling one without
`await` returns at its **first suspension point** and the remainder never runs.
Three old suites had this defect, which turned whole checks into dead code that
still looked covered: `ballistics` ran one of its three melee assertions,
`free_play_spawn_smoke` never ran its kill-counter block at all (and its idle
check asserted 120 frames late, by which time a later check had already started
free play), and `stamina_feedback_smoke` never reached its buffer-expiry checks.
All three failed the moment they were made reachable.

### A test that cannot fail on a real defect is not worth keeping

Before adding an assertion, say which defect it would catch. Restating a constant,
asserting a node exists right after creating it, or confirming the value a setter
was just given all add runtime cost and no safety. Drive the real code path
instead of reimplementing its rule in the test.

**Tuned balance values are the worst case.** `stamina_feedback_smoke` once opened
with nine assertions restating `max_stamina`, the four stamina costs, the regen
rate and the feedback windows. Every one of them could only fail when someone
retuned on purpose — so when `stamina_regen_rate` was deliberately doubled from
22 to 44, the suite went red while the feature was correct. If a tuned value
matters, assert a **relationship to the live field** instead of the literal.

### A test must be able to observe what it claims

Two old checks named a defect they could not detect. A "the player is blocked by
the Guard" check stood the player 60px away, pushed 90px, and asserted it ended
more than 8px from the Guard's centre — but a body passing clean through ends 30px
*past* the centre, which also satisfies that. It passed on the very bug it named,
and the suite printed a claim that was false. Judge a push by **which side** the
body ends on, or compare against a control run with collision switched off; a
distance threshold alone cannot tell "stopped short" from "went through".

### A flaky test is worse than no test

It trains everyone to ignore red. When one turns up: decide whether it asserts an
invariant or an outcome, reproduce it a few times and count, and if it is an
outcome, convert it to a report. Do not add retries — they hide the very
nondeterminism that makes the failure unreadable. If it is a genuine invariant,
make the input deterministic first, then fix the defect it exposes.

## Related documents

- [Scene workflow](SCENE_WORKFLOW.md) — building the scenes a test would drive.
- [UI workflow](ui/UI_WORKFLOW.md) — capture-based verification for UI work.
- [Visual QA](visual_qa.md) — the screenshot harness, which still works and is now
  the main automated evidence available.
