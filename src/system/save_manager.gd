class_name SaveManager
extends RefCounted

const SAVE_PATH = "user://player_save.json"
const DEFAULT_BEANS = 200000

static func get_default_data() -> Dictionary:
	return {
		"beans": DEFAULT_BEANS,
		"games_played": 0,
		"wins": 0,
		"total_hus": 0,
		"highest_win_beans": 0,
		"highest_pattern": "无",
		"refill_count": 0,
		"sound_enabled": true,
		"bgm_enabled": true
	}

static func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		var default_data = get_default_data()
		save_data(default_data)
		return default_data

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return get_default_data()

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_str)
	if parse_result != OK:
		return get_default_data()

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return get_default_data()

	# Ensure all fields exist
	var defaults = get_default_data()
	for key in defaults.keys():
		if not data.has(key):
			data[key] = defaults[key]

	return data

static func save_data(data: Dictionary) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

static func get_beans() -> int:
	var data = load_data()
	return int(data.get("beans", DEFAULT_BEANS))

static func update_beans(delta: int) -> int:
	var data = load_data()
	var current = int(data.get("beans", DEFAULT_BEANS))
	current += delta
	if current < 0:
		current = 0
	data["beans"] = current
	save_data(data)
	return current

static func refill_beans(amount: int) -> int:
	var data = load_data()
	var current = int(data.get("beans", DEFAULT_BEANS))
	current += amount
	data["beans"] = current
	data["refill_count"] = int(data.get("refill_count", 0)) + 1
	save_data(data)
	return current

static func record_round_end(beans_delta: int, hus: int, best_pattern: String) -> void:
	var data = load_data()
	data["games_played"] = int(data.get("games_played", 0)) + 1
	if beans_delta > 0:
		data["wins"] = int(data.get("wins", 0)) + 1
		if beans_delta > int(data.get("highest_win_beans", 0)):
			data["highest_win_beans"] = beans_delta
	data["total_hus"] = int(data.get("total_hus", 0)) + hus
	if best_pattern != "" and best_pattern != "无":
		data["highest_pattern"] = best_pattern
	save_data(data)
