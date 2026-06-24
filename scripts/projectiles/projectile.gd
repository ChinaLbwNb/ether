extends Node2D
class_name Projectile

@export var speed: float = 760.0
@export var hit_radius: float = 16.0

var target: Node2D
var damage: int = 0

func configure(new_target: Node2D, new_damage: int) -> void:
	target = new_target
	damage = new_damage

func _process(delta: float) -> void:
	if _game_is_finished():
		queue_free()
		return
	if target == null or not is_instance_valid(target) or target.is_dead:
		queue_free()
		return
	var direction := global_position.direction_to(target.global_position)
	global_position += direction * speed * delta
	if global_position.distance_to(target.global_position) <= hit_radius:
		target.take_damage(damage)
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(0.75, 1.0, 1.0, 1.0))
	draw_circle(Vector2.ZERO, 12.0, Color(0.2, 0.85, 1.0, 0.35))

func _game_is_finished() -> bool:
	var states: Array = get_tree().get_nodes_in_group("game_state")
	return not states.is_empty() and states[0].is_finished
