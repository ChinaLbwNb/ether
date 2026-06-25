extends Node2D
class_name GameRoot

@export var game_state_path: NodePath
@export var player_path: NodePath
@export var base_path: NodePath
@export var towers_root_path: NodePath
@export var walls_root_path: NodePath
@export var production_root_path: NodePath
@export var research_manager_path: NodePath
@export var quest_manager_path: NodePath
@export var tower_scene: PackedScene
@export var wall_scene: PackedScene
@export var miner_scene: PackedScene
@export var generator_scene: PackedScene
@export var research_station_scene: PackedScene
@export var rift_portal_scene: PackedScene
@export var collect_radius: float = 110.0
@export var build_radius: float = 480.0
@export var build_grid_size: float = 64.0
@export var tower_block_radius: float = 78.0
@export var resource_block_radius: float = 96.0
@export var base_block_radius: float = 135.0
@export var player_attack_range: float = 360.0
@export var player_attack_damage: int = 14
@export var player_attack_interval: float = 0.35
@export var cursor_target_radius: float = 76.0
@export var repair_amount: int = 35
@export var repair_cost: int = 5

var game_state: Node
var _player: Node2D
var _base_core: Node2D
var _towers_root: Node
var _walls_root: Node
var _production_root: Node
var _research_manager: Node
var _quest_manager: Node
var _build_mode: String = ""
var _build_rotation_degrees: float = 0.0
var _player_attack_cooldown: float = 0.0

func _ready() -> void:
	game_state = get_node(game_state_path)
	_player = get_node(player_path)
	_base_core = get_node(base_path)
	_towers_root = get_node(towers_root_path)
	_walls_root = get_node(walls_root_path)
	_production_root = get_node(production_root_path)
	_research_manager = get_node_or_null(research_manager_path)
	_quest_manager = get_node_or_null(quest_manager_path)
	_base_core.health_changed.connect(game_state.set_base_health)
	_base_core.destroyed.connect(_on_base_destroyed)
	game_state.game_finished.connect(_on_game_finished)
	if _player.has_signal("mech_destroyed"):
		_player.mech_destroyed.connect(_on_mech_destroyed)

