extends SceneTree

## Measures where the visible feet are in each frame of the player's animations,
## relative to the collision origin. The sprite is drawn at (0, -30) scale 0.8 with
## 192px frames, so: foot_offset = (lowest_opaque_row - 96) * 0.8 - 30.
## The visible gap at a stop = 18 (circle radius) - foot_offset.

const SHEETS := [
    ["idle", "res://asset/Units/Blue Units/Warrior/Warrior_Idle.png", 8],
    ["run", "res://asset/Units/Blue Units/Warrior/Warrior_Run.png", 6],
    ["archer_idle", "res://asset/Units/Red Units/Archer/Archer_Idle.png", 6],
    ["archer_run", "res://asset/Units/Red Units/Archer/Archer_Run.png", 4],
]
const FRAME := 192


func _init() -> void:
    print("%-6s %-6s %-9s %-9s %-11s %-11s" % [
        "anim", "frame", "low_row", "foot_off", "gap_north", "right_edge"])
    for entry in SHEETS:
        _sheet(entry[0], entry[1], entry[2])
    quit()


func _sheet(anim: String, path: String, count: int) -> void:
    var img := (load(path) as Texture2D).get_image()
    for index in count:
        var x0 := index * FRAME
        var low := -1
        var low_firm := -1
        var right := -1
        for dy in FRAME:
            var n := 0
            for dx in FRAME:
                if img.get_pixel(x0 + dx, dy).a > 0.5:
                    n += 1
            if n > 0:
                low = dy
            if n >= 3:
                low_firm = dy
        for dx in FRAME:
            var n := 0
            for dy in FRAME:
                if img.get_pixel(x0 + dx, dy).a > 0.5:
                    n += 1
            if n >= 3:
                right = dx
        # 'firm' rows/cols need >= 3 opaque pixels, so a lone speckle does not count.
        var foot_off := (low_firm - FRAME / 2.0) * 0.8 - 30.0
        var right_edge := (right - FRAME / 2.0) * 0.8
        print("%-6s %-6d %-9d %-9.1f %-11.1f %-11.1f" % [
            anim, index, low_firm, foot_off, 18.0 - foot_off, right_edge])
