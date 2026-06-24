extends Node2D
class_name ResearchStation

@export var max_health: int = 130
@export var asset_texture: Texture2D
@export var visual_size: Vector2 = Vector2(78, 78)

var health: int
var is_destroyed: bool = false
var _research_manager: Node
var _is_registered: bool = false

func _ready() -> void:
	add_to_group("enemy_targets")
	add_to_group("repairable_buildings")
	add_to_group("build_blockers")
	add_to_group("research_stations")
	health = max_health
	_research_manager = _get_research_manager()
	_register_station()
	queue_redraw()

func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	health = maxi(health - amount, 0)
	queue_redraw()
	if health == 0:
		is_destroyed = true
		_unregister_station()
		remove_from_group("enemy_targets")
		remove_from_group("repairable_buildings")
		remove_from_group("build_blockers")
		remove_from_group("research_stations")
		queue_free()

func repair(amount: int) -> void:
	if is_destroyed:
		return
	health = mini(health + amount, max_health)
	queue_redraw()

func is_damaged() -> bool:
	return not is_destroyed and health < max_health

func _exit_tree() -> void:
	_unregister_station()

func _register_station() -> void:
	if _research_manager != null and not _is_registered:
		_research_manager.register_station()
		_is_registered = true

func _unregister_station() -> void:
	if _research_manager != null and _is_registered:
		_research_manager.unregister_station()
		_is_registered = false

func _get_research_manager() -> Node:
	var managers: Array = get_tree().get_nodes_in_group("research_manager")
	if managers.is_empty():
		return null
	return managers[0]

func _draw() -> void:
	var health_ratio: float = float(health) / float(max_health)
	if asset_texture != null:
		draw_texture_rect(asset_texture, Rect2(-visual_size * 0.5, visual_size), false)
	else:
		draw_rect(Rect2(-visual_size * 0.5, visual_size), Color(0.16, 0.28, 0.38, 1.0), true)
		draw_rect(Rect2(-visual_size * 0.5, visual_size), Color(0.55, 0.95, 1.0, 1.0), false, 3.0)
		draw_circle(Vector2.ZERO, 19.0, Color(0.3, 0.9, 1.0, 0.25))
		draw_line(Vector2(-24, 18), Vector2(24, -18), Color(0.75, 1.0, 1.0, 0.95), 4.0)
	if health_ratio < 1.0:
		draw_rect(Rect2(Vector2(-30, -52), Vector2(60, 5)), Color(0.08, 0.02, 0.02, 0.8))
		draw_rect(Rect2(Vector2(-30, -52), Vector2(60 * health_ratio, 5)), Color(0.2, 0.95, 0.55, 0.95))