func _process(delta: float) -> void:
	_player_attack_cooldown = max(_player_attack_cooldown - delta, 0.0)
	if _is_building():
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if game_state.is_finished:
		return
	if event.is_action_pressed("interact"):
		_try_collect_resource()
	elif event.is_action_pressed("build_tower"):
		_set_build_mode("" if _build_mode == "tower" else "tower")
	elif event.is_action_pressed("build_wall"):
		_set_build_mode("" if _build_mode == "wall" else "wall")
	elif event.is_action_pressed("build_generator"):
		_set_build_mode("" if _build_mode == "generator" else "generator")
	elif event.is_action_pressed("build_miner"):
		_set_build_mode("" if _build_mode == "miner" else "miner")
	elif event.is_action_pressed("build_research_station"):
		_set_build_mode("" if _build_mode == "research" else "research")
	elif event.is_action_pressed("build_rift"):
		_set_build_mode("" if _build_mode == "rift" else "rift")
	elif event.is_action_pressed("switch_weapon"):
		_try_switch_weapon()
	elif event.is_action_pressed("upgrade_mech"):
		_try_upgrade_mech()
	elif event.is_action_pressed("rotate_building") and _is_building():
		_rotate_current_building()
	elif event.is_action_pressed("demolish_building") and not _is_building():
		_try_demolish_nearest_building()
	elif event.is_action_pressed("upgrade_tower"):
		_try_upgrade_nearest_tower()
	elif event.is_action_pressed("repair_building"):
		_try_repair_nearest_building()
	elif _is_building() and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_current_building(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_set_build_mode("")
	elif not _is_building() and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_player_attack(get_global_mouse_position())

func _set_build_mode(new_mode: String) -> void:
	_build_mode = new_mode
	if _build_mode == "tower":
		game_state.show_message("建造模式：哨兵塔，左键放置，R 旋转，右键取消")
	elif _build_mode == "wall":
		game_state.show_message("建造模式：城墙，左键放置，R 旋转，右键取消")
	elif _build_mode == "generator":
		game_state.show_message("建造模式：发电机，左键放置，R 旋转，右键取消")
	elif _build_mode == "miner":
		game_state.show_message("建造模式：采矿机，必须贴近资源点，R 旋转")
	elif _build_mode == "research":
		game_state.show_message("建造模式：研究站，左键放置，K 打开科技面板")
	elif _build_mode == "rift":
		game_state.show_message("建造模式：裂隙传送门，左键放置")
	else:
		game_state.show_message("已退出建造模式")
	queue_redraw()

func _rotate_current_building() -> void:
	_build_rotation_degrees = fmod(_build_rotation_degrees + 90.0, 360.0)
	game_state.show_message("建造朝向：%d°" % int(_build_rotation_degrees))
	queue_redraw()

func _is_building() -> bool:
	return not _build_mode.is_empty()

func _try_place_current_building(world_position: Vector2) -> void:
	if _build_mode == "tower":
		_try_place_tower(world_position)
	elif _build_mode == "wall":
		_try_place_wall(world_position)
	elif _build_mode == "generator":
		_try_place_generator(world_position)
	elif _build_mode == "miner":
		_try_place_miner(world_position)
	elif _build_mode == "research":
		_try_place_research_station(world_position)
	elif _build_mode == "rift":
		_try_place_rift_portal(world_position)
	queue_redraw()

func _try_collect_resource() -> void:
	if game_state.is_finished:
		return
	var nearest_teleporter: Node = _find_nearest_teleporter()
	if nearest_teleporter != null:
		nearest_teleporter.interact()
		return
	var nearest: Node = null
	var nearest_distance := collect_radius
	for node in get_tree().get_nodes_in_group("resource_deposits"):
		if not node.can_collect():
			continue
		var distance := _player.global_position.distance_to(node.global_position)
		if distance <= nearest_distance:
			nearest = node
			nearest_distance = distance
	if nearest == null:
		game_state.show_message("附近没有可采集资源")
		return
	var amount: int = nearest.collect()
	var accepted: int = game_state.add_resource(nearest.resource_id, amount)
	game_state.show_message("采集%s +%d" % [_get_resource_label(nearest.resource_id), accepted])

func _find_nearest_teleporter() -> Node:
	var nearest: Node = null
	var nearest_distance: float = collect_radius
	for tp in get_tree().get_nodes_in_group("teleporters"):
		if not is_instance_valid(tp) or not (tp is Node2D):
			continue
		if not tp.has_method("can_interact") or not tp.can_interact():
			continue
		var distance: float = _player.global_position.distance_to(tp.global_position)
		if distance <= nearest_distance:
			nearest = tp
			nearest_distance = distance
	return nearest

func _try_repair_nearest_building() -> void:
	if game_state.is_finished:
		return
	var target := _find_nearest_damaged_building()
	if target == null:
		game_state.show_message("附近没有需要修复的建筑")
		return
	if not game_state.spend_resources({"energy": repair_cost}):
		game_state.show_message("能量不足，修复需要 %d" % repair_cost)
		return
	target.repair(repair_amount)
	game_state.show_message("修复建筑 +%d" % repair_amount)

func _try_upgrade_nearest_tower() -> void:
	if game_state.is_finished:
		return
	var target := _find_nearest_upgradeable_tower()
	if target == null:
		game_state.show_message("附近没有可升级的哨兵塔")
		return
	var cost: int = target.get_upgrade_cost(game_state.tower_upgrade_cost)
	if not game_state.spend_resources({"energy": cost}):
		game_state.show_message("能量不足，升级需要 %d" % cost)
		return
	if target.upgrade():
		game_state.show_message("哨兵塔升级到 Lv.%d" % target.level)

func _try_switch_weapon() -> void:
	if not _player.has_method("switch_weapon"):
		return
	_player.switch_weapon()
	game_state.show_message("当前武器：%s Lv.%d" % [_player.get_active_weapon_label(), _player.weapon_level])

func _try_upgrade_mech() -> void:
	if not _player.has_method("can_upgrade_weapon") or not _player.can_upgrade_weapon():
		game_state.show_message("机甲武器已达到当前最高等级")
		return
	var costs: Dictionary = game_state.get_mech_upgrade_costs()
	if not game_state.spend_resources(costs):
		game_state.show_message("资源不足，机甲升级需要 %s" % game_state.format_cost(costs))
		return
	if _player.apply_weapon_upgrade():
		game_state.show_message("机甲武器升级到 Lv.%d" % _player.weapon_level)

func _find_nearest_upgradeable_tower() -> Node:
	var nearest: Node = null
	var nearest_distance := collect_radius
	for tower in get_tree().get_nodes_in_group("defense_towers"):
		if not is_instance_valid(tower) or not (tower is Node2D):
			continue
		if not tower.has_method("can_upgrade") or not tower.can_upgrade():
			continue
		var distance := _player.global_position.distance_to(tower.global_position)
		if distance <= nearest_distance:
			nearest = tower
			nearest_distance = distance
	return nearest

func _find_nearest_damaged_building() -> Node:
	var nearest: Node = null
	var nearest_distance := collect_radius
	for building in get_tree().get_nodes_in_group("repairable_buildings"):
		if not is_instance_valid(building) or not (building is Node2D):
			continue
		if not building.has_method("is_damaged") or not building.is_damaged():
			continue
		var distance := _player.global_position.distance_to(building.global_position)
		if distance <= nearest_distance:
			nearest = building
			nearest_distance = distance
	return nearest

func _try_place_tower(world_position: Vector2) -> void:
	if game_state.is_finished:
		return
	if tower_scene == null:
		game_state.show_message("缺少哨兵塔场景")
		return
	var snapped_position := _snap_to_build_grid(world_position)
	var validation_message := _get_build_validation_message(snapped_position)
	if not validation_message.is_empty():
		game_state.show_message(validation_message)
		return
	var costs: Dictionary = game_state.get_tower_costs()
	if not game_state.spend_resources(costs):
		game_state.show_message("资源不足，需要 %s" % game_state.format_cost(costs))
		return
	var tower := tower_scene.instantiate()
	tower.global_position = snapped_position
	tower.rotation_degrees = _build_rotation_degrees
	_assign_build_metadata(tower, costs)
	_towers_root.add_child(tower)
	_apply_research_to_building(tower)
	game_state.show_message("哨兵塔已建造")
	_notify_building_built("sentry_tower")

func _try_place_wall(world_position: Vector2) -> void:
	if game_state.is_finished:
		return
	if wall_scene == null:
		game_state.show_message("缺少城墙场景")
		return
	var snapped_position := _snap_to_build_grid(world_position)
	var validation_message := _get_build_validation_message(snapped_position)
	if not validation_message.is_empty():
		game_state.show_message(validation_message)
		return
	var costs: Dictionary = game_state.get_wall_costs()
	if not game_state.spend_resources(costs):
		game_state.show_message("资源不足，需要 %s" % game_state.format_cost(costs))
		return
	var wall := wall_scene.instantiate()
	wall.global_position = snapped_position
	wall.rotation_degrees = _build_rotation_degrees
	_assign_build_metadata(wall, costs)
	_walls_root.add_child(wall)
	_apply_research_to_building(wall)
	game_state.show_message("城墙已建造")
	_notify_building_built("wall_segment")

func _try_place_generator(world_position: Vector2) -> void:
	if game_state.is_finished:
		return
	if generator_scene == null:
		game_state.show_message("缺少发电机场景")
		return
	var snapped_position := _snap_to_build_grid(world_position)
	var validation_message := _get_build_validation_message(snapped_position)
	if not validation_message.is_empty():
		game_state.show_message(validation_message)
		return
	var costs: Dictionary = game_state.get_generator_costs()
	if not game_state.spend_resources(costs):
		game_state.show_message("资源不足，需要 %s" % game_state.format_cost(costs))
		return
	var generator := generator_scene.instantiate()
	generator.global_position = snapped_position
	generator.rotation_degrees = _build_rotation_degrees
	_assign_build_metadata(generator, costs)
	_production_root.add_child(generator)
	_apply_research_to_building(generator)
	game_state.show_message("发电机已建造，电力 +%d" % generator.power_output)
	_notify_building_built("power_generator")

func _try_place_miner(world_position: Vector2) -> void:
	if game_state.is_finished:
		return
	if miner_scene == null:
		game_state.show_message("缺少采矿机场景")
		return
	var snapped_position := _snap_to_build_grid(world_position)
	var validation_message := _get_build_validation_message(snapped_position, "miner")
	if not validation_message.is_empty():
		game_state.show_message(validation_message)
		return
	var deposit := _find_nearest_deposit(snapped_position, resource_block_radius)
	if deposit == null:
		game_state.show_message("采矿机必须贴近资源点")
		return
	var costs: Dictionary = game_state.get_miner_costs()
	if not game_state.spend_resources(costs):
		game_state.show_message("资源不足，需要 %s" % game_state.format_cost(costs))
		return
	var miner := miner_scene.instantiate()
	miner.global_position = snapped_position
	miner.rotation_degrees = _build_rotation_degrees
	_assign_build_metadata(miner, costs)
	_production_root.add_child(miner)
	miner.setup_deposit(deposit)
	_apply_research_to_building(miner)
	game_state.show_message("采矿机已部署：%s" % _get_resource_label(deposit.resource_id))
	_notify_building_built("mining_drill")

func _try_place_research_station(world_position: Vector2) -> void:
	if game_state.is_finished:
		return
	if research_station_scene == null:
		game_state.show_message("缺少研究站场景")
		return
	var snapped_position := _snap_to_build_grid(world_position)
	var validation_message := _get_build_validation_message(snapped_position)
	if not validation_message.is_empty():
		game_state.show_message(validation_message)
		return
	var costs: Dictionary = game_state.get_research_station_costs()
	if not game_state.spend_resources(costs):
		game_state.show_message("资源不足，需要 %s" % game_state.format_cost(costs))
		return
	var station := research_station_scene.instantiate()
	station.global_position = snapped_position
	station.rotation_degrees = _build_rotation_degrees
	_assign_build_metadata(station, costs)
	_production_root.add_child(station)
	game_state.show_message("研究站已建造，按 K 打开科技面板")
	_notify_building_built("research_station")

func _try_place_rift_portal(world_position: Vector2) -> void:
	if game_state.is_finished:
		return
	if rift_portal_scene == null:
		game_state.show_message("缺少裂隙传送门场景")
		return
	var existing_rifts: Array = get_tree().get_nodes_in_group("rift_portal")
	if not existing_rifts.is_empty():
		game_state.show_message("裂隙传送门只能建造一座")
		return
	var snapped_position := _snap_to_build_grid(world_position)
	var validation_message := _get_build_validation_message(snapped_position)
	if not validation_message.is_empty():
		game_state.show_message(validation_message)
		return
	var costs: Dictionary = game_state.get_rift_portal_costs()
	if not game_state.spend_resources(costs):
		game_state.show_message("资源不足，需要 %s" % game_state.format_cost(costs))
		return
	var rift := rift_portal_scene.instantiate()
	rift.global_position = snapped_position
	_assign_build_metadata(rift, costs)
	_production_root.add_child(rift)
	game_state.show_message("裂隙传送门已建造，充能中将开启最终防御")
	_set_build_mode("")

func _assign_build_metadata(building: Node, costs: Dictionary) -> void:
	building.set_meta("build_costs", costs.duplicate())
	building.set_meta("build_rotation_degrees", _build_rotation_degrees)

func _notify_building_built(building_type: String) -> void:
	if _quest_manager != null and _quest_manager.has_method("notify_building_built"):
		_quest_manager.notify_building_built(building_type)

func _apply_research_to_building(building: Node) -> void:
	if _research_manager != null and _research_manager.has_method("apply_building_research"):
		_research_manager.apply_building_research(building)

func _try_demolish_nearest_building() -> void:
	if game_state.is_finished:
		return
	var target: Node = _find_nearest_demolishable_building()
	if target == null:
		game_state.show_message("附近没有可拆除建筑")
		return
	var costs: Dictionary = {}
	if target.has_meta("build_costs"):
		costs = target.get_meta("build_costs")
	var refund: Dictionary = _refund_costs(costs)
	if target.has_method("_unregister_power"):
		target.call("_unregister_power")
	target.queue_free()
	if refund.is_empty():
		game_state.show_message("建筑已拆除")
	else:
		game_state.show_message("建筑已拆除，返还 %s" % game_state.format_cost(refund))

func _find_nearest_demolishable_building() -> Node:
	var nearest: Node = null
	var nearest_distance: float = collect_radius
	for building in get_tree().get_nodes_in_group("build_blockers"):
		if not is_instance_valid(building) or not (building is Node2D):
			continue
		var distance: float = _player.global_position.distance_to(building.global_position)
		if distance <= nearest_distance:
			nearest = building
			nearest_distance = distance
	return nearest

func _refund_costs(costs: Dictionary) -> Dictionary:
	var accepted_refund: Dictionary = {}
	for resource_id in costs.keys():
		var original_cost: int = int(costs[resource_id])
		if original_cost <= 0:
			continue
		var refund_amount: int = maxi(int(floor(float(original_cost) * 0.5)), 1)
		var accepted_amount: int = game_state.add_resource(str(resource_id), refund_amount)
		if accepted_amount > 0:
			accepted_refund[str(resource_id)] = accepted_amount
	return accepted_refund

func _snap_to_build_grid(world_position: Vector2) -> Vector2:
	if build_grid_size <= 0.0:
		return world_position
	return Vector2(
		round(world_position.x / build_grid_size) * build_grid_size,
		round(world_position.y / build_grid_size) * build_grid_size
	)

func _get_build_validation_message(world_position: Vector2, build_mode: String = "") -> String:
	if world_position.distance_to(_base_core.global_position) > build_radius:
		return "离基地太远，当前只能在基地范围内建造"
	if world_position.distance_to(_base_core.global_position) < base_block_radius:
		return "离基地核心太近，给总部留出安全空间"
	for blocker in get_tree().get_nodes_in_group("build_blockers"):
		if blocker is Node2D and blocker.global_position.distance_to(world_position) < tower_block_radius:
			return "这里已经有建筑"
	if build_mode == "miner":
		if _find_nearest_deposit(world_position, resource_block_radius) == null:
			return "采矿机必须贴近资源点"
		return ""
	for resource in get_tree().get_nodes_in_group("resource_deposits"):
		if resource is Node2D and resource.global_position.distance_to(world_position) < resource_block_radius:
			return "不要把建筑压到资源点上"
	return ""

func _find_nearest_deposit(world_position: Vector2, radius: float) -> Node:
	var nearest: Node = null
	var nearest_distance := radius
	for deposit in get_tree().get_nodes_in_group("resource_deposits"):
		if not is_instance_valid(deposit) or not (deposit is Node2D):
			continue
		if not deposit.can_collect():
			continue
		var distance := world_position.distance_to(deposit.global_position)
		if distance <= nearest_distance:
			nearest = deposit
			nearest_distance = distance
	return nearest

func _try_player_attack(world_position: Vector2) -> void:
	if game_state.is_finished:
		return
	if _player_attack_cooldown > 0.0:
		return
	var target := _find_enemy_near_cursor(world_position)
	if target == null:
		game_state.show_message("没有锁定敌人")
		return
	var distance: float = _player.global_position.distance_to(target.global_position)
	var weapon_range: float = player_attack_range
	var weapon_damage: int = player_attack_damage
	var weapon_label: String = "机甲"
	if _player.has_method("get_active_weapon_range"):
		weapon_range = _player.get_active_weapon_range()
		weapon_damage = _player.get_active_weapon_damage()
		weapon_label = _player.get_active_weapon_label()
	if distance > weapon_range:
		game_state.show_message("%s 射程不足" % weapon_label)
		return
	if _player.has_method("try_spend_weapon_energy") and not _player.try_spend_weapon_energy():
		game_state.show_message("机甲能量不足")
		return
	target.take_damage(weapon_damage)
	_player_attack_cooldown = player_attack_interval
	game_state.show_message("%s 命中，伤害 %d" % [weapon_label, weapon_damage])

func _find_enemy_near_cursor(world_position: Vector2) -> Node:
	var best_enemy: Node = null
	var best_cursor_distance := cursor_target_radius
	var attack_range: float = player_attack_range
	if _player.has_method("get_active_weapon_range"):
		attack_range = _player.get_active_weapon_range()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var player_distance := _player.global_position.distance_to(enemy.global_position)
		if player_distance > attack_range:
			continue
		var cursor_distance := world_position.distance_to(enemy.global_position)
		if cursor_distance <= best_cursor_distance:
			best_enemy = enemy
			best_cursor_distance = cursor_distance
	return best_enemy

func _on_base_destroyed() -> void:
	game_state.finish_game(false, "基地核心被摧毁，防守失败")

func _on_mech_destroyed(resource_penalty: int) -> void:
	if resource_penalty > 0:
		game_state.spend_resources({"energy": resource_penalty})
	game_state.show_message("机甲被击毁并回收，损失能量 %d" % resource_penalty)

func _on_game_finished(_victory: bool, _reason: String) -> void:
	_build_mode = ""
	queue_redraw()

func _draw() -> void:
	if not _is_building() or _base_core == null:
		return
	var base_local := to_local(_base_core.global_position)
	var snapped_position := _snap_to_build_grid(get_global_mouse_position())
	var mouse_local := to_local(snapped_position)
	var validation_message := _get_build_validation_message(snapped_position, _build_mode)
	var preview_color := Color(0.2, 0.95, 0.72, 0.22)
	var outline_color := Color(0.2, 0.95, 0.72, 0.8)
	if not validation_message.is_empty():
		preview_color = Color(1.0, 0.15, 0.1, 0.22)
		outline_color = Color(1.0, 0.15, 0.1, 0.85)
	draw_arc(base_local, build_radius, 0.0, TAU, 128, Color(0.2, 0.8, 1.0, 0.55), 3.0)
	_draw_build_grid(base_local)
	var cell_size := Vector2(build_grid_size, build_grid_size)
	draw_set_transform(mouse_local, deg_to_rad(_build_rotation_degrees), Vector2.ONE)
	draw_rect(Rect2(-cell_size * 0.5, cell_size), preview_color, true)
	draw_rect(Rect2(-cell_size * 0.5, cell_size), outline_color, false, 3.0)
	draw_line(Vector2.ZERO, Vector2(0, -cell_size.y * 0.45), outline_color, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(mouse_local, tower_block_radius * 0.5, Color(outline_color.r, outline_color.g, outline_color.b, 0.16))

func _draw_build_grid(base_local: Vector2) -> void:
	if build_grid_size <= 0.0:
		return
	var grid_color := Color(0.25, 0.8, 1.0, 0.12)
	var min_index := int(floor(-build_radius / build_grid_size)) - 1
	var max_index := int(ceil(build_radius / build_grid_size)) + 1
	for index in range(min_index, max_index + 1):
		var offset := index * build_grid_size
		draw_line(
			base_local + Vector2(offset, -build_radius),
			base_local + Vector2(offset, build_radius),
			grid_color,
			1.0
		)
		draw_line(
			base_local + Vector2(-build_radius, offset),
			base_local + Vector2(build_radius, offset),
			grid_color,
			1.0
		)

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
