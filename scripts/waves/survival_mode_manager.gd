extends Node
class_name SurvivalModeManager

signal survival_started
signal survival_ended(wave_reached: int, time_survived: float, kills: int)
signal wave_cleared(wave: int)
signal stats_updated(wave: int, time: float, kills: int)

@export var game_state_path: NodePath
@export var wave_manager_path: NodePath
@export var auto_start: bool = false
@export var difficulty_scale: float = 1.0
@export var prepare_time_base: float = 12.0
@export var prepare_time_min: float = 5.0
@export var prepare_time_decrease_per_wave: float = 0.3
@export var boss_wave_interval: int = 10
@export var elite_wave_interval: int = 5
@export var swarm_wave_interval: int = 7

var game_state: Node
var _wave_manager: Node
var _is_active: bool = false
var _current_wave: int = 0
var _survival_time: float = 0.0
var _total_kills: int = 0
var _highest_wave_reached: int = 0
var _special_wave_type: String = ""
var _enemy_kill_counter: int = 0

func _ready() -> void:
	game_state = get_node_or_null(game_state_path)
	_wave_manager = get_node_or_null(wave_manager_path)
	add_to_group("survival_mode_manager")
	if auto_start:
		start_survival_mode()

func _process(delta: float) -> void:
	if not _is_active:
		return
	if game_state != null and game_state.is_finished:
		_end_survival(false)
		return
	_survival_time += delta
	stats_updated.emit(_current_wave, _survival_time, _total_kills)

func start_survival_mode() -> void:
	if _is_active:
		return
	_is_active = true
	_current_wave = 0
	_survival_time = 0.0
	_total_kills = 0
	_highest_wave_reached = 0
	_enemy_kill_counter = 0
	_connect_wave_signals()
	survival_started.emit()
	if game_state != null:
		game_state.show_message("生存模式开始！抵御无尽敌潮！")
	_start_next_wave_prep()

func _connect_wave_signals() -> void:
	if _wave_manager == null:
		return
	if _wave_manager.has_signal("wave_cleared"):
		_wave_manager.wave_cleared.connect(_on_wave_cleared)
	elif game_state != null:
		game_state.resource_changed.connect(_on_resource_changed_check_wave)
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.connect("node_removed", Callable(self, "_on_node_removed"))

func _on_node_removed(node: Node) -> void:
	if not _is_active:
		return
	if node.is_in_group("enemies"):
		_enemy_kill_counter += 1
		_total_kills += 1

func _on_resource_changed_check_wave(_rid: String, _amt: int) -> void:
	pass

func _start_next_wave_prep() -> void:
	if _wave_manager == null:
		return
	_current_wave += 1
	_highest_wave_reached = maxi(_highest_wave_reached, _current_wave)
	_special_wave_type = _get_special_wave_type(_current_wave)
	var composition: Dictionary = _build_survival_wave_composition(_current_wave, _special_wave_type)
	var prepare_time: float = _calc_prepare_time(_current_wave)
	if _wave_manager.has_method("start_survival_wave"):
		_wave_manager.start_survival_wave(_current_wave, composition, prepare_time)
	else:
		_fallback_start_wave(composition, prepare_time)
	if game_state != null:
		var wave_label: String = _get_special_wave_label(_special_wave_type)
		game_state.show_message("第 %d 波 %s即将来袭！准备时间：%d 秒" % [_current_wave, wave_label, int(prepare_time)])

func _calc_prepare_time(wave: int) -> float:
	var time: float = prepare_time_base - float(wave) * prepare_time_decrease_per_wave
	return max(time, prepare_time_min)

func _get_special_wave_type(wave: int) -> String:
	if wave > 0 and wave % boss_wave_interval == 0:
		return "boss"
	elif wave > 0 and wave % elite_wave_interval == 0:
		return "elite"
	elif wave > 0 and wave % swarm_wave_interval == 0:
		return "swarm"
	return "normal"

func _get_special_wave_label(wave_type: String) -> String:
	match wave_type:
		"boss":
			return "【BOSS波】"
		"elite":
			return "【精英波】"
		"swarm":
			return "【群怪波】"
		_:
			return ""

