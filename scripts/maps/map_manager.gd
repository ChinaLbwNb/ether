extends Node
class_name MapManager

signal map_changed(map_id: String, map_name: String, biome: String)
signal map_unlocked(map_id: String, map_name: String)

@export var game_state_path: NodePath
@export var map_data_path: String = "res://data/maps/map_regions.json"

var map_definitions: Dictionary = {}
var map_order: Array[String] = []
var unlocked_maps: Array[String] = []
var current_map_id: String = "home_base"

var _game_state: Node

func _ready() -> void:
	add_to_group("map_manager")
	_game_state = get_node(game_state_path)
	_load_map_data()
	if unlocked_maps.is_empty() and map_definitions.has(current_map_id):
		unlocked_maps.append(current_map_id)
	call_deferred("_broadcast_current_map")

func unlock_next_map() -> bool:
	for map_id in map_order:
		if not unlocked_maps.has(map_id):
			return unlock_map(map_id)
	_game_state.show_message("所有已知区域都已解锁")
	return false

func unlock_map(map_id: String) -> bool:
	if not map_definitions.has(map_id):
		_game_state.show_message("未知地图区域")
		return false
	if unlocked_maps.has(map_id):
		_game_state.show_message("区域已解锁")
		return false
	var definition: Dictionary = map_definitions[map_id]
	var costs: Dictionary = definition.get("unlock_costs", {})
	if not _game_state.spend_resources(costs):
		_game_state.show_message("解锁区域需要 %s" % _game_state.format_cost(costs))
		return false
	unlocked_maps.append(map_id)
	map_unlocked.emit(map_id, str(definition.get("name", map_id)))
	_game_state.show_message("区域已解锁：%s" % str(definition.get("name", map_id)))
	return true

func travel_to_next_unlocked() -> bool:
	if unlocked_maps.is_empty():
		return false
	var index: int = unlocked_maps.find(current_map_id)
	if index < 0:
		index = 0
	var next_index: int = (index + 1) % unlocked_maps.size()
	return travel_to_map(unlocked_maps[next_index])

func travel_to_map(map_id: String) -> bool:
	if not unlocked_maps.has(map_id) or not map_definitions.has(map_id):
		_game_state.show_message("区域尚未解锁")
		return false
	current_map_id = map_id
	_broadcast_current_map()
	_game_state.show_message("已传送至：%s" % get_current_map_name())
	return true

func apply_resource_yield(resource_id: String, amount: int) -> int:
	var definition: Dictionary = get_current_definition()
	var multipliers: Dictionary = definition.get("resource_multipliers", {})
	var multiplier: float = float(multipliers.get(resource_id, 1.0))
	return maxi(int(round(float(amount) * multiplier)), 1)

func get_enemy_pressure_bonus() -> int:
	return int(get_current_definition().get("enemy_pressure", 0))

func get_current_map_name() -> String:
	return str(get_current_definition().get("name", current_map_id))

func get_current_biome() -> String:
	return str(get_current_definition().get("biome", "未知"))

func get_current_definition() -> Dictionary:
	return map_definitions.get(current_map_id, {})

func get_map_status_text() -> String:
	return "区域：%s / %s  已解锁 %d/%d" % [
		get_current_map_name(),
		get_current_biome(),
		unlocked_maps.size(),
		map_order.size()
	]

func _load_map_data() -> void:
	var file: FileAccess = FileAccess.open(map_data_path, FileAccess.READ)
	if file == null:
		push_error("无法读取地图数据：" + map_data_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		push_error("地图数据格式错误：" + map_data_path)
		return
	for item in parsed:
		if item is Dictionary and item.has("id"):
			var map_id: String = str(item["id"])
			map_definitions[map_id] = item
			map_order.append(map_id)

func _broadcast_current_map() -> void:
	map_changed.emit(current_map_id, get_current_map_name(), get_current_biome())
