class_name Enemy
extends TileBody
## Враг. Общее правило боя: каждая атака врага «предупреждает» о себе, её можно
## заблокировать, а поднятым вовремя щитом — парировать. Парированный враг оглушён,
## и следующий удар по нему критический.
## Числа — data/enemies.toml (раздел kind); логика кадрами, как в Pyxel-версии.

var kind := ""
var max_hp := 3
var contact_dmg := 1
var knock := 4.0
var silver := [1, 2]
var xp := 3
var ore_chance := 0.0  # шанс выронить железную крицу
var bread_chance := 0.0  # шанс выронить каравай
var stun_time := 80
var sight := 220

var hp := 3
var facing := -1
var dead := false
var hurt_t := 0
var flash := 0
var anim_t := 0
var stun_t := 0
var contact_cd := 0
var _fx: Node2D  # звёздочки оглушения и прочее — поверх облика


func _ready() -> void:
	_fx = Node2D.new()
	_fx.z_index = 1
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


## Числа из data/enemies.toml для вида kind (общие поля).
func load_stats(id: String) -> Dictionary:
	kind = id
	var d: Dictionary = Data.table("enemies").get(id, {})
	max_hp = int(d.get("hp", max_hp))
	contact_dmg = int(d.get("contact_damage", contact_dmg))
	knock = float(d.get("knockback", knock))
	silver = d.get("silver", silver)
	xp = int(d.get("xp", xp))
	ore_chance = float(d.get("ore_chance", ore_chance))
	bread_chance = float(d.get("bread_chance", bread_chance))
	stun_time = int(d.get("stun_frames", stun_time))
	sight = int(d.get("sight", sight))
	hp = max_hp
	return d


## Ставит врага ногами на низ тайла (tx, ty); dx — сдвиг по x, как в Pyxel (x2).
func place_on_tile(tx: int, ty: int, dx := 0.0) -> void:
	x = tx * Level.TILE + dx
	y = (ty + 1) * Level.TILE - h
	sync()


func overlaps(ox: float, oy: float, ow: float, oh: float) -> bool:
	return ox < x + w and x < ox + ow and oy < y + h and y < oy + oh


# ------------------------------------------------------------ получение урона
## Отражает ли враг этот удар (щитом).
func guards(_direction: int, _heavy: bool, _plunge: bool) -> bool:
	return false


func on_guard(_world, _direction: int) -> void:
	pass


## Сбить начатую атаку (при попадании или оглушении).
func interrupt() -> void:
	pass


## direction — куда смотрит бьющий герой. Возвращает "hit" или "blocked".
func take_hit(dmg: int, direction: int, world, heavy := false, plunge := false) -> String:
	var crit := stun_t > 0
	if crit:
		dmg = ceili(dmg * 2.5)
		stun_t = 0
	elif guards(direction, heavy, plunge):
		on_guard(world, direction)
		return "blocked"
	hp -= dmg
	hurt_t = 14
	flash = 6
	vx = direction * knock * (1.7 if heavy else 1.0)
	vy = -4.4 if heavy else -3.2
	facing = -direction
	interrupt()
	if crit:
		world.float_text(cx, y - 24, "КРИТ!", Pal.GOLD)
	world.float_text(cx, y - 8, str(dmg), Pal.SNOW if crit else Pal.GOLD)
	world.sparks(cx - direction * 6, cy, 12 if crit or heavy else 6)
	world.freeze(7 if crit else 5 if heavy else 3)
	if crit or heavy:
		world.shake(3)
	if hp <= 0:
		dead = true
		Audio.sfx("kill")
		world.on_enemy_killed(self)
	else:
		Audio.sfx("heavy" if crit or heavy else "hit")
	return "hit"


func on_parried(_world, player) -> void:
	stun_t = stun_time
	interrupt()
	vx = (1 if cx - player.cx >= 0 else -1) * 1.4  # недалеко: ответный удар должен доставать
	vy = -2.0


func on_blocked(_world, player) -> void:
	vx = (1 if cx - player.cx >= 0 else -1) * 3.6
	vy = -2.0
	hurt_t = 10
	interrupt()


# ------------------------------------------------------------ цикл
func tick(world) -> void:
	anim_t += 1
	if flash > 0:
		flash -= 1
	if contact_cd > 0:
		contact_cd -= 1
	if stun_t > 0:
		stun_t -= 1
		vx *= 0.85
	elif hurt_t > 0:
		hurt_t -= 1
		vx *= 0.88
	else:
		think(world)
	apply_gravity()
	move(world.level)
	var p: Player = world.player
	if (contact_dmg and not p.dead and hurt_t == 0 and stun_t == 0 and contact_cd == 0
			and overlaps(p.x, p.y, p.w, p.h)):
		var result: String = p.take_damage(current_contact_dmg(), cx, world, true, self)
		if result != "miss":
			contact_cd = 30


func current_contact_dmg() -> int:
	return contact_dmg


func think(_world) -> void:
	pass


func player_near(world, dist_x: float, dist_y := 56.0) -> bool:
	var p: Player = world.player
	return not p.dead and absf(p.cx - cx) < dist_x and absf(p.cy - cy) < dist_y


func patrol(world, speed: float) -> void:
	if hit_wall or (on_ground and not ground_ahead(world.level, facing)):
		facing = -facing
	vx = facing * speed


func sync() -> void:
	super.sync()
	queue_redraw()
	if _fx:
		_fx.queue_redraw()


## Рисование поверх облика (локальные координаты). Переопределяется.
func _draw_fx() -> void:
	draw_status(_fx, -12)


## Звёздочки над оглушённым; dy — высота над макушкой хитбокса.
func draw_status(c: CanvasItem, dy: float) -> void:
	if stun_t > 0:
		var t := Engine.get_physics_frames()
		for i in 3:
			var a := t * 0.15 + i * 2.1
			c.draw_rect(Rect2(Vector2(w / 2 + cos(a) * 10, dy + sin(a) * 3).floor(), Vector2(2, 2)),
					Pal.GOLD if i % 2 else Pal.SNOW)
