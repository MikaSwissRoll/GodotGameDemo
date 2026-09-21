extends Node2D
## The classic town's authored decoration and life, shared with its title view.
const ENV := preload("res://scripts/world/tiny_swords_environment.gd")
const MARKET := preload("res://scripts/world/town_market.gd")
const RESIDENT := preload("res://scripts/world/town_resident.gd")
const BLUE := "res://asset/Buildings/Blue Buildings/"
const UNITS := "res://asset/Units/Blue Units/"
var actors: Node2D

func _ready() -> void:
    name = "StartingTown"
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    actors = Node2D.new()
    actors.name = "Residents"
    add_child(actors)
    _grass_districts()
    _architecture()
    _groves()
    _camp_and_workyards()
    _residents()
    add_child(MARKET.new())

func _grass_districts() -> void:
    var olive := preload("res://asset/Terrain/Tileset/Tilemap_color4.png")
    var cool := preload("res://asset/Terrain/Tileset/Tilemap_color5.png")
    ENV.add_ground_rect(self, "ShepherdGreen", olive, Rect2i(24, 15, 4, 4), -19)
    ENV.add_ground_rect(self, "GrazingMeadow", cool, Rect2i(28, 16, 5, 5), -19)

func _architecture() -> void:
    # Dead centre of the forecourt: it spans cols 14-24, so x 896..1600 and its middle
    # is x 1248. The foot sits on the terrace's own last surface row, which is what puts
    # the collision (250x56) on rows 6-7 inside the forecourt.
    #
    # It was moved off x 1216, which was half a tile west of centre - a leftover from
    # when the forecourt was cols 15-23.
    ENV.add_building(self, BLUE + "Castle.png", Vector2(1248, 480), 1.0,
        Vector2(250, 56), Vector2(1.7, 0.66))
    ENV.add_building(self, BLUE + "Monastery.png", Vector2(1720, 510), 0.9,
        Vector2(102, 46))
    var buildings := [
        ["House1", Vector2(790, 720)], ["House2", Vector2(745, 610)],
        ["House3", Vector2(1530, 755)], ["House1", Vector2(1690, 790)],
        ["House2", Vector2(820, 1190)], ["House3", Vector2(1500, 1260)],
        ["Barracks", Vector2(1970, 645)], ["Tower", Vector2(2140, 780)],
        ["Archery", Vector2(1990, 1190)],
        ["House1", Vector2(1195, 680)],
        ["House3", Vector2(1310, 745)],
        ["House3", Vector2(1790, 740)],
        ["House1", Vector2(1000, 1330)], ["House3", Vector2(1120, 1250)],
        ["House2", Vector2(1230, 1330)]]
    # Back-to-front paint order allows roof overlap without inverted depth.
    buildings.sort_custom(func(a: Array, b: Array) -> bool: return a[1].y < b[1].y)
    for item in buildings:
        ENV.add_building(self, BLUE + item[0] + ".png", item[1], 1.0,
            Vector2(86, 38))

## The castle terrace was raised after these groves were laid out, so several of their
## trees ended up standing on the high ground or in the mouth of its two entrances -
## and every tree here carries collision, so they block the way up. Nothing is planted
## inside this box: the terrace's columns and rows, plus the stair rows below it.
const TERRACE_KEEPOUT := Rect2i(13, 0, 13, 10)


func _groves() -> void:
    var clusters := [Vector2(470, 380), Vector2(670, 280), Vector2(800, 360),
        Vector2(1540, 240), Vector2(1900, 290), Vector2(2150, 320),
        Vector2(540, 1170), Vector2(570, 1430), Vector2(1720, 1420),
        Vector2(2140, 1430), Vector2(2130, 1090), Vector2(1350, 1360)]
    for index in clusters.size():
        for j in 4:
            var at: Vector2 = clusters[index] + [Vector2.ZERO, Vector2(85, -24),
                Vector2(-55, 68), Vector2(64, 100)][j]
            if TERRACE_KEEPOUT.has_point(Elevation.tile_of(at)):
                continue
            ENV.add_tree(self, (index + j) % 4 + 1, at, 0.85, true, index + j)
        var bush_at: Vector2 = clusters[index] + Vector2(12, 100)
        if TERRACE_KEEPOUT.has_point(Elevation.tile_of(bush_at)):
            continue
        ENV.add_bush(self, index % 4 + 1, bush_at, 0.75, index)
    for index in 18:
        var at := Vector2(670 + index * 80, 1080 + (index % 3) * 30)
        if index in [4, 5, 6, 7, 8, 12, 13]:
            continue
        ENV.add_bush(self, index % 4 + 1, at, 0.65, index)
    # Two trees stand at the foot of the castle stairs, one below each entrance, at the
    # centre of tile (13, 8) and tile (25, 8).
    #
    # They are placed AFTER the loops on purpose. They sit inside `TERRACE_KEEPOUT`, the
    # same box the loop above now skips, and they are here because they were asked for -
    # not because the skip missed them. A reader who finds them inside a keepout box and
    # deletes them as a bug would be undoing a deliberate placement.
    for index in 2:
        var spot: Vector2 = [Vector2(864.0, 544.0), Vector2(1632.0, 544.0)][index]
        ENV.add_tree(self, 1, spot, 0.85, true, 40 + index)

    for item in [[Vector2(960, 450), 2], [Vector2(1510, 530), 1],
        [Vector2(1820, 920), 3], [Vector2(680, 1010), 4], [Vector2(1310, 1190), 2]]:
        ENV.add_static_prop(self, "res://asset/Terrain/Decorations/Rocks/Rock%d.png" % item[1], item[0])

