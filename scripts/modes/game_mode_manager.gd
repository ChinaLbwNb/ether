extends Node
class_name GameModeManager

signal mode_changed(mode_id: String, mode_name: String)
signal survival_stats_changed(elapsed_seconds: int, highest_wave: int, cleared_waves: int)

@export var game_state_path: NodePath
@export var default_mode: String = "campaign"

var current_mode_id: String = "campaign"
var survival_elapsed_seconds: float = 0.0
var survival_highest_wave: int = 0
var survival_cleared_waves: int = 0

var _game_state: Node

func _ready() -> void:
	add_to_group("game_mode_manager")
	_game_state = get_node(game_state_path)
	current_mode_id = default_mode
	call_deferred("_emit_mode_state")

func _process(delta: float) -> void:
	if _game_state != null and _game_state.is_finished:
		return
	if is_survival_mode():
		survival_elapsed_seconds += delta
		survival_stats_changed.emit(int(floor(survival_elapsed_seconds)), survival_highest_wave, survival_cleared_waves)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_survival_mode"):
		if is_survival_mode():
			set_campaign_mode()
		else:
			start_survival_mode(true)

func set_campaign_mode() -> void:
	current_mode_id = "campaign"
	_emit_mode_state()
	if _game_state != null:
		_game_state.show_message("模式：战役")

func start_survival_mode(reset_stats: bool = true) -> void:
	current_mode_id = "survival"
	if reset_stats:
		survival_elapsed_seconds = 0.0
		survival_highest_wave = 0
		survival_cleared_waves = 0
	_emit_mode_state()
	if _game_state != null:
		_game_state.show_message("模式：生存，无限敌潮已开启")

func is_survival_mode() -> bool:
	return current_mode_id == "survival"

func notify_wave_started(wave: int) -> void:
	if not is_survival_mode():
		return
	survival_highest_wave = maxi(survival_highest_wave, wave)
	survival_stats_changed.emit(int(floor(survival_elapsed_seconds)), survival_highest_wave, survival_cleared_waves)

func notify_wave_cleared(wave: int) -> void:
	if not is_survival_mode():
		return
	survival_cleared_waves = maxi(survival_cleared_waves, wave)
	survival_stats_changed.emit(int(floor(survival_elapsed_seconds)), survival_highest_wave, survival_cleared_waves)

func get_survival_enemy_bonus(wave: int) -> int:
	if not is_survival_mode():
		return 0
	return clampi(int(floor(float(wave) / 2.0)), 1, 10)

func get_survival_spawn_interval(base_interval: float, wave: int) -> float:
	if not is_survival_mode():
		return base_interval
	var multiplier: float = max(0.45, 1.0 - float(wave) * 0.035)
	return max(base_interval * multiplier, 0.22)

func get_mode_name() -> String:
	if is_survival_mode():
		return "生存"
	return "战役"

func get_mode_status_text() -> String:
	if is_survival_mode():
		return "模式：生存  时间 %d 秒  最高波 %d  清理 %d" % [
			int(floor(survival_elapsed_seconds)),
			survival_highest_wave,
			survival_cleared_waves
		]
	return "模式：战役"

func _emit_mode_state() -> void:
	mode_changed.emit(current_mode_id, get_mode_name())
	survival_stats_changed.emit(int(floor(survival_elapsed_seconds)), survival_highest_wave, survival_cleared_waves)
