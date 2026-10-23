class_name Level
extends Node2D
## Локация: тайлы, столкновения, фон. Пока строится из текстового файла
## Pyxel-версии (data/levels/*.txt); на шаге 4 — из сцены.

const TILE := 16
const TILESET := preload("res://assets/tiles/tiles.tres")

enum Kind { EMPTY, SOLID, PLATFORM, SPIKES }

## Символы карты -> имя тайла (порядок — assets/tiles/tiles.json).
const TILE_CHARS := {"S": "stone", "L": "log", "=": "plank", "^": "spikes", "_": "boardwalk", "%": "flagstone"}
const DECOR_CHARS := {"g": "tuft", "m": "mushroom"}

var level_name := ""
var meta := {}
var spawns := {}  # имя -> Vector2i (тайл)
var objects := []  # [символ, столбец, строка]
var blocked := {}  # Vector2i -> true: тайлы, временно ставшие стеной
var w := 0  # в тайлах
var h := 0
var pixel_w := 0
var pixel_h := 0

var _kinds := PackedByteArray()
var _tiles: TileMapLayer
var _decor: TileMapLayer


func load_txt(path: String) -> void:
	level_name = path.get_file().get_basename()
	var rows: Array[String] = []
	var section := ""
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.trim_suffix("\r")
		if section != "map" and (line.strip_edges() == "" or line.strip_edges().begins_with("#")):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2)
			continue
		if section == "map":
			if line.strip_edges() != "":
				rows.append(line)
		elif "=" in line:
			var key := line.get_slice("=", 0).strip_edges()
			var value := line.substr(line.find("=") + 1).strip_edges()
			if section == "meta":
				meta[key] = value
			elif section == "spawns":
				spawns[key] = Vector2i(int(value.get_slice(",", 0)), int(value.get_slice(",", 1)))
	_build(rows)


func _build(rows: Array[String]) -> void:
	h = rows.size()
	w = 0
	for r in rows:
		w = maxi(w, r.length())
	pixel_w = w * TILE
	pixel_h = h * TILE
	_kinds.resize(w * h)
	_kinds.fill(Kind.EMPTY)
	_tiles = _layer("Tiles")
	_decor = _layer("Decor")
	var order: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/tiles.json")).order
	for ty in h:
		var row := rows[ty].rpad(w, ".")
		for tx in w:
			var ch := row[tx]
			var tile_name := ""
			if ch == "#":
				var above := rows[ty - 1][tx] if ty > 0 and tx < rows[ty - 1].length() else "."
				tile_name = "dirt" if above in "#S_%L" else "grass"
			elif TILE_CHARS.has(ch):
				tile_name = TILE_CHARS[ch]
			elif DECOR_CHARS.has(ch):
				_decor.set_cell(Vector2i(tx, ty), 0, Vector2i(order.find(DECOR_CHARS[ch]), 0))
			elif ch != "." and ch != " ":
				objects.append([ch, tx, ty])
			if tile_name:
				var coords := Vector2i(order.find(tile_name), 0)
				_tiles.set_cell(Vector2i(tx, ty), 0, coords)
				_kinds[ty * w + tx] = _kind_of(coords)
	_add_background(meta.get("sky", "forest"))


func _layer(layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = TILESET
	add_child(layer)
	return layer


func _kind_of(coords: Vector2i) -> int:
	var kind: String = TILESET.get_source(0).get_tile_data(coords, 0).get_custom_data("kind")
	match kind:
		"solid": return Kind.SOLID
		"platform": return Kind.PLATFORM
		"spikes": return Kind.SPIKES
	return Kind.EMPTY


func _add_background(style: String) -> void:
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/backgrounds/backgrounds.json"))
	var layers: Array = all.get(style, [])
	for i in layers.size():
		var l: Dictionary = layers[i]
		var p := Parallax2D.new()
		p.scroll_scale = Vector2(l.parallax, l.parallax)
		p.repeat_size = Vector2(l.width, 0)
		p.repeat_times = 2
		p.z_index = -100
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/backgrounds/%s/%s.png" % [style, l.layer])
		spr.centered = false
		p.add_child(spr)
		add_child(p)
		move_child(p, i)  # слои по порядку, все — под тайлами


# ------------------------------------------------------------ запросы
func kind_at(tx: int, ty: int) -> int:
	if tx < 0 or tx >= w:
		return Kind.SOLID  # края мира — стена
	if ty < 0 or ty >= h:
		return Kind.EMPTY
	return _kinds[ty * w + tx]


func is_solid(tx: int, ty: int) -> bool:
	return kind_at(tx, ty) == Kind.SOLID or blocked.has(Vector2i(tx, ty))


func is_platform(tx: int, ty: int) -> bool:
	return kind_at(tx, ty) == Kind.PLATFORM


## Касается ли прямоугольник острой части кольев (нижние 3/4 тайла).
func touches_spikes(bx: float, by: float, bw: float, bh: float) -> bool:
	for ty in range(floori(by / TILE), floori((by + bh - 2) / TILE) + 1):
		for tx in range(floori(bx / TILE), floori((bx + bw - 2) / TILE) + 1):
			if kind_at(tx, ty) == Kind.SPIKES:
				var top := ty * TILE + 4
				if by + bh > top and bx + bw > tx * TILE + 2 and bx < tx * TILE + TILE - 2:
					return true
	return false


## Место старта героя (символ P) в пикселях: середина низа тайла.
func start_point() -> Vector2:
	for o in objects:
		if o[0] == "P":
			return Vector2(o[1] * TILE, (o[2] + 1) * TILE)
	return Vector2(TILE, TILE)
