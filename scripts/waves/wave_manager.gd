extends Node
class_name WaveManager

signal final_defense_started
signal final_defense_won
signal final_defense_lost
signal wave_cleared(wave: int)
signal wave_started(wave: int)

@export var enemy_scene: PackedScene
@export var game_state_path: NodePath
@export var base_path: NodePath
@export var spawn_root_path: NodePath
@export var enemies_root_path: NodePath
@export var prepare_duration: float = 8.0
@export var spawn_interval: float = 0.65
@export var base_enemy_count: int = 5
@export var max_waves_to_win: int = 5
@export var wave_clear_reward: int = 25
@export var enemy_type_data_path: String = "res://data/enemies/enemy_types.json"
@export var auto_start: bool = true
@export var final_defense_waves: int = 10
@export var final_defense_difficulty_mult: float = 1.5

var game_state: Node
var _base_core: Node2D
var _spawn_root: Node
var _enemies_root: Node
var _spawn_points: Array[Node2D] = []
var _nav_manager: Node
var _wave: int = 0
var _state: String = "待机"
var _countdown: float = 0.0
var _spawn_cooldown: float = 0.0
var _remaining_to_spawn: int = 0
var _enemy_types: Dictionary = {}
var _spawn_queue: Array[String] = []
var _next_wave_preview: Dictionary = {}
var _is_final_defense: bool = false
var _final_wave_count: int = 0
var _is_survival_mode: bool = false
var _survival_custom_composition: Dictionary = {}
var _survival_prepare_time: float = 8.0
var _prepare_duration_multiplier: float = 1.0
var _enemy_strength_multiplier: float = 1.0
var _current_wave_type: String = "normal"
var _boss_active: bool = false
var _spawn_angle_offset: float = 0.0

func _ready() -> void:
	game_state = get_node(game_state_path)
	_base_core = get_node(base_path)
	_spawn_root = get_node(spawn_root_path)
	_enemies_root = get_node(enemies_root_path)
	for child in _spawn_root.get_children():
		if child is Node2D:
			_spawn_points.append(child)
	_load_enemy_types()
	add_to_group("wave_manager")
	var nav_managers: Array = get_tree().get_nodes_in_group("navigation_manager")
	if not nav_managers.is_empty():
		_nav_manager = nav_managers[0]
	if auto_start:
		_start_preparation()
	else:
		_state = "待机"
		_emit_status()

func _process(delta: float) -> void:
	if game_state != null and game_state.is_finished:
		return
	if _state == "待机":
		return
	elif _state == "准备":
		_countdown -= delta
		_emit_status()
		if _countdown <= 0.0:
			_start_wave()
	elif _state == "出怪":
		_spawn_cooldown -= delta
		if _remaining_to_spawn > 0 and _spawn_cooldown <= 0.0:
			_spawn_enemy()
			_remaining_to_spawn -= 1
			_spawn_cooldown = spawn_interval
		if _remaining_to_spawn == 0:
			_state = "清场"
		_emit_status()
	elif _state == "清场":
		_emit_status()
		if _alive_enemy_count() == 0:
			wave_cleared.emit(_wave)
			if _is_survival_mode:
				_on_survival_wave_cleared()
			elif _is_final_defense:
				if _wave >= _final_wave_count:
					_on_final_defense_won()
				else:
					if game_state != null:
						var reward: int = wave_clear_reward * 2 + _wave * 15
						game_state.add_energy(reward)
						game_state.show_message("最终防御第 %d 波已清除，能量 +%d" % [_wave, reward])
					_start_preparation()
			else:
				if _wave >= max_waves_to_win:
					if game_state != null:
						game_state.finish_game(true, "守住了测试波次，基地防守原型胜利")
				else:
					if game_state != null:
						var reward: int = wave_clear_reward + _wave * 10
						game_state.add_energy(reward)
						game_state.show_message("第 %d 波已清除，回收能量 +%d" % [_wave, reward])
					_start_preparation()

func _start_preparation() -> void:
	_state = "准备"
	_countdown = prepare_duration * _prepare_duration_multiplier
	_next_wave_preview = _build_wave_composition(_wave + 1)
	_emit_status()
	if game_state != null:
		var warning: String = _format_wave_warning(_wave + 1, _next_wave_preview)
		game_state.set_wave_warning(warning)
		game_state.show_message(warning)

func _start_wave() -> void:
	_wave += 1
	_state = "出怪"
	var composition: Dictionary = _next_wave_preview
	if composition.is_empty():
		composition = _build_wave_composition(_wave)
	_spawn_queue = _build_spawn_queue(composition)
	_remaining_to_spawn = _spawn_queue.size()
	_spawn_cooldown = 0.0
	if game_state != null:
		game_state.set_wave_warning(_format_wave_warning(_wave, composition))
		var wave_type_label: String = get_wave_type_label(_current_wave_type)
		var prefix: String = "第 %d 波" % _wave
		if not wave_type_label.is_empty():
			prefix = wave_type_label + " 第 %d 波" % _wave
		game_state.show_message("%s敌人来袭：%s" % [prefix, _format_composition_names(composition)])
	wave_started.emit(_wave)
	_emit_status()

