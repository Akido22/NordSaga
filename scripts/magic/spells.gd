class_name Spells
## Чары: руны, которые знает герой, и их действие (data/spells.toml).
## Руна — предмет вида rune: найденная или купленная, сразу запоминается.
## Сила чар растёт с показателем «Дух».

const KNOWN := ["rune_fire", "rune_shield", "rune_heal"]  # чары, у которых есть действие в коде


## Описание руны: name, cost, cast, color, ground_only, damage, speed, duration, heal.
static func spell(id: String) -> Dictionary:
	var s: Dictionary = {"ground_only": false, "damage": 0, "speed": 0.0, "duration": 0, "heal": 0}
	s.merge(Data.table("spells")[id], true)
	return s


static func fire_damage(spirit: int) -> int:
	return int(spell("rune_fire").damage) + spirit


static func heal_amount(spirit: int) -> int:
	return int(spell("rune_heal").heal) + spirit


## Срабатывание чар в конце сотворения.
static func release(id: String, player: Player, world) -> void:
	var spirit := int(GameState.inv.stats.spi)
	match id:
		"rune_fire":
			var x := player.cx + player.facing * 16
			var sp := float(spell("rune_fire").speed)
			world.add_projectile(Fireball.create(x, player.y + 18, player.facing * sp, fire_damage(spirit)))
			Audio.sfx("fire")
		"rune_shield":
			player.shield_t = int(spell("rune_shield").duration)
			Audio.sfx("charged")
			world.sparks(player.cx, player.cy, 10)
		"rune_heal":
			var healed := player.heal(heal_amount(spirit))
			world.float_text(player.cx, player.y - 8, "+%d" % healed, Pal.MOSS)
			Audio.sfx("heal")
			world.effects.heal_glow(player.cx, player.y)
