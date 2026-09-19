extends RefCounted

static func popup(parent: Node2D, at: Vector2, message: String, tint: Color) -> void:
    var label := Label.new()
    label.text = message
    label.z_index = 50
    label.add_theme_font_size_override("font_size", 25)
    label.add_theme_color_override("font_color", tint)
    label.add_theme_color_override("font_shadow_color", Color.BLACK)
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    parent.add_child(label)
    label.add_to_group("combat_feedback")
    label.global_position = at + Vector2(-15, -72)
    var tween := label.create_tween()
    tween.tween_property(label, "global_position", label.global_position + Vector2(0, -42), 0.5)
    tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
    tween.tween_callback(label.queue_free)


