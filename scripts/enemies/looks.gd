class_name Looks
## Облики врагов из листов героя с перекраской (как sprites.py в Pyxel-версии).

const DRAUGR_HEAD := {"e": "6", "a": "7", "c": "f"}  # бледная кожа, седые космы, светящиеся глаза
const DRAUGR := [
	["hero_legs", {"5": "1", "7": "5", "2": "1"}],
	["hero_torso_mail", {"6": "5", "5": "1", "f": "6", "2": "1", "a": "2"}],
	["hero_head_male", DRAUGR_HEAD],
	["hero_helmet_shishak", {"6": "5", "f": "6", "a": "2"}],
]
const ARCHER := [
	["hero_legs", {"5": "1", "7": "5", "2": "1"}],
	["hero_torso_leather", {"4": "3", "2": "1"}],
	["hero_head_male", DRAUGR_HEAD],
	["hero_helmet_cap", {"4": "3", "7": "3"}],  # капюшон
]
const JARL := [
	["hero_legs", {"5": "1", "7": "2", "2": "1"}],
	["hero_torso_mail", {"6": "d", "5": "1", "f": "6", "2": "1"}],
	["hero_head_male", {"e": "6", "a": "7"}],
	["hero_helmet_crown", null],
]
const RUSTY_SWORD := {"icon": "sword", "tint": {"f": "6", "6": "5", "a": "2"}}
const RUSTY_SHIELD := {"shield_colors": [1, 5, 6]}
const JARL_AXE := {"icon": "axe", "tint": {"6": "5", "f": "6"}}
