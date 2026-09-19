extends Node2D

const ENV := preload("res://scripts/world/tiny_swords_environment.gd")
const MAP_CELLS := Vector2i(75, 24)
const MAP_SIZE := Vector2(4800.0, 1536.0)
const RIVER_LEFT := 2304.0
const RIVER_RIGHT := 2560.0
const BLUE := "res://asset/Buildings/Blue Buildings/"
const RED := "res://asset/Buildings/Red Buildings/"
const ROCK := "res://asset/Terrain/Decorations/Rocks/Rock%d.png"
const STUMP := "res://asset/Terrain/Resources/Wood/Trees/Stump %d.png"
const GOLD := "res://asset/Terrain/Resources/Gold/Gold Stones/Gold Stone %d.png"
const GRASS_1 := preload("res://asset/Terrain/Tileset/Tilemap_color1.png")
const GRASS_2 := preload("res://asset/Terrain/Tileset/Tilemap_color2.png")
const GRASS_3 := preload("res://asset/Terrain/Tileset/Tilemap_color3.png")
const GRASS_4 := preload("res://asset/Terrain/Tileset/Tilemap_color4.png")

var _art: Node2D


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ENV.begin_world()
    _art = Node2D.new()
    _art.name = "EnvironmentArt"
    add_child(_art)
    _build_terrain()
    _build_village()
    _build_borderlands()
    _build_enemy_camp()
    _place_water_details()
    _place_water_walls()
    queue_redraw()


func _draw() -> void:
    var bridge := Rect2(RIVER_LEFT - 24.0, 704.0, RIVER_RIGHT - RIVER_LEFT + 48.0, 192.0)
    draw_rect(bridge, Color("#71503b"))
    draw_rect(bridge.grow(-8.0), Color("#b7794e"))
    for plank_y in range(718, 890, 24):
        draw_line(Vector2(RIVER_LEFT - 12, plank_y), Vector2(RIVER_RIGHT + 12, plank_y),
            Color("#e0a064"), 4.0)
        draw_line(Vector2(RIVER_LEFT - 12, plank_y + 5), Vector2(RIVER_RIGHT + 12, plank_y + 5),
            Color("#674538"), 2.0)
    draw_rect(Rect2(RIVER_LEFT - 30, 696, RIVER_RIGHT - RIVER_LEFT + 60, 12), Color("#4f3b35"))
    draw_rect(Rect2(RIVER_LEFT - 30, 896, RIVER_RIGHT - RIVER_LEFT + 60, 12), Color("#4f3b35"))
    for x in range(int(RIVER_LEFT - 4), int(RIVER_RIGHT + 8), 32):
        draw_circle(Vector2(x, 700), 5.0, Color("#d7bc83"))
        draw_circle(Vector2(x, 902), 5.0, Color("#d7bc83"))


func _build_terrain() -> void:
    ENV.add_water(_art, MAP_CELLS)
    ENV.add_ground_rect(_art, "VillageContinent", GRASS_1,
        Rect2i(0, 0, 36, MAP_CELLS.y), -20, Vector4i(0, 0, 1, 0))
    ENV.add_ground_rect(_art, "EnemyContinent", GRASS_3,
        Rect2i(40, 0, 35, MAP_CELLS.y), -20, Vector4i(1, 0, 0, 0))
    ENV.add_plateau(_art, "VillageGreen", GRASS_2, Rect2i(3, 2, 18, 8))
    ENV.add_ground_rect(_art, "GuardRoad", GRASS_2, Rect2i(3, 10, 33, 4), -18)
    ENV.add_plateau(_art, "CampRise", GRASS_4, Rect2i(53, 1, 19, 9))
    ENV.add_ground_rect(_art, "CampRoad", GRASS_4, Rect2i(40, 10, 31, 4), -18)


func _build_village() -> void:
    ENV.add_building(_art, BLUE + "Castle.png", Vector2(430, 620), 0.95,
        Vector2(225, 58), Vector2(1.7, 0.66))
    ENV.add_building(_art, BLUE + "House1.png", Vector2(790, 640), 0.82,
        Vector2(78, 38))
    ENV.add_building(_art, BLUE + "House2.png", Vector2(955, 640), 0.78,
        Vector2(76, 38))
    ENV.add_building(_art, BLUE + "House3.png", Vector2(1125, 640), 0.78,
        Vector2(76, 38))
    ENV.add_building(_art, BLUE + "Monastery.png", Vector2(1375, 640), 0.66,
        Vector2(92, 42), Vector2(0.9, 0.55))
    ENV.add_building(_art, BLUE + "Barracks.png", Vector2(1690, 650), 0.72,
        Vector2(110, 44), Vector2(1.0, 0.56))
    ENV.add_building(_art, BLUE + "Tower.png", Vector2(2115, 630), 0.7,
        Vector2(68, 38))
    ENV.add_building(_art, BLUE + "Archery.png", Vector2(860, 1325), 0.7,
        Vector2(94, 40))
    ENV.add_building(_art, BLUE + "House2.png", Vector2(1160, 1300), 0.72,
        Vector2(72, 36))

    _tree_cluster(Vector2(100, 350), [1, 2, 4, 3], 0)
    _tree_cluster(Vector2(1850, 290), [2, 3, 1], 4)
    _tree_cluster(Vector2(155, 1330), [4, 2, 3], 2)
    _tree_cluster(Vector2(1840, 1335), [1, 4, 2, 3], 5)
    _bush_cluster([Vector2(660, 300), Vector2(735, 315), Vector2(1240, 325),
        Vector2(1515, 330), Vector2(430, 1190), Vector2(1450, 1260)], 0)
    _rock_cluster([Vector2(285, 1080), Vector2(2030, 1130), Vector2(2180, 310)], 0)
    ENV.add_sheep(_art, Vector2(720, 615), 0)
    ENV.add_sheep(_art, Vector2(990, 625), 3)
    ENV.add_sheep(_art, Vector2(1280, 610), 5)


