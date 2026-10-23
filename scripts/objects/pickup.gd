@tool
class_name Pickup
extends TileBody
## Предмет на земле: серебро (coin) или вещь из items. Положенные на карту — висят
## в воздухе и запоминаются подобранными (uid); выпавшие из врагов — падают.

@export var kind := "coin"
@export var floating := true

var uid := ""  # для предметов с карты: «o12,9»
var age := 0
var taken := false


func _ready() -> void:
	w = 16
	h = 16
	z_index = 8
	# Узел в сцене стоит на низ-левом углу тайла; в игре (x, y) — верх-лево.
	x = position.x
	y = position.y - h
	if not Engine.is_editor_hint():
		sync()
	queue_redraw()


func tick(world) -> void:
	age += 1
	if not floating:
		apply_gravity()
		vx *= 0.95
		move(world.level)
	var p: Player = world.player
	if not p.dead and age > 20 and x < p.x + p.w and p.x < x + w and y < p.y + p.h and p.y < y + h:
		world.collect(self)
	sync()
	queue_redraw()


func _draw() -> void:
	var bob := sin(age * 0.08) * 3.0 if floating else 0.0
	if Engine.is_editor_hint():
		bob = -h  # в редакторе узел — на низу тайла
	if kind == "coin":
		# «Вращение» монеты сужением спрайта.
		var sx: float = [1.0, 0.75, 0.25, 0.75][(age / 6) % 4]
		draw_set_transform(Vector2(8, bob + 8), 0, Vector2(sx, 1))
		draw_texture(Icons.texture("coin"), Vector2(-8, -8))
		draw_set_transform(Vector2.ZERO)
	else:
		var it: Dictionary = _item()
		draw_texture(Icons.of(it) if it else Icons.texture(kind), Vector2(0, bob))
		if (age / 10) % 6 == 0:
			draw_rect(Rect2(12, bob + 2, 2, 2), Pal.SNOW)


func _item() -> Dictionary:
	if Engine.is_editor_hint():
		return {}
	return Items.get_item(kind) if Items.has(kind) else {}
