extends Node2D
class_name PowerGenerator

@export var max_health: int = 140
@export var power_output: int = 30
@export var asset_texture: Texture2D
@export var visual_size: Vector2 = Vector2(76, 76)

var health: int
var is_destroyed: bool = false
var _game_state: Node
var _is_registered: bool = false

func _ready() -> void:
	add_to_group("enemy_targets")
	add_to_group("repairable_buildings")
	add_to_group("build_blockers")
	health = max_health
	_game_state = _get_game_state()
	_register_power()
	queue_redraw()

func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	health = max(health - amount, 0)
	queue_redraw()
	if health == 0:
		is_destroyed = true
		_unregister_power()
		remove_from_group("enemy_targets")
		remove_from_group("repairable_buildings")
		remove_from_group("build_blockers")
		queue_free()

func repair(amount: int) -> void:
	if is_destroyed:
		return
	health = min(health + amount, max_health)
	queue_redraw()

func is_damaged() -> bool:
	return not is_destroyed and health < max_health

func _exit_tree() -> void:
	_unregister_power()

func _register_power() -> void:
	if _game_state != null and not _is_registered:
		_game_state.register_power_source(power_output)
		_is_registered = true

func _unregister_power() -> void:
	if _game_state != null and _is_registered:
		_game_state.unregister_power_source(power_output)
		_is_registered = false

func _get_game_state() -> Node:
	var states: Array = get_tree().get_nodes_in_group("game_state")
	if states.is_empty():
		return null
	return states[0]

func _draw() -> void:
	var health_ratio := float(health) / float(max_health)
	if asset_texture != null:
		draw_texture_rect(asset_texture, Rect2(-visual_size * 0.5, visual_size), false)
	else:
		draw_circle(Vector2.ZERO, 32.0, Color(0.2, 0.58, 0.95, 1.0))
	draw_circle(Vector2.ZERO, 38.0, Color(0.2, 0.85, 1.0, 0.16))
	if health_ratio < 1.0:
		draw_rect(Rect2(Vector2(-30, -52), Vector2(60, 5)), Color(0.08, 0.02, 0.02, 0.8))
		draw_rect(Rect2(Vector2(-30, -52), Vector2(60 * health_ratio, 5)), Color(0.2, 0.95, 0.55, 0.95))
