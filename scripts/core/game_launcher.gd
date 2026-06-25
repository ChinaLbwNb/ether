extends Node
class_name GameLauncher

@export var game_state_path: NodePath
@export var game_mode_manager_path: NodePath
@export var wave_manager_path: NodePath
@export var survival_mode_manager_path: NodePath
@export var research_manager_path: NodePath
@export var main_menu_path: NodePath

var _game_state: Node
var _mode_manager: Node
var _wave_manager: Node
var _survival_manager: Node
var _research_manager: Node
var _main_menu: Control
var _game_started: bool = false

func _ready() -> void:
	add_to_group("game_launcher")
	_game_state = get_node_or_null(game_state_path)
	_mode_manager = get_node_or_null(game_mode_manager_path)
	_wave_manager = get_node_or_null(wave_manager_path)
	_survival_manager = get_node_or_null(survival_mode_manager_path)
	_research_manager = get_node_or_null(research_manager_path)
	_main_menu = get_node_or_null(main_menu_path)
	if _main_menu != null:
		_main_menu.start_game.connect(_on_start_game)
	_show_menu()

func _show_menu() -> void:
	if _main_menu != null:
		_main_menu.visible = true
	get_tree().paused = true

func _hide_menu() -> void:
	if _main_menu != null:
		_main_menu.visible = false
	get_tree().paused = false

func _on_start_game(mode_id: String, config: Dictionary) -> void:
	if _mode_manager == null:
		_start_game_default()
		return
	_mode_manager.set_mode(mode_id)
	if config.has("difficulty"):
		_mode_manager.set_difficulty(str(config["difficulty"]))
	_apply_mode_settings()
	_hide_menu()
	_game_started = true
	_start_waves_for_mode(mode_id)

func _apply_mode_settings() -> void:
	if _mode_manager == null or _game_state == null:
		return
	var starting: Dictionary = _mode_manager.get_starting_resources()
	var energy: int = int(starting.get("energy", 0))
	var iron: int = int(starting.get("iron", 0))
	var carbon: int = int(starting.get("carbon", 0))
	var storage: int = int(starting.get("storage", 240))
	if _game_state.has_method("set_starting_resources"):
		_game_state.set_starting_resources(energy, iron, carbon, storage)
	if _mode_manager.is_sandbox_all_tech() and _research_manager != null:
		if _research_manager.has_method("unlock_all_tech"):
			_research_manager.unlock_all_tech()
	if _survival_manager != null and _mode_manager != null:
		if _survival_manager.has_method("set_difficulty_scale"):
			_survival_manager.set_difficulty_scale(_mode_manager.get_survival_difficulty_scale())

func _start_waves_for_mode(mode_id: String) -> void:
	match mode_id:
		"survival":
			if _survival_manager != null and _survival_manager.has_method("start_survival_mode"):
				_survival_manager.start_survival_mode()
		"campaign":
			if _wave_manager != null and _wave_manager.has_method("start_waves"):
				_wave_manager.start_waves()
		"sandbox":
			if _mode_manager.are_enemies_enabled():
				if _wave_manager != null and _wave_manager.has_method("start_waves"):
					_wave_manager.start_waves()

func _start_game_default() -> void:
	_hide_menu()
	_game_started = true
	if _wave_manager != null and _wave_manager.has_method("start_waves"):
		_wave_manager.start_waves()

func restart_game() -> void:
	get_tree().reload_current_scene()
