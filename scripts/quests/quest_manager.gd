extends Node
class_name QuestManager

signal quest_activated(quest_id: String, quest_data: Dictionary)
signal quest_progress_updated(quest_id: String, progress: float, description: String)
signal quest_completed(quest_id: String, quest_data: Dictionary)
signal main_quest_updated(current_main_id: String, name: String, progress: float)

@export var quest_data_path: String = "res://data/quests/quest_data.json"
@export var game_state_path: NodePath
@export var research_manager_path: NodePath
@export var map_manager_path: NodePath
@export var wave_manager_path: NodePath
@export var first_quest_id: String = "q01_first_generator"

var all_quests: Dictionary = {}
var active_quests: Dictionary = {}
var completed_quests: Dictionary = {}
var current_main_quest_id: String = ""
var total_buildings_built: int = 0
var nests_destroyed: Dictionary = {}
var rift_charge_percent: float = 0.0
var rift_built: bool = false
var game_state: Node
var _research_manager: Node
var _map_manager: Node
var _wave_manager: Node

func _ready() -> void:
	add_to_group("quest_manager")
	_load_quest_data()
	game_state = get_node_or_null(game_state_path)
	_research_manager = get_node_or_null(research_manager_path)
	_map_manager = get_node_or_null(map_manager_path)
	_wave_manager = get_node_or_null(wave_manager_path)
	_connect_signals()
	_start_first_quest()

