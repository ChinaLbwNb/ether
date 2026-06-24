extends Node
class_name ResearchManager

signal research_changed(unlocked_ids: Array[String])
signal station_count_changed(count: int)

@export var game_state_path: NodePath
@export var player_path: NodePath
@export var tech_data_path: String = "res://data/research/basic_techs.json"

var tech_definitions: Dictionary = {}
var unlocked_techs: Array[String] = []
var station_count: int = 0

var _game_state: Node
var _player: Node

func _ready() -> void:
	add_to_group("research_manager")
	_game_state = get_node(game_state_path)
	_player = get_node(player_path)
	_load_tech_data()
	call_deferred("_broadcast_initial_state")

func register_station() -> void:
	station_count += 1
	station_count_changed.emit(station_count)

func unregister_station() -> void:
	station_count = maxi(station_count - 1, 0)
	station_count_changed.emit(station_count)

func has_technology(tech_id: String) -> bool:
	return unlocked_techs.has(tech_id)

func get_available_techs() -> Array[Dictionary]:
	var techs: Array[Dictionary] = []
	for tech_id in tech_definitions.keys():
		var tech: Dictionary = tech_definitions[tech_id]
		if not has_technology(str(tech_id)) and _requirements_met(tech):
			techs.append(tech)
	return techs

func try_research(tech_id: String) -> bool:
	if station_count <= 0:
		_game_state.show_message("需要先建造研究站")
		return false
	if has_technology(tech_id):
		_game_state.show_message("科技已完成")
		return false
	if not tech_definitions.has(tech_id):
		_game_state.show_message("未知科技")
		return false
	var tech: Dictionary = tech_definitions[tech_id]
	if not _requirements_met(tech):
		_game_state.show_message("前置科技不足")
		return false
	var costs: Dictionary = tech.get("costs", {})
	if not _game_state.spend_resources(costs):
		_game_state.show_message("研究资源不足，需要 %s" % _game_state.format_cost(costs))
		return false
	unlocked_techs.append(tech_id)
	_apply_technology(tech_id)
	research_changed.emit(unlocked_techs.duplicate())
	_game_state.show_message("研究完成：%s" % str(tech.get("name", tech_id)))
	return true

func apply_building_research(building: Node) -> void:
	if has_technology("tower_overdrive") and building is SentryTower:
		building.apply_research_bonus("tower_overdrive")
	if has_technology("mining_efficiency") and building is MiningDrill:
		building.apply_research_bonus("mining_efficiency")
	if has_technology("generator_efficiency") and building is PowerGenerator:
		building.apply_research_bonus("generator_efficiency")
	if has_technology("wall_plating") and building is WallSegment:
		building.apply_research_bonus("wall_plating")

func get_unlocked_text() -> String:
	if unlocked_techs.is_empty():
		return "科技：无"
	var names: Array[String] = []
	for tech_id in unlocked_techs:
		var tech: Dictionary = tech_definitions.get(tech_id, {})
		names.append(str(tech.get("name", tech_id)))
	return "科技：" + "、".join(names)

func _load_tech_data() -> void:
	var file: FileAccess = FileAccess.open(tech_data_path, FileAccess.READ)
	if file == null:
		push_error("无法读取科技数据：" + tech_data_path)
		return
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Array):
		push_error("科技数据格式错误：" + tech_data_path)
		return
	for item in parsed:
		if not (item is Dictionary) or not item.has("id"):
			continue
		tech_definitions[str(item["id"])] = item

func _requirements_met(tech: Dictionary) -> bool:
	for required_id in tech.get("requires", []):
		if not has_technology(str(required_id)):
			return false
	return true

func _apply_technology(tech_id: String) -> void:
	if tech_id == "mech_mk2" and _player != null and _player.has_method("apply_research_bonus"):
		_player.apply_research_bonus(tech_id)
	for node in get_tree().get_nodes_in_group("build_blockers"):
		if is_instance_valid(node):
			apply_building_research(node)

func _broadcast_initial_state() -> void:
	station_count_changed.emit(station_count)
	research_changed.emit(unlocked_techs.duplicate())
