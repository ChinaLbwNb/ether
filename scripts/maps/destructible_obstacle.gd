extends StaticBody2D
class_name DestructibleObstacle

signal destroyed
signal damage_taken(amount: int)

@export var max_health: int = 80
@export var obstacle_type: String = "rock"
@export var size: Vector2 = Vector2(64, 64)
@export var drop_resources: Dictionary = {}
@export var obstacle_color: Color = Color(0.4, 0.35, 0.3, 0.95)

var health: int
var is_destroyed: bool = false
var _hit_flash_time: float = 0.0

func _ready() -> void:
	add_to_group("destructible_obstacles")
	add_to_group("build_blockers")
	health = max_health
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size * 0.8
	shape.shape = rect_shape
	add_child(shape)
	queue_redraw()

func _process(delta: float) -> void:
	if _hit_flash_time > 0.0:
		_hit_flash_time -= delta
		if _hit_flash_time <= 0.0:
			queue_redraw()

func take_damage(amount: int) -> void:
	if is_destroyed or amount <= 0:
		return
	health = max(health - amount, 0)
	_hit_flash_time = 0.1
	damage_taken.emit(amount)
	queue_redraw()
	if health == 0:
		_destroy()

func _destroy() -> void:
	is_destroyed = true
	remove_from_group("build_blockers")
	destroyed.emit()
	_drop_resources()
	queue_free()

func _drop_resources() -> void:
	if drop_resources.is_empty():
		return
	var game_state: Node = _get_game_state()
	if game_state == null:
		return
	var drop_text: Array[String] = []
	for resource_id in drop_resources.keys():
		var amount: int = int(drop_resources[resource_id])
		if amount > 0:
			var accepted: int = game_state.add_resource(str(resource_id), amount)
			if accepted > 0:
				drop_text.append("%s +%d" % [_get_resource_label(str(resource_id)), accepted])
	if not drop_text.is_empty():
		game_state.show_message("破坏障碍物，获得：%s" % "、".join(drop_text))

func _get_game_state() -> Node:
	var states: Array = get_tree().get_nodes_in_group("game_state")
	if not states.is_empty():
		return states[0]
	return null

func _get_resource_label(resource_id: String) -> String:
	match resource_id:
		"energy":
			return "能量"
		"iron":
			return "铁"
		"carbon":
			return "碳"
		_:
			return resource_id

func _draw() -> void:
	if is_destroyed:
		return
	var health_ratio: float = float(health) / float(max_health)
	var draw_color: Color = obstacle_color
	if _hit_flash_time > 0.0:
		draw_color = Color(1.0, 0.9, 0.85, 1.0)
	match obstacle_type:
		"rock":
			_draw_rock(draw_color)
		"crystal":
			_draw_crystal(draw_color)
		"ruin":
			_draw_ruin(draw_color)
		_:
			_draw_rock(draw_color)
	if health_ratio < 0.7:
		var crack_alpha: float = (1.0 - health_ratio) * 0.6
		_draw_cracks(crack_alpha)
	if health_ratio < 1.0:
		var bar_width: float = size.x * 0.7
		draw_rect(Rect2(Vector2(-bar_width * 0.5, -size.y * 0.5 - 12), Vector2(bar_width, 5)), Color(0.1, 0.05, 0.05, 0.85))
		draw_rect(Rect2(Vector2(-bar_width * 0.5, -size.y * 0.5 - 12), Vector2(bar_width * health_ratio, 5)), Color(0.95, 0.3, 0.2, 0.95))

func _draw_rock(color: Color) -> void:
	var half_w: float = size.x * 0.45
	var half_h: float = size.y * 0.4
	var points := PackedVector2Array([
		Vector2(-half_w, half_h * 0.3),
		Vector2(-half_w * 0.7, -half_h),
		Vector2(0, -half_h * 0.9),
		Vector2(half_w * 0.8, -half_h * 0.6),
		Vector2(half_w, half_h * 0.2),
		Vector2(half_w * 0.5, half_h),
		Vector2(-half_w * 0.3, half_h * 0.8)
	])
	draw_colored_polygon(points, color)
	var outline := points
	outline.append(points[0])
	draw_polyline(outline, Color(color.r * 0.6, color.g * 0.55, color.b * 0.5, 0.9), 3.0)
	draw_circle(Vector2(-half_w * 0.2, -half_h * 0.2), half_w * 0.15, Color(color.r * 1.2, color.g * 1.1, color.b, 0.4))

func _draw_crystal(color: Color) -> void:
	var half_w: float = size.x * 0.35
	var half_h: float = size.y * 0.45
	var points := PackedVector2Array([
		Vector2(0, -half_h),
		Vector2(half_w, -half_h * 0.3),
		Vector2(half_w * 0.6, half_h),
		Vector2(-half_w * 0.6, half_h),
		Vector2(-half_w, -half_h * 0.3)
	])
	draw_colored_polygon(points, color)
	var outline := points
	outline.append(points[0])
	draw_polyline(outline, Color(color.r * 1.3, color.g * 1.3, color.b * 1.4, 0.9), 2.5)
	draw_line(Vector2(0, -half_h), Vector2(0, half_h), Color(color.r * 1.5, color.g * 1.5, color.b * 1.6, 0.5), 2.0)
	draw_circle(Vector2.ZERO, half_w * 0.3, Color(color.r * 1.5, color.g * 1.5, color.b * 1.6, 0.3))

func _draw_ruin(color: Color) -> void:
	var half_w: float = size.x * 0.45
	var half_h: float = size.y * 0.45
	draw_rect(Rect2(Vector2(-half_w, -half_h), Vector2(half_w * 2, half_h * 2)), color)
	draw_rect(Rect2(Vector2(-half_w, -half_h), Vector2(half_w * 2, half_h * 2)), Color(color.r * 0.5, color.g * 0.45, color.b * 0.4, 0.9), false, 3.0)
	draw_rect(Rect2(Vector2(-half_w * 0.3, -half_h * 0.2), Vector2(half_w * 0.5, half_h * 0.6)), Color(color.r * 0.3, color.g * 0.25, color.b * 0.2, 0.9))
	draw_line(Vector2(-half_w * 0.8, 0), Vector2(half_w * 0.7, half_h * 0.3), Color(color.r * 0.4, color.g * 0.35, color.b * 0.3, 0.8), 2.0)

func _draw_cracks(alpha: float) -> void:
	var half_w: float = size.x * 0.4
	var half_h: float = size.y * 0.35
	var crack_color: Color = Color(0.05, 0.03, 0.02, alpha)
	draw_line(Vector2(-half_w * 0.5, -half_h * 0.8), Vector2(0, 0), crack_color, 2.0)
	draw_line(Vector2(0, 0), Vector2(half_w * 0.4, half_h * 0.6), crack_color, 2.0)
	draw_line(Vector2(0, 0), Vector2(-half_w * 0.3, half_h * 0.5), crack_color, 1.5)
	draw_line(Vector2(half_w * 0.3, -half_h * 0.5), Vector2(half_w * 0.6, 0), crack_color, 1.5)
