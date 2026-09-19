extends SceneTree

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(8.0).timeout.connect(_on_timeout)
	INPUT_SETUP.ensure_actions()
	var world := (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(world)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	root.add_child(player)

	player.global_position = Vector2(2250, 400)
	Input.action_press("move_right")
	for frame_index in 60:
		await physics_frame
	Input.action_release("move_right")
	assert(player.global_position.x < 2310.0, "River wall did not block crossing")

	player.global_position = Vector2(2250, 800)
	Input.action_press("move_right")
	for frame_index in 110:
		await physics_frame
	Input.action_release("move_right")
	assert(player.global_position.x > 2560.0, "Bridge did not allow crossing")

	player.global_position = Vector2(200, 590)
	Input.action_press("move_right")
	for frame_index in 50:
		await physics_frame
	Input.action_release("move_right")
	assert(player.global_position.x < 310.0, "Village castle did not block movement")
	print("COLLISION PASS: river, bridge, village castle")
	quit(0)


func _on_timeout() -> void:
	push_error("Collision smoke test timed out")
	quit(1)

