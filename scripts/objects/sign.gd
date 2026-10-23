@tool
class_name Sign
extends LevelObject
## Табличка: текст показывается, пока герой стоит рядом.
## В тексте можно писать стрелки ← ↑ → ↓.

@export_multiline var text := "..."


func _setup() -> void:
	bw = 20
	bh = 24
	bx = position.x - 2
	by = position.y - bh


func refresh() -> void:
	show_strip(OBJECTS, "sign")
