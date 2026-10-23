extends Node2D
## Галерея перенесённых ресурсов: фон с параллаксом, тайлы, иконки, объекты,
## постройки и шрифт. ←/→ — прокрутка, 1/2/3 — лес, город, курган.

const OBJECTS := "res://assets/sprites/objects"
const PROPS := "res://assets/sprites/props"
const GROUND_Y := 236

var font: Font = preload("res://assets/fonts/nord_font.fnt")
var tiles: Texture2D = preload("res://assets/tiles/tiles.png")
var icons: Texture2D = preload("res://assets/sprites/icons.png")
var scroll := 0.0
var style := "town"
var _bg: CanvasLayer  # фон — отдельный слой под всем остальным
var _world: Node2D


func _ready() -> void:
	_world = Node2D.new()
	add_child(_world)
	var x := 24.0
	for name in ["izba_8", "stela_active", "forge_7", "lantern_1", "gate_town", "longhouse_15",
			"runestone_active", "chest_closed", "banner_1", "oak_2", "decor_fire", "gate_forest",
			"torch_1", "throne_5", "gate_barrow", "lost_silver"]:
		var dir := PROPS if name in Strips.names(PROPS) else OBJECTS
		var s := Strips.sprite(dir, name)
		s.position = Vector2(x + Strips.meta(dir, name).anchor[0], GROUND_Y)
		_world.add_child(s)
		x += Strips.meta(dir, name).frame_w + 12
	_set_style(style)


func _set_style(s: String) -> void:
	style = s
	if _bg:
		_bg.queue_free()
	_bg = CanvasLayer.new()
	_bg.layer = -1
	add_child(_bg)
	var layers: Array = JSON.parse_string(FileAccess.get_file_as_string(
			"res://assets/backgrounds/backgrounds.json"))[s]
	for l in layers:
		var tex: Texture2D = load("res://assets/backgrounds/%s/%s.png" % [s, l.layer])
		var p := Parallax2D.new()
		p.scroll_scale = Vector2(l.parallax, 0)
		p.repeat_size = Vector2(l.width, 0)
		p.repeat_times = 3
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.position.y = 270 - tex.get_height() + 40  # горизонт ниже середины экрана
		p.add_child(spr)
		_bg.add_child(p)


func _process(delta: float) -> void:
	scroll += Controls.axis_x() * 120 * delta
	if Input.is_physical_key_pressed(KEY_1): _set_style("forest")
	elif Input.is_physical_key_pressed(KEY_2): _set_style("town")
	elif Input.is_physical_key_pressed(KEY_3): _set_style("barrow")
	_world.position.x = -scroll
	for p in _bg.get_children():
		p.scroll_offset.x = -scroll * p.scroll_scale.x
	queue_redraw()


func _draw() -> void:
	# Земля из тайлов: трава, мостовая, плиты.
	for i in 31:
		var t: int = [0, 8, 9][(i / 10) % 3]
		draw_texture_rect_region(tiles, Rect2(i * 16 - fmod(scroll, 16), GROUND_Y, 16, 16), Rect2(t * 16, 0, 16, 16))
		draw_texture_rect_region(tiles, Rect2(i * 16 - fmod(scroll, 16), GROUND_Y + 16, 16, 16), Rect2(16, 0, 16, 16))
	draw_rect(Rect2(0, 0, 480, 44), Color(Pal.BLACK, 0.8))
	draw_texture(icons, Vector2(4, 4))
	draw_string(font, Vector2(4, 32), "СЕВЕРНАЯ САГА: ресурсы из Pyxel. ←/→ — прокрутка, 1/2/3 — лес, город, курган",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.LINEN)
	draw_string(font, Vector2(4, 42), "Велеград — стела предков. Сага о Ратмире.", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.GOLD)
