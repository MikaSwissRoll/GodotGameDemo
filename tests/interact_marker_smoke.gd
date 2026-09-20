extends SceneTree

## Interaction-marker contract for the classic NPCs.
##
## The behaviour under test is a hand-off, not a simple toggle:
##   - before play begins        -> nothing shown (title backdrop is inert)
##   - play begins, player far   -> speech bubble, to guide the player over
##   - player inside the radius  -> bubble hides, "E ..." prompt shows
##   - player leaves             -> prompt hides, bubble returns
##
## The marker's pixels are reviewed separately by the `dialogue_ui` capture; this
## covers the contract and the atlas cell.

const UI := preload("res://scripts/ui/tiny_swords_ui.gd")


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(30.0).timeout.connect(_on_timeout)
    var game := (load("res://scenes/main/game.tscn") as PackedScene).instantiate() as Node2D
    root.add_child(game)
    current_scene = game
    await _wait_frames(4)

    var guard := game.get_node("VillageGuard")
    var merchant := game.get_node("Merchant")
    var player := game.get_node("Player")
    var ui := game.get_node("GameUI")

    # Atlas cell and filtering are static properties of the marker.
    for npc in [guard, merchant]:
        var marker: Sprite2D = npc._marker
        assert(marker != null, "%s has no interaction marker" % npc.name)
        var atlas := marker.texture as AtlasTexture
        assert(atlas != null, "%s marker is not an AtlasTexture" % npc.name)
        assert(Rect2i(atlas.region) == UI.SHIKASHI_BUBBLE,
            "%s marker samples the wrong atlas cell: %s" % [npc.name, atlas.region])
        assert(marker.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
            "%s marker is not nearest-filtered" % npc.name)

    # 1. Title backdrop: prepare_title_view() is what the title screen calls, and
    #    it must leave nothing advertised, because the player cannot move yet.
    game.prepare_title_view()
    await _wait_frames(3)
    assert(not guard._marker.visible, "Marker showed on the title backdrop")
    assert(not guard.prompt.visible, "Prompt showed on the title backdrop")

    # 2. Play begins via begin_from_title() — the same call the title makes after
    #    the camera pull-in. The player is still far, so the bubble guides them.
    player.global_position = guard.global_position + Vector2(400, 0)
    game.begin_from_title()
    await _wait_frames(10)
    assert(not guard.player_nearby, "Guard considers the player near from 400px away")
    assert(guard._marker.visible, "Marker did not appear once play began")
    assert(not guard.prompt.visible, "Prompt showed while the player was still far")

    # 3. Walk into the radius: the bubble hands over to the key prompt.
    var steps := 0
    while steps < 300 and not guard.player_nearby:
        player.global_position += Vector2(-2, 0)
        await physics_frame
        steps += 1
    assert(guard.player_nearby, "Guard never noticed the player walking in")
    assert(guard.prompt.visible, "Prompt did not appear on approach")
    assert(not guard._marker.visible, "Bubble stayed visible alongside the prompt")
    print("  entered after %d steps at distance %.1f" % [
        steps, guard.global_position.distance_to(player.global_position)])

    # 4. Leave: the prompt hides and the bubble returns.
    steps = 0
    while steps < 400 and guard.player_nearby:
        player.global_position += Vector2(2, 0)
        await physics_frame
        steps += 1
    assert(not guard.player_nearby, "Guard still thinks the player is near after leaving")
    assert(not guard.prompt.visible, "Prompt stayed visible after leaving")
    assert(guard._marker.visible, "Bubble did not return after leaving")

    # The two NPCs must not bob in phase, per the animation offset rule.
    var guard_phase: float = guard._marker.get_meta("bob_phase", 0.0)
    var merchant_phase: float = merchant._marker.get_meta("bob_phase", 0.0)
    assert(not is_equal_approx(guard_phase, merchant_phase),
        "Both markers bob in phase")

    print("INTERACT PASS: title gate, bubble-to-prompt hand-off, atlas cell, bob phase")
    quit(0)


func _wait_frames(count: int) -> void:
    for _i in count:
        await process_frame


func _on_timeout() -> void:
    push_error("Interaction marker test timed out")
    quit(1)
