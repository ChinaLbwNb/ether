extends Node2D
class_name ParticleEffect

@export var effect_type: String = "explosion"
@export var color: Color = Color(1, 0.6, 0.2, 1)
@export var duration: float = 0.6
@export var particle_count: int = 12
@export var min_speed: float = 40.0
@export var max_speed: float = 120.0
@export var start_size: float = 6.0
@export var end_size: float = 1.0

var _time: float = 0.0
var _particles: Array = []

func _ready() -> void:
	_spawn_particles()
	queue_redraw()

func spawn_at(position: Vector2, effect: String = "explosion", effect_color: Color = Color(1, 0.6, 0.2, 1)) -> void:
	global_position = position
	effect_type = effect
	color = effect_color
	match effect:
		"explosion":
			particle_count = 14
			duration = 0.6
			min_speed = 50.0
			max_speed = 140.0
			start_size = 7.0
			end_size = 1.0
		"death":
			particle_count = 10
			duration = 0.5
			min_speed = 30.0
			max_speed = 90.0
			start_size = 5.0
			end_size = 1.0
		"build":
			particle_count = 16
			duration = 0.7
			min_speed = 20.0
			max_speed = 70.0
			start_size = 4.0
			end_size = 1.0
		"upgrade":
			particle_count = 20
			duration = 0.9
			min_speed = 30.0
			max_speed = 100.0
			start_size = 5.0
			end_size = 1.0
		"collect":
			particle_count = 8
			duration = 0.5
			min_speed = 25.0
			max_speed = 70.0
			start_size = 4.0
			end_size = 1.0
	_spawn_particles()
	queue_redraw()

func _spawn_particles() -> void:
	_particles.clear()
	for i in range(particle_count):
		var angle: float = randf() * TAU
		var speed: float = lerp(min_speed, max_speed, randf())
		_particles.append({
			"angle": angle,
			"speed": speed,
			"offset": Vector2.ZERO,
			"size": start_size,
			"alpha": 1.0
		})

func _process(delta: float) -> void:
	_time += delta
	var progress: float = clamp(_time / duration, 0.0, 1.0)
	for p in _particles:
		var angle: float = p["angle"]
		var speed: float = p["speed"]
		p["offset"] = Vector2(cos(angle), sin(angle)) * speed * _time * (1.0 - progress * 0.5)
		p["size"] = lerp(start_size, end_size, progress)
		p["alpha"] = 1.0 - progress
	queue_redraw()
	if progress >= 1.0:
		queue_free()

func _draw() -> void:
	for p in _particles:
		var c: Color = color
		c.a = float(p["alpha"])
		draw_circle(Vector2(p["offset"]), float(p["size"]), c)
