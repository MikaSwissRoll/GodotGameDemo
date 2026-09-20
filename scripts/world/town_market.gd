extends Node2D
## Decorative goods and counters composed exclusively from existing pack art.
const ENV := preload("res://scripts/world/tiny_swords_environment.gd")
const UI := preload("res://scripts/ui/tiny_swords_ui.gd")
const WOOD := "res://asset/Terrain/Resources/Wood/Wood Resource/Wood Resource.png"
const MEAT := "res://asset/Terrain/Resources/Meat/Meat Resource/Meat Resource.png"
const TOOL := "res://asset/Terrain/Resources/Tools/Tool_%02d.png"
const STUMP := "res://asset/Terrain/Resources/Wood/Trees/Stump %d.png"

func _ready() -> void:
    name = "MarketProps"
    _counter(Vector2(1090, 805), [TOOL % 1, TOOL % 2])
    _counter(Vector2(1285, 1105), [MEAT, MEAT])
    _counter(Vector2(1420, 733), ["res://asset/Terrain/Resources/Gold/Gold Resource/Gold_Resource.png",
        "res://asset/Terrain/Resources/Gold/Gold Stones/Gold Stone 3.png"])
    # Staggered lumber stacks and a work stump flank the existing merchant.
    for point in [Vector2(800, 985), Vector2(830, 976), Vector2(856, 988),
        Vector2(810, 1011), Vector2(844, 1014), Vector2(876, 997),
        Vector2(934, 1100), Vector2(960, 1108)]:
        ENV.add_static_prop(self, WOOD, point, 1.25)
    ENV.add_static_prop(self, STUMP % 2, Vector2(911, 987), 0.7)
    ENV.add_static_prop(self, TOOL % 2, Vector2(925, 977), 1.0, -1)
    # Tools are grouped on the north workbench, with stone stock beside it.
    for item in [[TOOL % 3, Vector2(1050, 846)], [TOOL % 4, Vector2(1134, 832)],
        ["res://asset/Terrain/Decorations/Rocks/Rock2.png", Vector2(1180, 811)],
        ["res://asset/Terrain/Decorations/Rocks/Rock3.png", Vector2(1203, 822)]]:
        ENV.add_static_prop(self, item[0], item[1], 0.85)
    for point in [Vector2(1218, 1080), Vector2(1370, 1090)]:
        ENV.add_static_prop(self, STUMP % 1, point, 0.5)
    ENV.add_static_prop(self, MEAT, Vector2(1370, 1070), 1.0, -1)
    for point in [Vector2(1000, 1110), Vector2(1450, 1070), Vector2(745, 942)]:
        ENV.add_bush(self, 3, point, 0.5, 2)

func _counter(center: Vector2, goods: Array) -> void:
    # Nine-slicing keeps native plank/corner geometry at this small world scale.
    var table := NinePatchRect.new()
    table.texture = UI.patched(UI.WOOD_TABLE, 128, 64, 64)
    table.position = center - Vector2(60, 28)
    table.size = Vector2(120, 56)
    table.patch_margin_left = 20
    table.patch_margin_right = 20
    table.patch_margin_top = 20
    table.patch_margin_bottom = 20
    table.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    table.mouse_filter = Control.MOUSE_FILTER_IGNORE
    table.z_index = -3
    add_child(table)
    for i in goods.size():
        ENV.add_static_prop(self, goods[i], center + Vector2(-24 + i * 48, -8), 0.85)
