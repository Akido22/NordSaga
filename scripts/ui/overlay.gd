class_name Overlay
extends CanvasLayer
## Окно поверх игры: мир стоит, пока окно открыто. Рисование — в draw_ui(c),
## логика — в update() раз в кадр. close() возвращает в игру.

var game  # корень игры (scripts/game.gd): открывает и закрывает окна
var world: World
var msg := ""
var msg_col := Pal.GOLD
var msg_t := 0
var t := 0
var _canvas: Node2D


var inv: Inventory:
	get: return GameState.inv


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.draw.connect(func(): draw_ui(_canvas))
	add_child(_canvas)


func _physics_process(_delta: float) -> void:
	t += 1
	if msg_t > 0:
		msg_t -= 1
	update()
	_canvas.queue_redraw()


func update() -> void:
	pass


func draw_ui(_c: CanvasItem) -> void:
	pass


func say(text: String, col := Pal.GOLD) -> void:
	msg = text
	msg_col = col
	msg_t = 110


func close() -> void:
	game.close_overlay()


## Затемнение мира под окном.
func dim(c: CanvasItem, amount: float) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.get_viewport_rect().size), Color(Pal.BLACK, amount))


## Табличка с заголовком по центру.
static func title_plate(c: CanvasItem, cx: float, y: float, text: String, col := Pal.GOLD) -> void:
	var w := UiKit.width(text) + 24
	UiKit.panel(c, Rect2(roundf(cx - w / 2), y, w, 18), Pal.DARK_WOOD, col, Pal.RED)
	UiKit.text_center(c, cx, y + 5, text, col, Pal.NIGHT)


## Ячейка с иконкой предмета x2.
static func item_box(c: CanvasItem, x: float, y: float, size: float, it: Dictionary, count := 0) -> void:
	c.draw_rect(Rect2(x, y, size, size), Pal.BLACK)
	c.draw_rect(Rect2(x + 0.5, y + 0.5, size - 1, size - 1), Pal.STONE, false, 1.0)
	if not it.is_empty():
		var off := (size - 32) / 2
		c.draw_texture_rect(Icons.of(it), Rect2(x + off, y + off, 32, 32), false)
		if count > 1:
			UiKit.text(c, x + size - 8, y + size - 10, str(count), Pal.SNOW, Pal.BLACK)
