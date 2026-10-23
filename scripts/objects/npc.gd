@tool
class_name Npc
extends LevelObject
## Житель: облик и реплики — data/npcs.toml. Поворачивается к подошедшему герою.
## Торговля — шаг 7; пока житель только говорит.

@export var npc_id := "elder"

var data := {}
var facing := 1
var line := -1  # -1: молчит
var phase := 0
var _look: HumanoidLook


var talking: bool:
	get: return line >= 0


static func hero_name() -> String:
	return Data.table("npcs").get("hero_name", "Ратмир")


func _setup() -> void:
	bw = 20
	bh = 44
	bx = position.x - 2
	by = position.y - bh
	z_index = 7
	data = Data.table("npcs").get(npc_id, {}) if not Engine.is_editor_hint() else _editor_data()
	facing = int(data.get("facing", 1))
	phase = tx % 40


func _editor_data() -> Dictionary:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/json/npcs.json"))
	return raw.get(npc_id, {}) if raw is Dictionary else {}


func refresh() -> void:
	if _look == null:
		_look = HumanoidLook.new()
		_look.position = Vector2(bx + bw / 2 - position.x, 0)
		add_child(_look)
		_look.set_look(look_layers())
	_show(0)


## Слои облика из data.look: torso, head, helmet и *_tint.
func look_layers() -> Array:
	var l: Dictionary = data.get("look", {})
	var layers := [["hero_legs", l.get("legs_tint")], [l.get("torso", "hero_torso_plain"), l.get("torso_tint")],
			[l.get("head", "hero_head_male"), l.get("head_tint")]]
	if l.get("helmet"):
		layers.append([l.helmet, l.get("helmet_tint")])
	return layers


func lines() -> Array:
	var out := []
	for s in data.get("lines", []):
		out.append(str(s).replace("{hero}", hero_name()))
	return out


func display_name() -> String:
	return data.get("name", npc_id)


func hint() -> String:
	return "" if talking else "говорить"


## Следующая реплика; после последней разговор заканчивается.
func interact(world) -> void:
	line += 1
	if line >= lines().size():
		line = -1
	world.talk_npc = self if talking else null
	Audio.sfx("move")


func tick(world) -> void:
	var p: Player = world.player
	if absf(p.cx - center_x()) < 80:
		facing = 1 if p.cx > center_x() else -1
	else:
		facing = int(data.get("facing", 1))
		line = -1
	_show((world.t + phase) / 18)


func _show(i: int) -> void:
	_look.show_frame(HumanoidLook.anim("idle", i), facing, data.get("held"))
