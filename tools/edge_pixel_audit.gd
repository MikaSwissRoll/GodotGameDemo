extends SceneTree

## Pixel audit for the "north barrier feels proud" question.
## Two measurements, no engine geometry involved:
##   1. atlas: does the rim/edge/wall art actually reach its cell boundary?
##   2. screenshots: where is the visible knoll edge vs the player's feet, in pixels?

const ATLAS := "res://asset/Terrain/Tileset/Tilemap_color5.png"
const CELLS := [
    Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
    Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1),
    Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4),
]
const SHOT_DIR := "C:/Users/22141/AppData/Local/Temp/claude/D--Major-Project-GodotGameDemo/ced27bbc-8f9b-4028-af2b-738ad704b326/images/"


func _init() -> void:
    _atlas()
    _shot("1-west", SHOT_DIR + "1.png", Vector2(0.30, 0.62))
    _shot("2-north", SHOT_DIR + "2.png", Vector2(0.20, 0.50))
    _shot("3-south", SHOT_DIR + "3.png", Vector2(0.70, 0.40))
    quit()


func _atlas() -> void:
    var img := (load(ATLAS) as Texture2D).get_image()
    print("=== atlas %s (%dx%d) ===" % [ATLAS, img.get_width(), img.get_height()])
    print("(rows/cols are offsets inside the 64px cell; 'any' = a>0.05, 'solid' = >=32px with a>0.5)")
    for cell_v in CELLS:
        var cell: Vector2i = cell_v
        var x0: int = cell.x * 64
        var y0: int = cell.y * 64
        var r := {"fa": -1, "la": -1, "fs": -1, "ls": -1}
        var c := {"fa": -1, "la": -1, "fs": -1, "ls": -1}
        for dy in 64:
            var n := 0
            var na := 0
            for dx in 64:
                var a: float = img.get_pixel(x0 + dx, y0 + dy).a
                if a > 0.5:
                    n += 1
                if a > 0.05:
                    na += 1
            if na > 0:
                if r["fa"] < 0: r["fa"] = dy
                r["la"] = dy
            if n >= 32:
                if r["fs"] < 0: r["fs"] = dy
                r["ls"] = dy
        for dx in 64:
            var n := 0
            var na := 0
            for dy in 64:
                var a: float = img.get_pixel(x0 + dx, y0 + dy).a
                if a > 0.5:
                    n += 1
                if a > 0.05:
                    na += 1
            if na > 0:
                if c["fa"] < 0: c["fa"] = dx
                c["la"] = dx
            if n >= 32:
                if c["fs"] < 0: c["fs"] = dx
                c["ls"] = dx
        print("c%d r%d: rows any %2d..%2d solid %2d..%2d | cols any %2d..%2d solid %2d..%2d" % [
            cell.x, cell.y, r["fa"], r["la"], r["fs"], r["ls"],
            c["fa"], c["la"], c["fs"], c["ls"]])


func _shot(title: String, path: String, knoll_ref_frac: Vector2) -> void:
    var img := Image.new()
    if img.load(path) != OK:
        print("=== %s: cannot load %s" % [title, path])
        return
    img.convert(Image.FORMAT_RGB8)
    var w := img.get_width()
    var h := img.get_height()
    var data := img.get_data()
    print("=== %s (%dx%d) ===" % [title, w, h])
    var ref_low := _avg(data, w, h, 8, 8, 6)
    var ref_knoll := _avg(data, w, h,
        int(knoll_ref_frac.x * w), int(knoll_ref_frac.y * h), 6)
    print("ref low %s   ref knoll %s" % [ref_low, ref_knoll])
    var cols := 80
    var rows := 56
    print("    (map %dx%d cells, each ~%.1fx%.1f px; '.'=low '#' =knoll 'o'=other)" % [
        cols, rows, float(w) / cols, float(h) / rows])
    for gy in rows:
        var line := ""
        for gx in cols:
            var px := _avg(data, w, h, (gx * w) / cols, (gy * h) / rows,
                maxi(1, w / cols / 2))
            line += _classify(px, ref_low, ref_knoll)
        print("%02d|%s" % [gy, line])


func _avg(data: PackedByteArray, w: int, h: int, x: int, y: int, half: int) -> Color:
    var r := 0.0
    var g := 0.0
    var b := 0.0
    var n := 0
    for dy in range(maxi(0, y - half), mini(h, y + half + 1)):
        for dx in range(maxi(0, x - half), mini(w, x + half + 1)):
            var i := (dy * w + dx) * 3
            r += data[i]
            g += data[i + 1]
            b += data[i + 2]
            n += 1
    return Color(r / n / 255.0, g / n / 255.0, b / n / 255.0)


func _dist(a: Color, b: Color) -> float:
    return sqrt(pow(a.r - b.r, 2) + pow(a.g - b.g, 2) + pow(a.b - b.b, 2))


func _classify(px: Color, ref_low: Color, ref_knoll: Color) -> String:
    if _dist(px, ref_low) < 0.16:
        return "."
    if _dist(px, ref_knoll) < 0.16:
        return "#"
    return "o"
