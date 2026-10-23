@tool
class_name Prop
extends LevelObject
## Постройка или убранство (изба, кузня, фонарь…). Стоит на левом нижнем тайле;
## width — ширина в тайлах (картинка props/<вид>_<ширина>.png должна существовать).

@export var kind := "izba"
@export var width := 8

var seed := 0


func _setup() -> void:
	z_index = -10
	seed = tx * 31 + ty * 7


func refresh() -> void:
	show_strip(PROPS, "%s_%d" % [kind, width])


func tick(world) -> void:
	var t: int = world.t
	var w := width * T
	if kind == "izba" and t % 18 == seed % 18:
		world.effects.puff(position.x + w - 28, position.y - 128)
	elif kind == "forge":
		if t % 10 == seed % 10:
			world.effects.puff(position.x + 20, position.y - 104)
		if t % 50 == 0:  # кузнец бьёт по наковальне
			world.sparks(position.x + w - 44, position.y - 24, 5)
