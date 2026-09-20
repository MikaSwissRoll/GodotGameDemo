extends SceneTree

## Icon-atlas cell mapper.
##
## Why this exists: the Shikashi sheet is a 16-column x 27-row grid of 32px cells,
## but its rows are NOT full (row 0 holds 11 icons, row 1 holds 5, row 3 holds 16).
## Counting columns by eye therefore produces wrong coordinates, and the pack's
## own manifest lists icons by category rather than by atlas position, so it
## cannot be used to derive a cell either. This project has already recorded one
## wrong coordinate that way.
##
## Run:
##   godot --path . --script res://tools/dump_icon_atlas.gd
##
## Then render the cell you intend to use and look at it before writing the
## coordinate into docs/ui/UI_ASSET_GUIDE.md.

const SHEET := "res://asset/Shikashi's Fantasy Icons Pack v2/#1 - Transparent Icons.png"
const COLS := 16
const CELL := 32
## Rows to list in detail. Set to [] to only print the occupancy map.
const DETAIL_ROWS: Array[int] = [0, 4]


func _init() -> void:
    var sheet: Texture2D = load(SHEET)
    if sheet == null:
        push_error("atlas not found: " + SHEET)
        quit(1)
        return
    var img := sheet.get_image()
    print("atlas %s  size=%s  grid=%dx%d cells of %dpx" % [
        SHEET.get_file(), img.get_size(), COLS, int(img.get_height() / CELL), CELL])

    var rows := int(img.get_height() / CELL)
    print("--- occupied columns per row ---")
    for row in rows:
        var cols: Array[int] = []
        for col in COLS:
            if _opaque(img, col, row) > 0:
                cols.append(col)
        if cols.is_empty():
            continue
        var flag := "" if cols.size() == COLS else "   <-- NOT FULL (%d)" % cols.size()
        print("  row %2d  cols %s%s" % [row, cols, flag])

    if DETAIL_ROWS.is_empty():
        quit(0)
        return
    print("--- per-cell detail (pixel rect + inner opaque box) ---")
    for row in DETAIL_ROWS:
        for col in COLS:
            var n := _opaque(img, col, row)
            if n == 0:
                continue
            var box := _box(img, col, row)
            print("  row %2d col %2d  px(%d,%d,%d,%d)  opaque=%d  inner=(%d,%d,%d,%d)" % [
                row, col, col * CELL, row * CELL, CELL, CELL, n,
                box.position.x, box.position.y, box.size.x, box.size.y])
    quit(0)


func _opaque(img: Image, col: int, row: int) -> int:
    var n := 0
    for y in range(row * CELL, row * CELL + CELL):
        for x in range(col * CELL, col * CELL + CELL):
            if _inside(img, x, y) and img.get_pixel(x, y).a > 0.1:
                n += 1
    return n


func _box(img: Image, col: int, row: int) -> Rect2i:
    var minx := 9999
    var maxx := -1
    var miny := 9999
    var maxy := -1
    for y in range(row * CELL, row * CELL + CELL):
        for x in range(col * CELL, col * CELL + CELL):
            if _inside(img, x, y) and img.get_pixel(x, y).a > 0.1:
                minx = mini(minx, x - col * CELL)
                maxx = maxi(maxx, x - col * CELL)
                miny = mini(miny, y - row * CELL)
                maxy = maxi(maxy, y - row * CELL)
    if maxx < 0:
        return Rect2i()
    return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)


func _inside(img: Image, x: int, y: int) -> bool:
    return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height()
