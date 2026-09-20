extends SceneTree

## Shared base for every V2 suite. `extends "res://tests_v2/harness.gd"`.
##
## WHY THIS EXISTS, and why it does not use `assert()`.
##
## In Godot a failed `assert()` returns from the ENCLOSING FUNCTION only. Inside a
## `_check_*` helper that means the helper aborts while the suite carries on to
## `quit(0)`: the run is green, the exit code is 0, and the assertion never
## mattered. The frozen legacy suite was largely unfalsifiable for exactly this
## reason.
##
## So V2 never asserts. It counts. Every failure is recorded, `finish()` decides
## the exit code, and a suite that recorded no checks at all is itself a failure -
## which catches the other silent killer, a suite that quietly stopped running.
##
## Three rules for anything extending this:
##   1. call `finish()` exactly once, from `_run()`, on every path;
##   2. arm `arm_timeout()` first, so a hang exits non-zero instead of stalling;
##   3. one `check()` per rule, with a message that names the rule.

var _checks: int = 0
var _failures: Array[String] = []
var _section: String = ""
var _timeout_armed: bool = false
var _finished: bool = false


## Abort the suite if it has not finished within `seconds`. Without this a suite
## that hangs is worse than one that fails: CI and the runner both wait forever.
func arm_timeout(seconds: float, suite_name: String) -> void:
    if _timeout_armed:
        return
    _timeout_armed = true
    create_timer(seconds).timeout.connect(func() -> void:
        if _finished:
            return
        push_error("V2 TIMEOUT %s after %.0fs" % [suite_name, seconds])
        print("V2 FAIL %s (timed out after %.0fs, %d checks recorded)" % [
            suite_name, seconds, _checks])
        quit(1))


## Start a named group of checks. Printed so a failure line says where it happened.
func section(title: String) -> void:
    _section = title
    print("  [%s]" % title)


## Record one rule. Never aborts, so a single run reports every broken rule.
func check(condition: bool, message: String) -> void:
    _checks += 1
    if condition:
        return
    var located := message
    if _section != "":
        located = "%s: %s" % [_section, message]
    _failures.append(located)
    push_error("V2 FAIL %s" % located)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
    check(actual == expected, "%s (got %s, expected %s)" % [message, actual, expected])


func check_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
    check(absf(actual - expected) <= tolerance,
        "%s (got %.3f, expected %.3f +/- %.3f)" % [message, actual, expected, tolerance])


func check_not_null(value: Variant, message: String) -> bool:
    var ok := value != null
    check(ok, message)
    return ok


## Wait `count` physics frames. Prefer this over `process_frame` when the thing
## under test moves, because movement happens in physics.
func wait_physics(count: int) -> void:
    for _i in count:
        await physics_frame


func wait_frames(count: int) -> void:
    for _i in count:
        await process_frame


## Decision point. Call once, at the end of `_run()`, on every path.
func finish(suite_name: String) -> void:
    _finished = true
    if _checks == 0:
        push_error("V2 FAIL %s: recorded no checks at all, so it verified nothing" % suite_name)
        print("V2 FAIL %s (0 checks: the suite did not run)" % suite_name)
        quit(1)
        return
    if _failures.is_empty():
        print("V2 PASS %s (%d checks)" % [suite_name, _checks])
        quit(0)
        return
    print("V2 FAIL %s (%d of %d checks failed)" % [suite_name, _failures.size(), _checks])
    for failure in _failures:
        print("    - %s" % failure)
    quit(1)


## Convenience for suites that load a packed scene, fail cleanly when it is missing.
func load_scene(path: String) -> PackedScene:
    if not ResourceLoader.exists(path):
        check(false, "scene is missing: %s" % path)
        return null
    var packed := load(path) as PackedScene
    check(packed != null, "scene failed to load as a PackedScene: %s" % path)
    return packed
