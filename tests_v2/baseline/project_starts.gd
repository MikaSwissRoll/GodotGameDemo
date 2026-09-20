extends "res://tests_v2/harness.gd"

## V2 BASELINE — project startup.
##
## Answers one question: does the current project still boot every scene it ships,
## with the nodes the rest of the game expects? It is the check that says "this
## refactor did not break startup", not a feature test.

const CLASSIC_SCENE := "res://scenes/main/game.tscn"
const RUN_SCENE := "res://scenes/main/run_game.tscn"
const TITLE_SCENE := "res://scenes/main/town_title.tscn"

const SUITE := "project_starts"


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    arm_timeout(60.0, SUITE)

    section("project configuration")
    var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
    check(main_scene != "", "application/run/main_scene is not configured")
    check(ResourceLoader.exists(main_scene), "the configured main scene does not exist: %s" % main_scene)

    section("shipped scenes load")
    for path in [TITLE_SCENE, CLASSIC_SCENE, RUN_SCENE]:
        check(ResourceLoader.exists(path), "scene is missing: %s" % path)
        var packed := load(path) as PackedScene
        check(packed != null, "scene did not load as a PackedScene: %s" % path)

    section("shared systems are registered as classes")
    # These are referenced by bare class_name across the codebase, so a parse
    # failure in any of them breaks unrelated scenes.
    for class_name_string in ["Player", "Enemy", "ArcherEnemy", "Follower", "Party", "Elevation"]:
        check(ClassDB.class_exists(class_name_string) or _class_script_exists(class_name_string),
            "class_name %s is not resolvable" % class_name_string)

    section("classic scene builds its node contract")
    var classic := await _instantiate(CLASSIC_SCENE)
    if classic != null:
        for node_path in ["Player", "QuestManager", "GameUI", "ClassicProgression", "VillageGuard", "Merchant"]:
            check(classic.get_node_or_null(node_path) != null,
                "classic scene is missing node %s" % node_path)
        var progression: Variant = classic.get_node_or_null("ClassicProgression")
        if progression != null:
            check(progression.phase == 0,
                "classic scene should start in the Guard tutorial phase, got %s" % progression.phase)
        classic.queue_free()
        await wait_frames(2)

    section("expedition scene builds its node contract")
    var run := await _instantiate(RUN_SCENE)
    if run != null:
        for node_path in ["Player", "RunUI", "RunArena"]:
            check(run.get_node_or_null(node_path) != null,
                "expedition scene is missing node %s" % node_path)
        check(run.phase == "menu", "expedition scene should start in the menu phase, got %s" % run.phase)
        run.queue_free()
        await wait_frames(2)

    section("title scene builds its node contract")
    var title := await _instantiate(TITLE_SCENE)
    if title != null:
        check(title.get_node_or_null("Game") != null or title.get_node_or_null("game") != null,
            "title scene does not host the classic game")
        check(title.menu != null, "title scene has no menu")
        title.queue_free()
        await wait_frames(2)

    finish(SUITE)


## A class_name declared in a project script is reachable through its own script
## path even before the global class cache is warm, so check both ways.
func _class_script_exists(class_name_string: String) -> bool:
    for path in [
        "res://scripts/player/player.gd",
        "res://scripts/enemies/enemy.gd",
        "res://scripts/enemies/archer.gd",
        "res://scripts/party/follower.gd",
        "res://scripts/systems/party.gd",
        "res://scripts/systems/elevation.gd",
    ]:
        if not ResourceLoader.exists(path):
            continue
        var script := load(path) as GDScript
        if script != null and script.get_global_name() == class_name_string:
            return true
    return false


func _instantiate(path: String) -> Node:
    var packed := load(path) as PackedScene
    if packed == null:
        check(false, "cannot instantiate %s" % path)
        return null
    var node := packed.instantiate()
    if node == null:
        check(false, "instantiate() returned null for %s" % path)
        return null
    root.add_child(node)
    current_scene = node
    await wait_frames(3)
    return node
