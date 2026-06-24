extends Node
class_name WaveManager

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

var game_state: Node
var _base_core: Node2D
var _spawn_root: Node
var _enemies_root: Node
var _spawn_points: Array[Node2D] = []
var _wave: int = 0
var _state: String = "准备"
var _countdown: float = 0.0
var _spawn_cooldown: float = 0.0
var _remaining_to_spawn: int = 0
var _enemy_types: Dictionary = {}
var _spawn_queue: Array[String] = []
var _next_wave_preview: Dictionary = {}

func _ready() -> void:
	game_state = get_node(game_state_path)
	_base_core = get_node(base_path)
	_spawn_root = get_node(spawn_root_path)
	_enemies_root = get_node(enemies_root_path)
	for child in _spawn_root.get_children():
		if child is Node2D:
			_spawn_points.append(child)
	_load_enemy_types()
	_start_preparation()

func _process(delta: float) -> void:
	if game_state != null and game_state.is_finished:
		return
	if _state == "准备":
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
	_countdown = prepare_duration
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
		game_state.show_message("第 %d 波敌人来袭：%s" % [_wave, _format_composition_names(composition)])
	_emit_status()

func _spawn_enemy() -> void:
	if enemy_scene == null or _spawn_points.is_empty() or _spawn_queue.is_empty():
		return
	var spawn_point := _spawn_points[(_remaining_to_spawn + _wave) % _spawn_points.size()]
	var enemy := enemy_scene.instantiate()
	enemy.global_position = spawn_point.global_position
	_enemies_root.add_child(enemy)
	var type_id: String = _spawn_queue.pop_front()
	if enemy.has_method("setup_type") and _enemy_types.has(type_id):
		enemy.setup_type(_enemy_types[type_id], _wave)
	enemy.setup(_base_core)

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
	var total_count: int = base_enemy_count + (wave - 1) * 2 + _dynamic_pressure_bonus()
	var composition: Dictionary = {"scout": total_count}
	if wave >= 2:
		var armored_count: int = 1 + int(floor(float(wave) / 2.0))
		composition["armored"] = armored_count
		composition["scout"] = maxi(int(composition["scout"]) - armored_count, 2)
	if wave >= 3:
		composition["breaker"] = 1 + int(floor(float(wave - 3) / 2.0))
	if wave >= 4:
		composition["spitter"] = 1 + int(floor(float(wave - 4) / 2.0))
	if wave % 3 == 0:
		composition["elite"] = 1
	return composition

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
	return "预警：第 %d 波将从%s来袭：%s" % [wave, direction_text, _format_composition_names(composition)]

func _format_composition_names(composition: Dictionary) -> String:
	var parts: Array[String] = []
	for type_id in composition.keys():
		var profile: Dictionary = _enemy_types.get(str(type_id), {})
		var type_name: String = str(profile.get("name", type_id))
		parts.append("%s x%d" % [type_name, int(composition[type_id])])
	return "、".join(parts)
