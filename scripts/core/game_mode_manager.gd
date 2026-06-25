extends Node
class_name GameModeManager

signal mode_changed(mode_id: String)
signal survival_config_changed(config: Dictionary)

const MODE_CAMPAIGN := "campaign"
const MODE_SURVIVAL := "survival"
const MODE_SANDBOX := "sandbox"

const DIFFICULTY_EASY := "easy"
const DIFFICULTY_NORMAL := "normal"
const DIFFICULTY_HARD := "hard"

var current_mode: String = MODE_CAMPAIGN
var current_difficulty: String = DIFFICULTY_NORMAL

var survival_config: Dictionary = {
	"difficulty": DIFFICULTY_NORMAL,
	"starting_energy": 80,
	"starting_iron": 30,
	"starting_carbon": 20,
	"storage_capacity": 300,
	"difficulty_scale": 1.0
}

var sandbox_config: Dictionary = {
	"resource_multiplier": 1.0,
	"enemy_strength": 1.0,
	"wave_interval": 1.0,
	"enemies_enabled": true,
	"death_penalty_enabled": true,
	"all_tech_unlocked": false,
	"unlimited_resources": false
}

var _persistent_data: Dictionary = {}

func _ready() -> void:
	add_to_group("game_mode_manager")
	_load_persistent_data()

func set_mode(mode_id: String) -> void:
	if current_mode == mode_id:
		return
	current_mode = mode_id
	mode_changed.emit(current_mode)

func set_difficulty(difficulty_id: String) -> void:
	current_difficulty = difficulty_id
	if current_mode == MODE_SURVIVAL:
		survival_config["difficulty"] = difficulty_id
		survival_config["difficulty_scale"] = _get_difficulty_scale(difficulty_id)
		survival_config_changed.emit(survival_config)

func apply_mode_config(mode_id: String, config: Dictionary) -> void:
	match mode_id:
		MODE_SURVIVAL:
			survival_config.merge(config)
			survival_config_changed.emit(survival_config)
		MODE_SANDBOX:
			sandbox_config.merge(config)

func get_mode_name(mode_id: String) -> String:
	match mode_id:
		MODE_CAMPAIGN:
			return "战役模式"
		MODE_SURVIVAL:
			return "生存模式"
		MODE_SANDBOX:
			return "沙盒模式"
	return "未知模式"

func get_difficulty_name(difficulty_id: String) -> String:
	match difficulty_id:
		DIFFICULTY_EASY:
			return "简单"
		DIFFICULTY_NORMAL:
			return "普通"
		DIFFICULTY_HARD:
			return "困难"
	return "未知"

func get_starting_resources() -> Dictionary:
	match current_mode:
		MODE_CAMPAIGN:
			return {
				"energy": 0,
				"iron": 0,
				"carbon": 0,
				"storage": 240
			}
		MODE_SURVIVAL:
			return {
				"energy": int(survival_config.get("starting_energy", 80)),
				"iron": int(survival_config.get("starting_iron", 30)),
				"carbon": int(survival_config.get("starting_carbon", 20)),
				"storage": int(survival_config.get("storage_capacity", 300))
			}
		MODE_SANDBOX:
			var mult: float = float(sandbox_config.get("resource_multiplier", 1.0))
			return {
				"energy": int(200 * mult),
				"iron": int(100 * mult),
				"carbon": int(80 * mult),
				"storage": int(500 * mult)
			}
	return {}

func should_start_survival() -> bool:
	return current_mode == MODE_SURVIVAL

func is_sandbox_unlimited_resources() -> bool:
	return current_mode == MODE_SANDBOX and sandbox_config.get("unlimited_resources", false)

func is_sandbox_all_tech() -> bool:
	return current_mode == MODE_SANDBOX and sandbox_config.get("all_tech_unlocked", false)

func are_enemies_enabled() -> bool:
	if current_mode == MODE_SANDBOX:
		return sandbox_config.get("enemies_enabled", true)
	return true

func is_death_penalty_enabled() -> bool:
	if current_mode == MODE_SANDBOX:
		return sandbox_config.get("death_penalty_enabled", true)
	return true

func get_survival_difficulty_scale() -> float:
	return float(survival_config.get("difficulty_scale", 1.0))

func _get_difficulty_scale(difficulty_id: String) -> float:
	match difficulty_id:
		DIFFICULTY_EASY:
			return 0.7
		DIFFICULTY_NORMAL:
			return 1.0
		DIFFICULTY_HARD:
			return 1.5
	return 1.0

func save_score(mode_id: String, score_data: Dictionary) -> void:
	var key: String = "leaderboard_%s" % mode_id
	if not _persistent_data.has(key):
		_persistent_data[key] = []
	var scores: Array = _persistent_data[key]
	score_data["date"] = Time.get_datetime_string_from_system()
	scores.append(score_data)
	scores.sort_custom(func(a, b):
		return int(a.get("wave", 0)) > int(b.get("wave", 0)))
	if scores.size() > 10:
		scores.resize(10)
	_persistent_data[key] = scores
	_save_persistent_data()

func get_leaderboard(mode_id: String) -> Array:
	var key: String = "leaderboard_%s" % mode_id
	return _persistent_data.get(key, [])

func _load_persistent_data() -> void:
	var file := FileAccess.open("user://game_data.json", FileAccess.READ)
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if typeof(parsed) == TYPE_DICTIONARY:
		_persistent_data = parsed

func _save_persistent_data() -> void:
	var file := FileAccess.open("user://game_data.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_persistent_data))
	file.close()
