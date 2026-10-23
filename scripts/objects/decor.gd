@tool
class_name Decor
extends LevelObject
## Украшения без действия: берёза, идол, костёр (костёр — перед тайлами).

@export_enum("birch", "idol", "fire") var kind := "birch"


func refresh() -> void:
	z_index = 6 if kind == "fire" else -5
	show_strip(OBJECTS, "decor_" + kind)
