@tool
class_name Level
extends Node2D
## Локация — сцена scenes/levels/<имя>.tscn:
##   Tiles, Decor — слои тайлов (тип тайла — пользовательские данные «kind» в tiles.tres);
##   Props — постройки; Objects — сундуки, камни, врата, таблички, монеты, декор;
##   Npcs — жители; Enemies — метки врагов; Spawns — точки появления (Start — старт героя).
## Сцены собирает из data/levels/*.txt tools/import_levels.gd; дальше их можно
## править в редакторе.

const TILE := 16
const TILESET := preload("res://assets/tiles/tiles.tres")

enum Kind { EMPTY, SOLID, PLATFORM, SPIKES }

@export var title := ""
@export var subtitle := ""
@export_enum("forest", "town", "barrow") var sky := "forest"
@export_enum("forest", "town", "boss") var music := "forest"
## Размер карты в тайлах: края по горизонтали — стена, ниже низа — пропасть.
@export var size_tiles := Vector2i(32, 24)
## Арена босса: boss (id), arena_trigger (столбец), arena_door [столбец, строка от, до], boss_chest «столбец,строка».
@export var boss := {}

var level_name := ""
var blocked := {}  # Vector2i -> true: тайлы, временно ставшие стеной
var w := 0
var h := 0
var pixel_w := 0
var pixel_h := 0
var _kinds := PackedByteArray()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	level_name = scene_file_path.get_file().get_basename() if scene_file_path else str(name)
	w = size_tiles.x
	h = size_tiles.y
	pixel_w = w * TILE
	pixel_h = h * TILE
	_index_tiles()
	_add_background()


func _index_tiles() -> void:
	_kinds.resize(w * h)
	_kinds.fill(Kind.EMPTY)
	var tiles: TileMapLayer = $Tiles
	for c in tiles.get_used_cells():
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
			continue
		match str(tiles.get_cell_tile_data(c).get_custom_data("kind")):
			"solid": _kinds[c.y * w + c.x] = Kind.SOLID
			"platform": _kinds[c.y * w + c.x] = Kind.PLATFORM
			"spikes": _kinds[c.y * w + c.x] = Kind.SPIKES


func _add_background() -> void:
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/backgrounds/backgrounds.json"))
	var layers: Array = all.get(sky, [])
	for i in layers.size():
		var l: Dictionary = layers[i]
		var p := Parallax2D.new()
		# По вертикали фон идёт вместе с уровнем: в Pyxel-версии экран был высотой с уровень.
		p.scroll_scale = Vector2(l.parallax, 1)
		p.repeat_size = Vector2(l.width, 0)
		p.repeat_times = 2
		p.z_index = -100
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/backgrounds/%s/%s.png" % [sky, l.layer])
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


## Точка появления по имени (левый край и низ тайла); нет такой — старт героя.
func spawn_point(spawn_name: String) -> Vector2:
	var spawns := get_node_or_null("Spawns")
	if spawns:
		var m: Node2D = spawns.get_node_or_null(spawn_name) if spawn_name else null
		if m == null:
			m = spawns.get_node_or_null("Start")
		if m:
			return m.position
	return Vector2(TILE, TILE)


func objects() -> Array:
	return $Objects.get_children()


func props() -> Array:
	return $Props.get_children()


func npcs() -> Array:
	return $Npcs.get_children()


func enemy_markers() -> Array:
	return $Enemies.get_children()
