extends Node
## Баланс игры: таблицы из data/json/*.json.
## Основной файл — data/*.toml; JSON собирает из него tools/toml_to_json.py (шаг 2).
## При экспорте добавить «*.json» в фильтр ресурсов, иначе файлы не попадут в сборку.

const JSON_DIR := "res://data/json"

var tables := {}  # "items" -> {...}, "enemies" -> {...}


func _ready() -> void:
	load_all()


func load_all() -> void:
	tables.clear()
	var dir := DirAccess.open(JSON_DIR)
	if dir == null:
		return  # таблиц ещё нет
	for file in dir.get_files():
		if file.get_extension() == "json":
			tables[file.get_basename()] = _read(JSON_DIR.path_join(file))


## Таблица целиком; отсутствие — ошибка данных.
func table(id: String) -> Dictionary:
	if not tables.has(id):
		push_error("Данные: нет таблицы «%s» в %s" % [id, JSON_DIR])
		return {}
	return tables[id]


func _read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Данные: не удалось прочитать %s" % path)
		return {}
	return parsed
