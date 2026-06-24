extends Node
class_name MissionManager

signal mission_changed(title: String, objective_text: String, progress_text: String)
signal campaign_completed

@export var game_state_path: NodePath
@export var research_manager_path: NodePath
@export var map_manager_path: NodePath
@export var mission_data_path: String = "res://data/missions/campaign_missions.json"

var mission_definitions: Array[Dictionary] = []
var completed_missions: Array[String] = []
var current_mission_index: int = 0

var _game_state: Node
var _research_manager: Node
var _map_manager: Node
var _highest_wave_reached: int = 0
var _evaluate_timer: float = 0.0

func _ready() -> void:
	add_to_group("mission_manager")
	_game_state = get_node(game_state_path)
	_research_manager = get_node_or_null(research_manager_path)
	_map_manager = get_node_or_null(map_manager_path)
	_load_mission_data()
	_connect_progress_signals()
	call_deferred("_evaluate_current_mission")

func _process(delta: float) -> void:
	_evaluate_timer -= delta
	if _evaluate_timer <= 0.0:
		_evaluate_timer = 0.35
		_evaluate_current_mission()

func get_current_mission() -> Dictionary:
	if current_mission_index >= mission_definitions.size():
		return {}
	return mission_definitions[current_mission_index]

func get_current_mission_title() -> String:
	var mission: Dictionary = get_current_mission()
	return str(mission.get("title", "战役完成"))

func get_current_objective_text() -> String:
	var mission: Dictionary = get_current_mission()
	if mission.is_empty():
		return "所有主线目标已完成"
	return _format_objective(mission.get("objective", {}))

func get_mission_status_text() -> String:
	return "任务：%d/%d" % [completed_missions.size(), mission_definitions.size()]

func notify_progress_changed() -> void:
	_evaluate_current_mission()

func _load_mission_data() -> void:
	var file: FileAccess = FileAccess.open(mission_data_path, FileAccess.READ)
	if file == null:
		push_error("无法读取任务数据：" + mission_data_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		push_error("任务数据格式错误：" + mission_data_path)
		return
	for item in parsed:
		if item is Dictionary and item.has("id"):
			mission_definitions.append(item)

func _connect_progress_signals() -> void:
	_game_state.resource_changed.connect(_on_progress_changed)
	_game_state.wave_status_changed.connect(_on_wave_status_changed)
	if _research_manager != null:
		_research_manager.research_changed.connect(_on_progress_changed)
	if _map_manager != null:
		_map_manager.map_unlocked.connect(_on_map_unlocked)
		_map_manager.map_changed.connect(_on_progress_changed)

func _evaluate_current_mission() -> void:
	var advanced: bool = false
	while current_mission_index < mission_definitions.size():
		var mission: Dictionary = mission_definitions[current_mission_index]
		if not _objective_met(mission.get("objective", {})):
			break
		completed_missions.append(str(mission["id"]))
		current_mission_index += 1
		advanced = true
		if _game_state != null:
			_game_state.show_message("任务完成：%s" % str(mission.get("title", mission["id"])))
	if current_mission_index >= mission_definitions.size():
		_emit_mission_state()
		if advanced:
			campaign_completed.emit()
			_game_state.show_message("战役目标链完成，裂隙工程已进入下一阶段")
		return
	_emit_mission_state()

func _objective_met(objective: Dictionary) -> bool:
	match str(objective.get("type", "")):
		"resource":
			return _game_state.get_resource(str(objective.get("resource_id", ""))) >= int(objective.get("amount", 0))
		"group_count":
			return get_tree().get_nodes_in_group(str(objective.get("group", ""))).size() >= int(objective.get("count", 0))
		"research":
			return _research_manager != null and _research_manager.has_technology(str(objective.get("tech_id", "")))
		"map_unlocked":
			return _map_manager != null and _map_manager.unlocked_maps.has(str(objective.get("map_id", "")))
		"survive_wave":
			return _highest_wave_reached >= int(objective.get("wave", 0))
		_:
			return false

func _format_objective(objective: Dictionary) -> String:
	match str(objective.get("type", "")):
		"resource":
			return "储备%s %d" % [_resource_label(str(objective.get("resource_id", ""))), int(objective.get("amount", 0))]
		"group_count":
			return "建造 %s x%d" % [_group_label(str(objective.get("group", ""))), int(objective.get("count", 0))]
		"research":
			return "完成科技：%s" % _research_label(str(objective.get("tech_id", "")))
		"map_unlocked":
			return "解锁区域：%s" % _map_label(str(objective.get("map_id", "")))
		"survive_wave":
			return "守住第 %d 波敌潮" % int(objective.get("wave", 0))
		_:
			return "等待任务目标"

func _emit_mission_state() -> void:
	mission_changed.emit(get_current_mission_title(), get_current_objective_text(), get_mission_status_text())

func _on_progress_changed(_a = null, _b = null, _c = null) -> void:
	_evaluate_current_mission()

func _on_wave_status_changed(wave: int, status: String, _countdown: float, _enemies_alive: int) -> void:
	if status == "清场":
		_highest_wave_reached = max(_highest_wave_reached, wave)
	_evaluate_current_mission()

func _on_map_unlocked(_map_id: String, _map_name: String) -> void:
	_evaluate_current_mission()

func _resource_label(resource_id: String) -> String:
	match resource_id:
		"energy":
			return "能量"
		"iron":
			return "铁"
		"carbon":
			return "碳"
		_:
			return resource_id

func _group_label(group_name: String) -> String:
	match group_name:
		"defense_towers":
			return "哨兵塔"
		"research_stations":
			return "研究站"
		_:
			return group_name

func _research_label(tech_id: String) -> String:
	if _research_manager != null and _research_manager.tech_definitions.has(tech_id):
		return str(_research_manager.tech_definitions[tech_id].get("name", tech_id))
	return tech_id

func _map_label(map_id: String) -> String:
	if _map_manager != null and _map_manager.map_definitions.has(map_id):
		return str(_map_manager.map_definitions[map_id].get("name", map_id))
	return map_id