func _build_survival_wave_composition(wave: int, wave_type: String) -> Dictionary:
	var difficulty_mult: float = 1.0 + float(wave - 1) * 0.12 * difficulty_scale
	var base_count: int = int(float(5 + wave * 2) * difficulty_scale)
	var composition: Dictionary = {}
	match wave_type:
		"boss":
			composition = _build_boss_wave(wave, difficulty_mult)
		"elite":
			composition = _build_elite_wave(wave, difficulty_mult, base_count)
		"swarm":
			composition = _build_swarm_wave(wave, difficulty_mult, base_count)
		_:
			composition = _build_normal_wave(wave, difficulty_mult, base_count)
	return composition

func _build_normal_wave(wave: int, diff_mult: float, base_count: int) -> Dictionary:
	var composition: Dictionary = {"scout": base_count}
	if wave >= 2:
		var armored_count: int = int(float(1 + int(floor(float(wave) / 2.0))) * diff_mult)
		composition["armored"] = maxi(armored_count, 1)
		composition["scout"] = maxi(base_count - armored_count, 2)
	if wave >= 4:
		composition["breaker"] = int(float(1 + int(floor(float(wave - 3) / 2.0))) * diff_mult)
	if wave >= 6:
		composition["spitter"] = int(float(1 + int(floor(float(wave - 5) / 2.0))) * diff_mult)
	if wave >= 8 and wave % 4 == 0:
		composition["elite"] = maxi(int(diff_mult), 1)
	return composition

func _build_elite_wave(wave: int, diff_mult: float, base_count: int) -> Dictionary:
	var composition: Dictionary = {}
	composition["elite"] = maxi(int(float(2 + wave / 5) * diff_mult), 2)
	composition["scout"] = int(float(base_count) * 0.6)
	composition["armored"] = int(float(base_count) * 0.3)
	return composition

func _build_swarm_wave(wave: int, diff_mult: float, base_count: int) -> Dictionary:
	var composition: Dictionary = {}
	composition["scout"] = int(float(base_count) * 2.5 * diff_mult)
	composition["breaker"] = maxi(int(float(wave / 3) * diff_mult), 1)
	return composition

func _build_boss_wave(wave: int, diff_mult: float) -> Dictionary:
	var composition: Dictionary = {}
	composition["elite"] = maxi(int(float(3 + wave / 3) * diff_mult), 3)
	composition["armored"] = int(float(5 + wave) * diff_mult)
	composition["spitter"] = int(float(3 + wave / 2) * diff_mult)
	composition["scout"] = int(float(10 + wave) * diff_mult)
	composition["breaker"] = int(float(2 + wave / 4) * diff_mult)
	return composition

func _fallback_start_wave(composition: Dictionary, prep_time: float) -> void:
	if game_state == null:
		return
	pass

func _on_wave_cleared(wave: int) -> void:
	if not _is_active:
		return
	wave_cleared.emit(wave)
	if game_state != null:
		var reward: int = 30 + wave * 15
		game_state.add_energy(reward)
		game_state.show_message("第 %d 波已清除！能量 +%d | 击杀：%d" % [wave, reward, _total_kills])
	await get_tree().create_timer(2.0).timeout
	_start_next_wave_prep()

func _end_survival(victory: bool) -> void:
	if not _is_active:
		return
	_is_active = false
	survival_ended.emit(_highest_wave_reached, _survival_time, _total_kills)
	if game_state != null:
		if victory:
			game_state.finish_game(true, "生存模式结束！最高波次：%d，生存时间：%d秒，击杀：%d" % [_highest_wave_reached, int(_survival_time), _total_kills])
		else:
			game_state.finish_game(false, "基地被摧毁！最高波次：%d，生存时间：%d秒，击杀：%d" % [_highest_wave_reached, int(_survival_time), _total_kills])

func get_current_wave() -> int:
	return _current_wave

func get_survival_time() -> float:
	return _survival_time

func get_total_kills() -> int:
	return _total_kills

func get_highest_wave() -> int:
	return _highest_wave_reached

func is_survival_active() -> bool:
	return _is_active

func get_special_wave_type() -> String:
	return _special_wave_type

func format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%02d:%02d" % [mins, secs]