func _camp_and_workyards() -> void:
    var wood := "res://asset/Terrain/Resources/Wood/Wood Resource/Wood Resource.png"
    for offset in [Vector2(-16, 15), Vector2(12, 13), Vector2(0, 22)]:
        ENV.add_static_prop(self, wood, Vector2(1160, 944) + offset, 0.85)
    ENV.add_wall(self, Vector2(1160, 957), Vector2(44, 30))
    for point in [Vector2(1090, 1000), Vector2(1215, 1000), Vector2(860, 1170),
        Vector2(890, 1195), Vector2(900, 1160)]:
        ENV.add_static_prop(self, wood, point, 1.0)
    for i in 3:
        ENV.add_static_prop(self, "res://asset/Terrain/Resources/Wood/Trees/Stump %d.png" % (i + 1),
            Vector2(700 + i * 70, 1310 + (i % 2) * 36), 0.65)
    ENV.add_static_prop(self, "res://asset/Terrain/Resources/Meat/Meat Resource/Meat Resource.png",
        Vector2(1280, 995), 1.0)
    ENV.add_sheep(self, Vector2(1610, 1090), 1)
    ENV.add_sheep(self, Vector2(1700, 1160), 4)
    for i in 4:
        ENV.add_animated_strip(self, "res://asset/Terrain/Resources/Meat/Sheep/Sheep_Grass.png",
            Vector2i(128, 128), 12, Vector2(1840 + (i % 2) * 100, 1180 + floori(i / 2.0) * 85),
            0.85, 4.0, i * 3)

func _resident(role: String, family: String, idle: String, walk: String,
        route: Array, phase: float, frame_size := Vector2i(192, 192)) -> void:
    var actor := RESIDENT.new()
    actor.name = role
    actor.role = role
    actor.idle_sheet = UNITS + family + "/" + idle + ".png"
    actor.walk_sheet = UNITS + family + "/" + walk + ".png"
    actor.frame_size = frame_size
    actor.route = PackedVector2Array(route)
    actor.phase = phase
    actors.add_child(actor)

func _residents() -> void:
    _resident("旅者", "Monk", "Idle", "Run",
        [Vector2(1320, 810), Vector2(1390, 850), Vector2(1600, 880), Vector2(1390, 850)], 0.4)
    _resident("长枪巡卫", "Lancer", "Lancer_Idle", "Lancer_Run",
        [Vector2(1500, 930), Vector2(2040, 930)], 1.0, Vector2i(320, 320))
    _resident("城堡卫兵", "Lancer", "Lancer_Idle", "Lancer_Run",
        [Vector2(1100, 490), Vector2(1350, 490)], 2.0, Vector2i(320, 320))
    _resident("美食家", "Pawn", "Pawn_Idle Meat", "Pawn_Run Meat",
        [Vector2(1280, 980), Vector2(1330, 1040), Vector2(1230, 1050)], 3.0)
    _resident("木工", "Pawn", "Pawn_Idle Wood", "Pawn_Run Wood",
        [Vector2(890, 1260), Vector2(1020, 1200), Vector2(970, 1120)], 0.0)
    _resident("行商", "Pawn", "Pawn_Idle Gold", "Pawn_Run Gold",
        [Vector2(780, 850), Vector2(960, 850)], 1.6)
    _resident("居民", "Pawn", "Pawn_Idle", "Pawn_Run",
        [Vector2(1450, 1130), Vector2(1500, 1040), Vector2(1600, 1080)], 2.4)
    _resident("营火战士", "Warrior", "Warrior_Idle", "Warrior_Run",
        [Vector2(1100, 960)], 0.0)

    _resident("工具匠", "Pawn", "Pawn_Interact Hammer", "Pawn_Run Hammer",
        [Vector2(1080, 782)], 0.0)
    _resident("食物摊主", "Pawn", "Pawn_Idle Knife", "Pawn_Run Knife",
        [Vector2(1290, 1070)], 0.0)
    _resident("赶集村民", "Pawn", "Pawn_Idle", "Pawn_Run",
        [Vector2(1410, 822), Vector2(1445, 880), Vector2(1330, 875)], 1.4)
