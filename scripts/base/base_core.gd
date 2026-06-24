extends Node2D
class_name BaseCore

signal health_changed(current_health: int, max_health: int)
signal destroyed

@export var max_health: int = 500
@export var core_radius: float = 72.0
@export var asset_texture: Texture2D
@export var visual_size: Vector2 = Vector2(128, 128)

var health: int

func _ready() -> void:
	add_to_group("base_core")
	add_to_group("enemy_targets")
	add_to_group("repairable_buildings")
	health = max_health
	health_changed.emit(health, max_health)
	queue_redraw()

func is_damaged() -> bool:
	return health > 0 and health < max_health

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = max(health - amount, 0)
	health_changed.emit(health, max_health)
	queue_redraw()
	if health == 0:
		remove_from_group("enemy_targets")
		remove_from_group("repairable_buildings")
		destroyed.emit()

func repair(amount: int) -> void:
	if health <= 0:
		return
	health = min(health + amount, max_health)
	health_changed.emit(health, max_health)
	queue_redraw()

func _draw() -> void:
	var health_ratio := float(health) / float(max_health)
	if asset_texture != null:
		draw_texture_rect(asset_texture, Rect2(-visual_size * 0.5, visual_size), false)
		draw_arc(Vector2.ZERO, max(visual_size.x, visual_size.y) * 0.56, 0.0, TAU, 96, Color(0.5, 0.95, 1.0, 0.8), 4.0)
		if health_ratio < 0.7:
			draw_circle(Vector2.ZERO, max(visual_size.x, visual_size.y) * 0.5, Color(1.0, 0.2, 0.1, 0.16))
		return
	var body_color := Color(0.12, 0.45, 0.9, 0.95)
	if health_ratio < 0.35:
		body_color = Color(0.95, 0.28, 0.12, 0.95)
	elif health_ratio < 0.7:
		body_color = Color(0.95, 0.75, 0.22, 0.95)
	draw_circle(Vector2.ZERO, core_radius, Color(0.04, 0.08, 0.12, 0.9))
	draw_circle(Vector2.ZERO, core_radius * 0.74, body_color)
	draw_circle(Vector2.ZERO, core_radius * 0.32, Color(0.65, 0.95, 1.0, 0.95))
	draw_arc(Vector2.ZERO, core_radius + 10.0, 0.0, TAU, 96, Color(0.5, 0.95, 1.0, 0.8), 4.0)
