@tool
class_name EdgeExit
extends LevelObject
## Выход на краю карты: срабатывает, когда герой в него заходит.
## Рядом стоит дорожный указатель со стрелкой.

@export var target := ""
@export var spawn := ""


func _setup() -> void:
	bw = 16
	bh = 48
	bx = position.x
	by = position.y - bh


func refresh() -> void:
	show_strip(OBJECTS, "signpost_left" if position.x < T * 2 else "signpost_right")