func _build_borderlands() -> void:
    _tree_cluster(Vector2(2150, 1220), [3, 4], 1)
    _tree_cluster(Vector2(2690, 300), [3, 4, 2], 3)
    _tree_cluster(Vector2(2720, 1320), [1, 4, 3], 6)
    _bush_cluster([Vector2(2060, 620), Vector2(2170, 1070), Vector2(2740, 620),
        Vector2(2820, 1100)], 3)
    _rock_cluster([Vector2(2190, 590), Vector2(2700, 560), Vector2(2820, 1210)], 2)


func _build_enemy_camp() -> void:
    ENV.add_building(_art, RED + "Tower.png", Vector2(3110, 630), 0.72,
        Vector2(68, 38))
    ENV.add_building(_art, RED + "Barracks.png", Vector2(3450, 650), 0.78,
        Vector2(116, 46), Vector2(1.0, 0.58))
    ENV.add_building(_art, RED + "Castle.png", Vector2(3980, 620), 0.96,
        Vector2(230, 60), Vector2(1.75, 0.68))
    ENV.add_building(_art, RED + "Archery.png", Vector2(4450, 650), 0.76,
        Vector2(100, 42))
    ENV.add_building(_art, RED + "Tower.png", Vector2(4670, 630), 0.7,
        Vector2(68, 38))
    ENV.add_building(_art, RED + "House1.png", Vector2(3320, 1320), 0.74,
        Vector2(72, 36))
    ENV.add_building(_art, RED + "House3.png", Vector2(3620, 1320), 0.74,
        Vector2(72, 36))
    ENV.add_building(_art, RED + "Barracks.png", Vector2(4280, 1325), 0.72,
        Vector2(106, 44))

    ENV.add_fire(_art, Vector2(3650, 700), 2, 0)
    ENV.add_fire(_art, Vector2(4220, 700), 3, 4)
    _tree_cluster(Vector2(2880, 330), [4, 3, 2], 1)
    _tree_cluster(Vector2(4540, 300), [4, 3, 1], 4)
    _tree_cluster(Vector2(2960, 1330), [3, 4, 2], 6)
    _tree_cluster(Vector2(4560, 1330), [4, 1, 3], 2)
    _bush_cluster([Vector2(3240, 310), Vector2(3720, 300), Vector2(4320, 315),
        Vector2(3070, 1170), Vector2(3910, 1260), Vector2(4660, 1160)], 5)
    _rock_cluster([Vector2(3040, 1090), Vector2(3420, 1160), Vector2(4050, 1120),
        Vector2(4620, 1050)], 4)
    for index in 4:
        ENV.add_static_prop(_art, STUMP % (index % 4 + 1),
            Vector2(3150 + index * 120, 610 + (index % 2) * 35), 0.42)
    for index in 5:
        ENV.add_static_prop(_art, GOLD % (index % 6 + 1),
            Vector2(4010 + index * 78, 1180 + (index % 2) * 42), 0.46)


func _place_water_details() -> void:
    for data in [
        [1, Vector2(2380, 170), 0], [2, Vector2(2490, 340), 4],
        [3, Vector2(2390, 560), 8], [4, Vector2(2480, 1060), 12],
        [2, Vector2(2385, 1280), 2], [1, Vector2(2480, 1430), 7]
    ]:
        ENV.add_water_foam(_art, data[1], data[2])
        ENV.add_water_rock(_art, data[0], data[1], data[2])
    ENV.add_static_prop(_art,
        "res://asset/Terrain/Decorations/Rubber Duck/Rubber duck.png",
        Vector2(2440, 1160), 1.0, -14)


func _tree_cluster(origin: Vector2, variants: Array, phase: int) -> void:
    var offsets := [Vector2.ZERO, Vector2(84, 22), Vector2(36, 96), Vector2(130, 105)]
    for index in variants.size():
        ENV.add_tree(_art, variants[index], origin + offsets[index],
            0.62 + (index % 2) * 0.07, false, phase + index * 2)


func _bush_cluster(points: Array, phase: int) -> void:
    for index in points.size():
        ENV.add_bush(_art, index % 4 + 1, points[index], 0.58, phase + index)


func _rock_cluster(points: Array, phase: int) -> void:
    for index in points.size():
        ENV.add_static_prop(_art, ROCK % (index % 4 + 1), points[index],
            0.82 + ((phase + index) % 2) * 0.12)


func _place_water_walls() -> void:
    ENV.add_wall(self, Vector2(2432, 344), Vector2(256, 688))
    ENV.add_wall(self, Vector2(2432, 1220), Vector2(256, 632))
