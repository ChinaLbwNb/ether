extends Node2D
class_name Teleporter

signal player_teleported(target_position: Vector2, target_label: String)

@export var target_position: Vector2 = Vector2.ZERO
@export var target_label: String = "目标区域"
@export var interact_radius: float = 100.0
@export var teleport_cooldown: float = 2.0
@export var portal_color: Color = Color(0.3, 0.85, 1.0, 0.9)
@export var display_name: String = "传送点"

var _cooldown_timer: float = 0.0
var _player_in_range: bool = false
var _pulse_phase: float = 0.0

func _ready() -> void:
	add_to_group("teleporters")
	add_to_group("interactables")
	queue_redraw()

func _process(delta: float) -> void:
	_cooldown_timer = max(_cooldown_timer - delta, 0.0)
	_pulse_phase += delta * 2.0
	var was_in_range: bool = _player_in_range
	_player_in_range = _check_player_in_range()
	if _player_in_range and not was_in_range:
		_show_hint()
	queue_redraw()

func _check_player_in_range() -> bool:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	var player: Node2D = players[0]
	if not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) <= interact_radius

func _show_hint() -> void:
	var game_state: Node = _get_game_state()
	if game_state != null:
		game_state.show_message("传送点 - 按 E 传送至%s" % target_label)

func can_interact() -> bool:
	return _player_in_range and _cooldown_timer <= 0.0

func interact() -> void:
	if not can_interact():
		return
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node2D = players[0]
	if not is_instance_valid(player):
		return
	player.global_position = target_position
	_cooldown_timer = teleport_cooldown
	player_teleported.emit(target_position, target_label)
	var game_state: Node = _get_game_state()
	if game_state != null:
		game_state.show_message("传送至：%s" % target_label)

func _get_game_state() -> Node:
	var states: Array = get_tree().get_nodes_in_group("game_state")
	if not states.is_empty():
		return states[0]
	return null

func _draw() -> void:
	var pulse_scale: float = 1.0 + sin(_pulse_phase) * 0.08
	var base_radius: float = 48.0 * pulse_scale
	draw_arc(Vector2.ZERO, base_radius, 0.0, TAU, 64, portal_color, 5.0)
	draw_arc(Vector2.ZERO, base_radius * 0.65, 0.0, TAU, 48, Color(portal_color.r, portal_color.g, portal_color.b, 0.6), 3.0)
	draw_circle(Vector2.ZERO, base_radius * 0.4, Color(portal_color.r, portal_color.g, portal_color.b, 0.25))
	for i in range(6):
		var angle: float = _pulse_phase + deg_to_rad(i * 60.0)
		var start_radius: float = base_radius * 0.55
		var end_radius: float = base_radius * 0.9
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * start_radius
		var end: Vector2 = Vector2(cos(angle), sin(angle)) * end_radius
		draw_line(start, end, Color(portal_color.r, portal_color.g, portal_color.b, 0.7), 3.0)
	if _player_in_range and _cooldown_timer <= 0.0:
		draw_arc(Vector2.ZERO, interact_radius, 0.0, TAU, 64, Color(portal_color.r, portal_color.g, portal_color.b, 0.3), 2.0)