func _spawn_enemy() -> void:
	if enemy_scene == null or _spawn_queue.is_empty():
		return
	var spawn_position: Vector2 = _get_spawn_position()
	var enemy := enemy_scene.instantiate()
	enemy.global_position = spawn_position
	_enemies_root.add_child(enemy)
	var type_id: String = _spawn_queue.pop_front()
	if enemy.has_method("setup_type") and _enemy_types.has(type_id):
		enemy.setup_type(_enemy_types[type_id], _wave, _enemy_strength_multiplier, type_id)
	enemy.setup(_base_core)

func _get_nav_manager() -> Node:
	if _nav_manager == null:
		var nav_managers: Array = get_tree().get_nodes_in_group("navigation_manager")
		if not nav_managers.is_empty():
			_nav_manager = nav_managers[0]
	return _nav_manager

func _get_spawn_position() -> Vector2:
	var nav: Node = _get_nav_manager()
	if nav != null and nav.has_method("find_nearest_spawn_position"):
		_spawn_angle_offset += randf_range(0.3, 0.8)
		if _spawn_angle_offset >= TAU:
			_spawn_angle_offset -= TAU
		var min_spawn_dist: float = 500.0 + float(_wave) * 10.0
		var base_angle: float = _spawn_angle_offset
		if not _spawn_points.is_empty():
			var chosen_point_idx: int = (_remaining_to_spawn + _wave * 3) % _spawn_points.size()
			var point_to_base: Vector2 = _base_core.global_position.direction_to(_spawn_points[chosen_point_idx].global_position)
			base_angle = point_to_base.angle() + randf_range(-0.8, 0.8)
		var spawn_pos: Vector2 = nav.find_nearest_spawn_position(_base_core.global_position, min_spawn_dist)
		var angle_offset: float = base_angle + randf_range(-0.5, 0.5)
		var dist_offset: float = randf_range(-64, 64)
		var candidate: Vector2 = _base_core.global_position + Vector2(cos(angle_offset), sin(angle_offset)) * (min_spawn_dist + dist_offset)
		if nav.is_position_walkable(candidate):
			return candidate
		return spawn_pos
	if not _spawn_points.is_empty():
		var spawn_point := _spawn_points[(_remaining_to_spawn + _wave) % _spawn_points.size()]
		return spawn_point.global_position
	var fallback_angle: float = randf() * TAU
	return _base_core.global_position + Vector2(cos(fallback_angle), sin(fallback_angle)) * 600.0

func _alive_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func _emit_status() -> void:
	if game_state != null:
		game_state.set_wave_status(_wave, _state, max(_countdown, 0.0), _alive_enemy_count())

