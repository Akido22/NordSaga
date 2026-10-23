class_name NpcMenu
extends Overlay
## Меню торговца: говорить, торговать, ковать (у кузнеца), уйти.

var npc: Npc
var shop: Dictionary
var menu: MenuList


func _init(who: Npc) -> void:
	npc = who
	shop = Data.table("shops")[npc.shop()]
	var opts := [["Говорить", true], ["Торговать", true]]
	if "forge" in shop.get("tabs", []):
		opts.append(["Ковать оружие", true])
	opts.append(["Уйти", true])
	menu = MenuList.new(opts, 1)


func update() -> void:
	if Controls.pressed("back"):
		close()
		return
	if menu.update() < 0:
		return
	match menu.label():
		"Говорить":
			close()
			world.start_talk(npc)
		"Торговать":
			game.open_overlay(TradeMenu.new(npc.shop()))
		"Ковать оружие":
			game.open_overlay(TradeMenu.new(npc.shop(), Array(shop.tabs).find("forge")))
		_:
			close()


func draw_ui(c: CanvasItem) -> void:
	dim(c, 0.4)
	var cx := c.get_viewport_rect().size.x / 2
	var h := 34 + menu.options.size() * 16
	UiKit.panel(c, Rect2(cx - 110, 50, 220, h), Pal.NIGHT)
	UiKit.text_center(c, cx, 60, npc.display_name(), Pal.GOLD, Pal.NIGHT)
	menu.draw(c, cx, 78, 16, t)
