class_name ShieldDraugr
extends Draugr
## Держит щит перед собой: лёгкие удары спереди отскакивают. Пробивают его
## тяжёлый удар, удар сверху, удар в спину, парирование или серия лёгких ударов,
## которая ломает стойку.

var guard_max := 3
var guard_regen_frames := 120
var guard := 3
var guard_regen := 0


func _init() -> void:
	super._init()
	# Поля shield_draugr дополняют драугра: чего нет в разделе — как у драугра.
	var d := load_stats("shield_draugr")
	kind = "shield_draugr"
	guard_max = int(d.get("guard", guard_max))
	guard_regen_frames = int(d.get("guard_regen_frames", guard_regen_frames))
	guard = guard_max


func guarding() -> bool:
	return state in ["walk", "recover"] and stun_t == 0 and hurt_t == 0


func guards(direction: int, heavy: bool, plunge: bool) -> bool:
	return not (heavy or plunge) and guarding() and direction == -facing


func on_guard(world, direction: int) -> void:
	guard -= 1
	vx = direction * 1.6
	world.sparks(cx - direction * 10, y + 12, 5)
	if guard <= 0:
		Audio.sfx("guard_break")
		world.float_text(cx, y - 20, "ЩИТ ПРОБИТ", Pal.RED)
		stun_t = 70
		guard = guard_max


func think(world) -> void:
	if guard < guard_max:
		guard_regen += 1
		if guard_regen >= guard_regen_frames:
			guard += 1
			guard_regen = 0
	super.think(world)


func _show_look() -> void:
	var g := guarding()
	var f := HumanoidLook.anim("block") if g and absf(vx) < 0.1 else pose()
	look.show_frame(f, facing, Looks.RUSTY_SWORD, Looks.RUSTY_SHIELD, null, g, flash > 0, _eyes())