func _load_enemy_types() -> void:
	var file: FileAccess = FileAccess.open(enemy_type_data_path, FileAccess.READ)
	if file == null:
		push_error("无法读取敌人类型数据：" + enemy_type_data_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		push_error("敌人类型数据格式错误：" + enemy_type_data_path)
		return
	for item in parsed:
		if item is Dictionary and item.has("id"):
			_enemy_types[str(item["id"])] = item

func _build_wave_composition(wave: int) -> Dictionary:
	var mult: float = 1.0
	if _is_final_defense:
		mult = final_defense_difficulty_mult
	_current_wave_type = _determine_wave_type(wave)
	var total_count: int = int(float(base_enemy_count + int(floor(float(wave - 1) * 1.5)) + _dynamic_pressure_bonus()) * mult)
	var composition: Dictionary = {"scout": total_count}
	if wave >= 2:
		var armored_count: int = int(float(1 + int(floor(float(wave - 1) / 2.5))) * mult)
		composition["armored"] = armored_count
		composition["scout"] = maxi(int(composition["scout"]) - armored_count, 2)
	if wave >= 3:
		composition["breaker"] = int(float(1 + int(floor(float(wave - 2) / 3.0))) * mult)
	if wave >= 4:
		composition["spitter"] = int(float(1 + int(floor(float(wave - 3) / 3.0))) * mult)
	if wave >= 5:
		composition["swarm"] = int(float(2 + int(floor(float(wave - 4) / 2.0))) * mult)
	if wave >= 7:
		composition["shielded"] = int(float(1 + int(floor(float(wave - 6) / 4.0))) * mult)
	if wave >= 10:
		composition["brute"] = int(float(1 + int(floor(float(wave - 9) / 5.0))) * mult)
	if wave >= 4 and wave % 3 == 0:
		composition["elite"] = max(int(float(1 + int(floor(float(wave) / 6.0))) * mult), 1)
	match _current_wave_type:
		"swarm":
			var extra_swarm: int = int(float(8 + wave) * mult)
			composition["swarm"] = int(composition.get("swarm", 0)) + extra_swarm
			composition["scout"] = maxi(int(composition["scout"]) - int(float(extra_swarm) * 0.4), 1)
		"boss":
			var extra_brute: int = int(float(2 + int(floor(float(wave) / 10.0))) * mult)
			var extra_shielded: int = int(float(2 + int(floor(float(wave) / 8.0))) * mult)
			composition["brute"] = int(composition.get("brute", 0)) + extra_brute
			composition["shielded"] = int(composition.get("shielded", 0)) + extra_shielded
		"elite":
			composition["elite"] = int(float(composition.get("elite", 1)) * 2.5) + int(2 * mult)
	return composition

func _determine_wave_type(wave: int) -> String:
	if wave <= 2:
		return "normal"
	if wave % 10 == 0:
		return "boss"
	if wave % 5 == 0:
		return "swarm"
	if wave % 7 == 0:
		return "elite"
	return "normal"

func get_wave_type_label(wave_type: String) -> String:
	match wave_type:
		"boss":
			return "⚠️ BOSS波"
		"swarm":
			return "🐛 虫潮波"
		"elite":
			return "⚔️ 精英波"
		_:
			return ""

func get_current_wave_type() -> String:
	return _current_wave_type

func _dynamic_pressure_bonus() -> int:
	if game_state == null:
		return 0
	var bonus: int = 0
	bonus += int(floor(float(game_state.power_supply) / 40.0))
	bonus += int(floor(float(get_tree().get_nodes_in_group("defense_towers").size()) / 2.0))
	bonus += int(floor(float(get_tree().get_nodes_in_group("research_stations").size()) / 1.0))
	return clampi(bonus, 0, 5)

func _build_spawn_queue(composition: Dictionary) -> Array[String]:
	var queue: Array[String] = []
	for type_id in composition.keys():
		for _index in range(int(composition[type_id])):
			queue.append(str(type_id))
	queue.shuffle()
	return queue

func _format_wave_warning(wave: int, composition: Dictionary) -> String:
	var direction_text: String = "东侧与南侧"
	if _spawn_points.size() == 1:
		direction_text = "单方向"
	var wave_type_label: String = get_wave_type_label(_current_wave_type)
	var prefix: String = "预警"
	if not wave_type_label.is_empty():
		prefix = wave_type_label + " 预警"
	return "%s：第 %d 波将从%s来袭：%s" % [prefix, wave, direction_text, _format_composition_names(composition)]

func _format_composition_names(composition: Dictionary) -> String:
	var parts: Array[String] = []
	for type_id in composition.keys():
		var profile: Dictionary = _enemy_types.get(str(type_id), {})
		var type_name: String = str(profile.get("name", type_id))
		parts.append("%s x%d" % [type_name, int(composition[type_id])])
	return "、".join(parts)

func start_final_defense() -> void:
	if _state != "待机":
		return
	_is_final_defense = true
	_wave = 0
	_final_wave_count = final_defense_waves
	final_defense_started.emit()
	if game_state != null:
		game_state.show_message("警告：裂隙充能即将完成，最终防御战即将开始！")
	_start_preparation()

func _on_final_defense_won() -> void:
	final_defense_won.emit()
	var quest_managers: Array = get_tree().get_nodes_in_group("quest_manager")
	if not quest_managers.is_empty() and quest_managers[0].has_method("notify_defense_won"):
		quest_managers[0].notify_defense_won()
	if game_state != null:
		game_state.show_message("最终防御胜利！裂隙已稳定，星球正在净化...")

func is_final_defense_active() -> bool:
	return _is_final_defense

func get_current_wave() -> int:
	return _wave

func get_final_wave_count() -> int:
	return _final_wave_count

func start_waves() -> void:
	if _state != "待机":
		return
	_start_preparation()

func set_prepare_duration_multiplier(mult: float) -> void:
	_prepare_duration_multiplier = max(mult, 0.1)

func set_enemy_strength_multiplier(mult: float) -> void:
	_enemy_strength_multiplier = max(mult, 0.1)

func start_survival_wave(wave_number: int, composition: Dictionary, prepare_time: float) -> void:
	if _state != "待机" and _state != "清场":
		return
	_is_survival_mode = true
	_wave = wave_number - 1
	_survival_custom_composition = composition.duplicate()
	_survival_prepare_time = prepare_time
	_state = "准备"
	_countdown = prepare_time
	_next_wave_preview = composition.duplicate()
	_emit_status()
	if game_state != null:
		var warning: String = _format_wave_warning(wave_number, composition)
		game_state.set_wave_warning(warning)

func is_survival_mode() -> bool:
	return _is_survival_mode

func stop_survival_mode() -> void:
	_is_survival_mode = false
	_state = "待机"
	_emit_status()

func _on_survival_wave_cleared() -> void:
	if game_state != null:
		var reward: int = 30 + _wave * 15
		game_state.add_energy(reward)
	_state = "待机"
	_emit_status()
