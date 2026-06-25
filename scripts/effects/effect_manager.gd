extends Node
class_name EffectManager

var _effects_root: Node2D = null

func _ready() -> void:
	add_to_group("effect_manager")
	var effects_root: Node2D = get_tree().get_root().find_child("Effects", true, false)
	if effects_root != null and effects_root is Node2D:
		_effects_root = effects_root

func spawn_explosion(position: Vector2, color: Color = Color(1, 0.6, 0.2, 1)) -> void:
	_spawn_particle(position, "explosion", color)

func spawn_death(position: Vector2, color: Color = Color(0.9, 0.2, 0.2, 1)) -> void:
	_spawn_particle(position, "death", color)

func spawn_build(position: Vector2, color: Color = Color(0.2, 0.9, 0.6, 1)) -> void:
	_spawn_particle(position, "build", color)

func spawn_upgrade(position: Vector2, color: Color = Color(1, 0.9, 0.2, 1)) -> void:
	_spawn_particle(position, "upgrade", color)

func spawn_collect(position: Vector2, color: Color = Color(0.3, 0.7, 1, 1)) -> void:
	_spawn_particle(position, "collect", color)

func _spawn_particle(position: Vector2, effect_type: String, color: Color) -> void:
	if _effects_root == null:
		return
	var effect := ParticleEffect.new()
	effect.global_position = position
	effect.spawn_at(position, effect_type, color)
	_effects_root.add_child(effect)