func _load_quest_data() -> void:
	var file: FileAccess = FileAccess.open(quest_data_path, FileAccess.READ)
	if file == null:
		push_error("无法读取任务数据：" + quest_data_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		push_error("任务数据格式错误：" + quest_data_path)
		return
	for item in parsed:
		if item is Dictionary and item.has("id"):
			all_quests[str(item["id"])] = item

func _connect_signals() -> void:
	if game_state != null:
		game_state.resource_changed.connect(_on_resource_changed)
	if _research_manager != null:
		_research_manager.research_changed.connect(_on_research_changed)
	if _map_manager != null and _map_manager.has_signal("zone_discovered"):
		_map_manager.zone_discovered.connect(_on_zone_discovered)
	var enemies_tree: Node = get_tree()
	if enemies_tree != null:
		enemies_tree.connect("node_added", Callable(self, "_on_node_added"))
		for nest in enemies_tree.get_nodes_in_group("enemy_nests"):
			if nest != null and nest.has_signal("nest_destroyed"):
				nest.nest_destroyed.connect(_on_nest_destroyed.bind(nest))

func _start_first_quest() -> void:
	if all_quests.has(first_quest_id):
		_activate_quest(first_quest_id)

func _activate_quest(quest_id: String) -> void:
	if active_quests.has(quest_id) or completed_quests.has(quest_id):
		return
	if not all_quests.has(quest_id):
		return
	var quest_data: Dictionary = all_quests[quest_id]
	active_quests[quest_id] = {"progress": 0.0, "data": quest_data}
	quest_activated.emit(quest_id, quest_data)
	if quest_data.get("is_main", false):
		current_main_quest_id = quest_id
		main_quest_updated.emit(quest_id, str(quest_data.get("name", quest_id)), 0.0)
	if game_state != null:
		game_state.show_message("新任务：%s" % str(quest_data.get("name", quest_id)))
	_check_initial_quest_completion(quest_id)

func _check_initial_quest_completion(quest_id: String) -> void:
	var quest: Dictionary = active_quests[quest_id]["data"]
	var q_type: String = str(quest.get("type", ""))
	match q_type:
		"collect":
			_update_collect_quest(quest_id)
		"build":
			_update_build_quest(quest_id)
		"build_total":
			_update_build_total_quest(quest_id)
		"research":
			_update_research_quest(quest_id)
		"destroy_nests":
			_update_destroy_nests_quest(quest_id)
		"rift_charge":
			_update_rift_charge_quest(quest_id)
		"reach_zone":
			pass
		"survive_wave":
			pass

func _on_resource_changed(_resource_id: String, _amount: int) -> void:
	for quest_id in active_quests.keys():
		var quest: Dictionary = active_quests[quest_id]["data"]
		var q_type: String = str(quest.get("type", ""))
		if q_type == "collect":
			_update_collect_quest(quest_id)

func _on_research_changed(_unlocked_ids: Array[String]) -> void:
	for quest_id in active_quests.keys():
		var quest: Dictionary = active_quests[quest_id]["data"]
		var q_type: String = str(quest.get("type", ""))
		if q_type == "research":
			_update_research_quest(quest_id)

func _on_zone_discovered(zone_id: String, _zone_name: String) -> void:
	for quest_id in active_quests.keys():
		var quest: Dictionary = active_quests[quest_id]["data"]
		var q_type: String = str(quest.get("type", ""))
		if q_type == "reach_zone":
			var target_zone: String = str(quest.get("target", {}).get("zone_id", ""))
			if target_zone == zone_id:
				_complete_quest(quest_id)

func _on_node_added(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.is_in_group("enemy_nests") and node.has_signal("nest_destroyed"):
		node.nest_destroyed.connect(_on_nest_destroyed.bind(node))

func _on_nest_destroyed(nest: Node) -> void:
	var zone_id: String = _get_nest_zone(nest)
	if not nests_destroyed.has(zone_id):
		nests_destroyed[zone_id] = 0
	nests_destroyed[zone_id] = int(nests_destroyed[zone_id]) + 1
	for quest_id in active_quests.keys():
		var quest: Dictionary = active_quests[quest_id]["data"]
		var q_type: String = str(quest.get("type", ""))
		if q_type == "destroy_nests":
			_update_destroy_nests_quest(quest_id)

func _get_nest_zone(nest: Node) -> String:
	if _map_manager == null or not (nest is Node2D):
		return ""
	if not _map_manager.has_method("get_all_zones"):
		return ""
	var all_zones: Dictionary = _map_manager.get_all_zones()
	var nest_pos: Vector2 = nest.global_position
	var best_zone: String = ""
	var best_dist: float = INF
	for zone_id in all_zones.keys():
		var zone: Dictionary = all_zones[zone_id]
		var zone_pos: Vector2 = Vector2(
			float(zone.get("center_x", 0)),
			float(zone.get("center_y", 0))
		)
		var dist: float = nest_pos.distance_to(zone_pos)
		var radius: float = float(zone.get("radius", 500))
		if dist <= radius and dist < best_dist:
			best_dist = dist
			best_zone = zone_id
	return best_zone

func notify_building_built(building_type: String) -> void:
	total_buildings_built += 1
	for quest_id in active_quests.keys():
		var quest: Dictionary = active_quests[quest_id]["data"]
		var q_type: String = str(quest.get("type", ""))
		if q_type == "build":
			_update_build_quest(quest_id)
		elif q_type == "build_total":
			_update_build_total_quest(quest_id)

func notify_rift_built() -> void:
	rift_built = true
	_update_rift_quests()

func notify_rift_charge_changed(percent: float) -> void:
	rift_charge_percent = percent
	_update_rift_quests()

func _update_rift_quests() -> void:
	for quest_id in active_quests.keys():
		var quest: Dictionary = active_quests[quest_id]["data"]
		var q_type: String = str(quest.get("type", ""))
		if q_type == "rift_charge":
			_update_rift_charge_quest(quest_id)

func _update_collect_quest(quest_id: String) -> void:
	if game_state == null:
		return
	var quest: Dictionary = active_quests[quest_id]["data"]
	var target_resources: Dictionary = quest.get("target", {}).get("resources", {})
	if not (target_resources is Dictionary):
		return
	var total_target: float = 0.0
	var total_current: float = 0.0
	var all_met: bool = true
	for res_id in target_resources.keys():
		var target_amount: float = float(target_resources[res_id])
		total_target += target_amount
		var current: int = 0
		if game_state.has_method("get_resource"):
			current = game_state.get_resource(str(res_id))
		total_current += min(float(current), target_amount)
		if current < int(target_amount):
			all_met = false
	var progress: float = 0.0
	if total_target > 0:
		progress = total_current / total_target
	_set_quest_progress(quest_id, progress, _get_collect_desc(target_resources))
	if all_met:
		_complete_quest(quest_id)

func _get_collect_desc(target_resources: Dictionary) -> String:
	var parts: Array[String] = []
	for res_id in target_resources.keys():
		var current: int = 0
		if game_state != null and game_state.has_method("get_resource"):
			current = game_state.get_resource(str(res_id))
		parts.append("%s %d/%d" % [_get_resource_label(str(res_id)), current, int(target_resources[res_id])])
	return "、".join(parts)

func _update_build_quest(quest_id: String) -> void:
	var quest: Dictionary = active_quests[quest_id]["data"]
	var target: Dictionary = quest.get("target", {})
	if target.has("building_type"):
		var building_type: String = str(target["building_type"])
		var target_count: int = int(target.get("count", 1))
		var current: int = _count_buildings_of_type(building_type)
		var progress: float = min(float(current) / float(target_count), 1.0)
		_set_quest_progress(quest_id, progress, "%s %d/%d" % [_get_building_label(building_type), current, target_count])
		if current >= target_count:
			_complete_quest(quest_id)
	elif target.has("buildings"):
		var buildings_target: Dictionary = target["buildings"]
		if not (buildings_target is Dictionary):
			return
		var total_target: float = 0.0
		var total_current: float = 0.0
		var all_met: bool = true
		for b_type in buildings_target.keys():
			var t_count: int = int(buildings_target[b_type])
			total_target += t_count
			var c: int = _count_buildings_of_type(str(b_type))
			total_current += min(float(c), float(t_count))
			if c < t_count:
				all_met = false
		var progress: float = 0.0
		if total_target > 0:
			progress = total_current / total_target
		_set_quest_progress(quest_id, progress, _get_multi_build_desc(buildings_target))
		if all_met:
			_complete_quest(quest_id)

func _get_multi_build_desc(buildings_target: Dictionary) -> String:
	var parts: Array[String] = []
	for b_type in buildings_target.keys():
		var current: int = _count_buildings_of_type(str(b_type))
		parts.append("%s %d/%d" % [_get_building_label(str(b_type)), current, int(buildings_target[b_type])])
	return "、".join(parts)

func _update_build_total_quest(quest_id: String) -> void:
	var quest: Dictionary = active_quests[quest_id]["data"]
	var target_count: int = int(quest.get("target", {}).get("count", 1))
	var progress: float = min(float(total_buildings_built) / float(target_count), 1.0)
	_set_quest_progress(quest_id, progress, "已建造 %d/%d" % [total_buildings_built, target_count])
	if total_buildings_built >= target_count:
		_complete_quest(quest_id)

func _update_research_quest(quest_id: String) -> void:
	if _research_manager == null:
		return
	var quest: Dictionary = active_quests[quest_id]["data"]
	var target_tech: String = str(quest.get("target", {}).get("tech_id", ""))
	var has_tech: bool = false
	if _research_manager.has_method("has_technology"):
		has_tech = _research_manager.has_technology(target_tech)
	if has_tech:
		_set_quest_progress(quest_id, 1.0, "科技已解锁")
		_complete_quest(quest_id)
	else:
		_set_quest_progress(quest_id, 0.0, "研究中...")

func _update_destroy_nests_quest(quest_id: String) -> void:
	var quest: Dictionary = active_quests[quest_id]["data"]
	var target_zone: String = str(quest.get("target", {}).get("zone_id", ""))
	var target_count: int = int(quest.get("target", {}).get("count", 1))
	var destroyed: int = int(nests_destroyed.get(target_zone, 0))
	var progress: float = min(float(destroyed) / float(target_count), 1.0)
	_set_quest_progress(quest_id, progress, "巢穴 %d/%d" % [destroyed, target_count])
	if destroyed >= target_count:
		_complete_quest(quest_id)

func _update_rift_charge_quest(quest_id: String) -> void:
	var quest: Dictionary = active_quests[quest_id]["data"]
	var target_percent: float = float(quest.get("target", {}).get("charge_percent", 100))
	if not rift_built:
		_set_quest_progress(quest_id, 0.0, "建造裂隙传送门")
		return
	var progress: float = min(rift_charge_percent / target_percent, 1.0)
	_set_quest_progress(quest_id, progress, "充能 %.0f%% / %.0f%%" % [rift_charge_percent, target_percent])
	if rift_charge_percent >= target_percent:
		_complete_quest(quest_id)

func _count_buildings_of_type(building_type: String) -> int:
	var group_name: String = ""
	match building_type:
		"sentry_tower":
			group_name = "sentry_towers"
		"wall_segment":
			group_name = "walls"
		"power_generator":
			group_name = "generators"
		"mining_drill":
			group_name = "miners"
		"research_station":
			group_name = "research_stations"
		_:
			return 0
	if group_name == "":
		return 0
	var count: int = 0
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node):
			count += 1
	return count

func _set_quest_progress(quest_id: String, progress: float, desc: String) -> void:
	if not active_quests.has(quest_id):
		return
	active_quests[quest_id]["progress"] = progress
	quest_progress_updated.emit(quest_id, progress, desc)
	var quest_data: Dictionary = active_quests[quest_id]["data"]
	if quest_data.get("is_main", false) and quest_id == current_main_quest_id:
		main_quest_updated.emit(quest_id, str(quest_data.get("name", quest_id)), progress)

func _complete_quest(quest_id: String) -> void:
	if not active_quests.has(quest_id):
		return
	var quest_data: Dictionary = active_quests[quest_id]["data"]
	completed_quests[quest_id] = quest_data
	active_quests.erase(quest_id)
	_give_rewards(quest_data)
	quest_completed.emit(quest_id, quest_data)
	if game_state != null:
		game_state.show_message("任务完成：%s" % str(quest_data.get("name", quest_id)))
	var next_quest: String = str(quest_data.get("next_quest", ""))
	if next_quest != "" and all_quests.has(next_quest):
		_activate_quest(next_quest)
	if quest_data.get("is_final", false):
		if game_state != null and game_state.has_method("finish_game"):
			game_state.finish_game(true, "裂隙充能完成，星球已净化！")

func _give_rewards(quest_data: Dictionary) -> void:
	if game_state == null:
		return
	var rewards: Dictionary = quest_data.get("rewards", {})
	if not (rewards is Dictionary):
		return
	for res_id in rewards.keys():
		var amount: int = int(rewards[res_id])
		if amount > 0:
			game_state.add_resource(str(res_id), amount)

func _get_resource_label(resource_id: String) -> String:
	match resource_id:
		"energy":
			return "能量"
		"iron":
			return "铁"
		"carbon":
			return "碳"
		_:
			return resource_id

func _get_building_label(building_type: String) -> String:
	match building_type:
		"sentry_tower":
			return "哨兵塔"
		"wall_segment":
			return "城墙"
		"power_generator":
			return "发电机"
		"mining_drill":
			return "采矿机"
		"research_station":
			return "研究站"
		_:
			return building_type

func get_current_main_quest() -> Dictionary:
	if current_main_quest_id == "" or not active_quests.has(current_main_quest_id):
		return {}
	return active_quests[current_main_quest_id]

func get_active_quests() -> Dictionary:
	return active_quests.duplicate()

func get_completed_quests() -> Dictionary:
	return completed_quests.duplicate()

func has_completed_quest(quest_id: String) -> bool:
	return completed_quests.has(quest_id)

func notify_research_completed(tech_id: String) -> void:
	for quest_id in active_quests.keys():
		var quest: Dictionary = active_quests[quest_id]["data"]
		if str(quest.get("type", "")) == "research":
			var target: String = str(quest.get("target", {}).get("tech_id", ""))
			if target == tech_id:
				_complete_quest(quest_id)
				return

func notify_defense_won() -> void:
	for quest_id in active_quests.keys():
		var quest: Dictionary = active_quests[quest_id]["data"]
		if str(quest.get("type", "")) == "survive_wave":
			_complete_quest(quest_id)
			return
