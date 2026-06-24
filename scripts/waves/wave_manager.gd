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
@export var max_waves_to_win: int = 3
@export var wave_clear_reward: int = 25

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

func _ready() -> void:
	game_state = get_node(game_state_path)
	_base_core = get_node(base_path)
	_spawn_root = get_node(spawn_root_path)
	_enemies_root = get_node(enemies_root_path)
	for child in _spawn_root.get_children():
		if child is Node2D:
			_spawn_points.append(child)
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
	_emit_status()
	if game_state != null:
		game_state.show_message("下一波敌人正在接近，趁现在采集、建塔、建墙或修复")

func _start_wave() -> void:
	_wave += 1
	_state = "出怪"
	_remaining_to_spawn = base_enemy_count + (_wave - 1) * 2
	_spawn_cooldown = 0.0
	if game_state != null:
		game_state.show_message("第 %d 波敌人来袭" % _wave)
	_emit_status()

func _spawn_enemy() -> void:
	if enemy_scene == null or _spawn_points.is_empty():
		return
	var spawn_point := _spawn_points[(_remaining_to_spawn + _wave) % _spawn_points.size()]
	var enemy := enemy_scene.instantiate()
	enemy.global_position = spawn_point.global_position
	_enemies_root.add_child(enemy)
	enemy.setup(_base_core)

func _alive_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func _emit_status() -> void:
	if game_state != null:
		game_state.set_wave_status(_wave, _state, max(_countdown, 0.0), _alive_enemy_count())
