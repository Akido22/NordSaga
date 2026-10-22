extends Node
## Сохранение и загрузка (JSON в папке пользователя Godot).
## Формат v2 совпадает с Pyxel-версией.

const SAVE_VERSION := 2

var path := "user://save.json"  # тесты подменяют путь, чтобы не трогать настоящее сохранение


func exists() -> bool:
	return load_data() != null


## Атомарная запись: сначала во временный файл, потом замена. true — успех.
func write(data: Dictionary) -> bool:
	var payload := data.duplicate()
	payload["version"] = SAVE_VERSION
	var t := Time.get_datetime_dict_from_system()
	payload["saved_at"] = "%02d.%02d.%d %02d:%02d" % [t.day, t.month, t.year, t.hour, t.minute]
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "  ", false))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK


## Читает сохранение; при отсутствии или порче файла возвращает null.
func load_data():
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("version", 0)) != SAVE_VERSION:
		return null
	return parsed


func delete() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
