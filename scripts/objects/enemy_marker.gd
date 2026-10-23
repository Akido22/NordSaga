@tool
class_name EnemyMarker
extends LevelObject
## Где появляется враг. Сами враги — шаг 6; пока метка видна только в редакторе.

@export_enum("wolf", "draugr", "shield_draugr", "archer", "dummy", "jarl") var kind := "wolf"


func refresh() -> void:
	visible = Engine.is_editor_hint()
	queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(0, -44, 20, 44), Color(Pal.RED, 0.5))
		UiKit.text(self, 0, -54, kind, Pal.RED)
