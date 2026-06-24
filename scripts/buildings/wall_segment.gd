extends StaticBody2D
class_name WallSegment

@export var max_health: int = 180
@export var asset_texture: Texture2D
@export var visual_size: Vector2 = Vector2(64, 64)

var health: int
var is_destroyed: bool = false
var _research_bonuses: Dictionary = {}

func _ready() -> void:
	add_to_group("enemy_targets")
	add_to_group("repairable_buildings")
	add_to_group("build_blockers")
	health = max_health
	queue_redraw()

func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	health = max(health - amount, 0)
	queue_redraw()
	if health == 0:
		is_destroyed = true
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

func apply_research_bonus(tech_id: String) -> void:
	if _research_bonuses.has(tech_id):
		return
	_research_bonuses[tech_id] = true
	if tech_id == "wall_plating":
		max_health += 60
		health += 60
	queue_redraw()

func _draw() -> void:
	var health_ratio := float(health) / float(max_health)
	if asset_texture != null:
		draw_texture_rect(asset_texture, Rect2(-visual_size * 0.5, visual_size), false)
	else:
		draw_rect(Rect2(-visual_size * 0.5, visual_size), Color(0.42, 0.54, 0.58, 1.0), true)
		draw_rect(Rect2(-visual_size * 0.5, visual_size), Color(0.72, 0.86, 0.9, 1.0), false, 3.0)
	if health_ratio < 1.0:
		draw_rect(Rect2(Vector2(-28, -42), Vector2(56, 5)), Color(0.08, 0.02, 0.02, 0.8))
		draw_rect(Rect2(Vector2(-28, -42), Vector2(56 * health_ratio, 5)), Color(0.2, 0.95, 0.55, 0.95))
	if health_ratio < 0.45:
		draw_circle(Vector2.ZERO, 30.0, Color(1.0, 0.16, 0.08, 0.18))
