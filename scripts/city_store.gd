extends RefCounted

const Network = preload("res://scripts/streets_model.gd")
var base_path := "user://city.json"


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 8388608:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var data = parser.data
	if not data is Dictionary or data.get("schema") != 1:
		return {}
	var seed_value = data.get("seed")
	if not (seed_value is int or seed_value is float):
		return {}
	if not is_finite(seed_value) or seed_value < 0 or seed_value > 2147483000 or seed_value != int(seed_value):
		return {}
	if Network.restore(data) == null:
		return {}
	return data


func load_city() -> Dictionary:
	var data := _read(base_path)
	if data.is_empty():
		data = _read(base_path + ".bak")
	return data


func save_city(seed_value: int, model: RefCounted) -> bool:
	var data: Dictionary = model.serialize()
	data["schema"] = 1
	data["seed"] = seed_value
	var temp := base_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if _read(temp).is_empty():
		return false
	var main_abs := ProjectSettings.globalize_path(base_path)
	var backup_abs := main_abs + ".bak"
	if FileAccess.file_exists(base_path):
		if not _read(base_path).is_empty():
			if FileAccess.file_exists(backup_abs):
				DirAccess.remove_absolute(backup_abs)
			if DirAccess.rename_absolute(main_abs, backup_abs) != OK:
				return false
		else:
			if DirAccess.remove_absolute(main_abs) != OK:
				return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), main_abs) != OK:
		if FileAccess.file_exists(backup_abs):
			DirAccess.copy_absolute(backup_abs, main_abs)
		return false
	return true
