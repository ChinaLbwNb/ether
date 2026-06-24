extends Node
class_name MapManager

signal zone_changed(zone_id: String, zone_name: String)
signal zone_discovered(zone_id: String, zone_name: String)
signal biome_modifier_changed(modifier_id: String, value: float)

@export var zones_data_path: String = "res://data/maps/map_zones.json"
@export var player_path: NodePath
@export var game_state_path: NodePath
@export var fog_reveal_radius: float = 350.0
@export var discovery_check_interval: float = 0.5

var zones: Dictionary = {}
var discovered_zones: Dictionary = {}
var current_zone_id: String = ""
var game_state: Node
var _player: Node2D
var _discovery_check_timer: float = 0.0
var _active_modifiers: Dictionary = {}

func _ready() -> void:
	add_to_group("map_manager")
	_load_zones()
	_player = get_node_or_null(player_path)
	game_state = get_node_or_null(game_state_path)
	for zone_id in zones.keys():
		var zone: Dictionary = zones[zone_id]
		if zone.get("fog_revealed", false):
			discovered_zones[zone_id] = true
	_initial_zone_check()
	_emit_initial_state()

func _process(delta: float) -> void:
	_discovery_check_timer -= delta
	if _discovery_check_timer <= 0.0:
		_discovery_check_timer = discovery_check_interval
		_check_zone_discovery()
		_update_current_zone()
		_update_biome_effects(delta)

func _load_zones() -> void:
	var file: FileAccess = FileAccess.open(zones_data_path, FileAccess.READ)
	if file == null:
		push_error("无法读取区域数据：" + zones_data_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		push_error("区域数据格式错误：" + zones_data_path)
		return
	for item in parsed:
		if item is Dictionary and item.has("id"):
			zones[str(item["id"])] = item

func _initial_zone_check() -> void:
	if _player == null:
		return
	var player_pos: Vector2 = _player.global_position
	var closest_zone_id: String = ""
	var closest_dist: float = INF
	for zone_id in zones.keys():
		var zone: Dictionary = zones[zone_id]
		var zone_pos: Vector2 = Vector2(
			float(zone.get("center_x", 0)),
			float(zone.get("center_y", 0))
		)
		var dist: float = player_pos.distance_to(zone_pos)
		var radius: float = float(zone.get("radius", 500))
		if dist <= radius and dist < closest_dist:
			closest_dist = dist
			closest_zone_id = zone_id
	if closest_zone_id != "":
		current_zone_id = closest_zone_id

func _check_zone_discovery() -> void:
	if _player == null:
		return
	var player_pos: Vector2 = _player.global_position
	for zone_id in zones.keys():
		if discovered_zones.has(zone_id):
			continue
		var zone: Dictionary = zones[zone_id]
		var zone_pos: Vector2 = Vector2(
			float(zone.get("center_x", 0)),
			float(zone.get("center_y", 0))
		)
		var dist: float = player_pos.distance_to(zone_pos)
		var radius: float = float(zone.get("radius", 500))
		if dist <= radius + fog_reveal_radius * 0.5:
			discovered_zones[zone_id] = true
			zone_discovered.emit(zone_id, str(zone.get("name", zone_id)))
			if game_state != null:
				game_state.show_message("发现新区域：%s" % str(zone.get("name", zone_id)))

func _update_current_zone() -> void:
	if _player == null:
		return
	var player_pos: Vector2 = _player.global_position
	var closest_zone_id: String = ""
	var closest_dist: float = INF
	for zone_id in zones.keys():
		var zone: Dictionary = zones[zone_id]
		var zone_pos: Vector2 = Vector2(
			float(zone.get("center_x", 0)),
			float(zone.get("center_y", 0))
		)
		var dist: float = player_pos.distance_to(zone_pos)
		var radius: float = float(zone.get("radius", 500))
		if dist <= radius and dist < closest_dist:
			closest_dist = dist
			closest_zone_id = zone_id
	if closest_zone_id != "" and closest_zone_id != current_zone_id:
		current_zone_id = closest_zone_id
		var zone_name: String = str(zones[closest_zone_id].get("name", closest_zone_id))
		zone_changed.emit(current_zone_id, zone_name)
		if game_state != null:
			game_state.show_message("进入：%s" % zone_name)
		_apply_biome_modifiers(zones[closest_zone_id])
	elif closest_zone_id == "" and current_zone_id != "":
		current_zone_id = ""
		zone_changed.emit("", "荒野")
		_clear_biome_modifiers()

func _apply_biome_modifiers(zone: Dictionary) -> void:
	_clear_biome_modifiers()
	var modifiers: Dictionary = zone.get("modifiers", {})
	if not (modifiers is Dictionary):
		return
	for mod_id in modifiers.keys():
		_active_modifiers[str(mod_id)] = modifiers[mod_id]
		biome_modifier_changed.emit(str(mod_id), float(modifiers[mod_id]))

func _clear_biome_modifiers() -> void:
	for mod_id in _active_modifiers.keys():
		biome_modifier_changed.emit(str(mod_id), 0.0)
	_active_modifiers.clear()

func _update_biome_effects(delta: float) -> void:
	if _active_modifiers.is_empty():
		return
	var building_dps: float = float(_active_modifiers.get("building_damage_per_second", 0))
	if building_dps > 0 and _player != null:
		_damage_nearby_buildings(building_dps * delta)

func _damage_nearby_buildings(damage: float) -> void:
	if _player == null or game_state == null or game_state.is_finished:
		return
	var player_pos: Vector2 = _player.global_position
	for building in get_tree().get_nodes_in_group("repairable_buildings"):
		if not is_instance_valid(building) or not (building is Node2D):
			continue
		if not building.has_method("take_damage"):
			continue
		var dist: float = player_pos.distance_to(building.global_position)
		if dist < 500.0:
			building.take_damage(int(ceil(damage)))

func get_current_zone() -> Dictionary:
	if current_zone_id == "" or not zones.has(current_zone_id):
		return {}
	return zones[current_zone_id]

func get_current_biome() -> String:
	var zone: Dictionary = get_current_zone()
	return str(zone.get("biome", "unknown"))

func get_modifier(modifier_id: String) -> float:
	return float(_active_modifiers.get(modifier_id, 0.0))

func has_modifier(modifier_id: String) -> bool:
	return _active_modifiers.has(modifier_id)

func is_zone_discovered(zone_id: String) -> bool:
	return discovered_zones.has(zone_id)

func get_zone_data(zone_id: String) -> Dictionary:
	if zones.has(zone_id):
		return zones[zone_id]
	return {}

func get_all_zones() -> Dictionary:
	return zones.duplicate()

func _emit_initial_state() -> void:
	if current_zone_id != "" and zones.has(current_zone_id):
		var zone_name: String = str(zones[current_zone_id].get("name", current_zone_id))
		zone_changed.emit(current_zone_id, zone_name)
