extends Node2D
class_name ResourceDeposit

signal depleted

@export var resource_id: String = "energy"
@export var total_amount: int = 100
@export var collect_amount: int = 10
@export var interact_radius: float = 95.0
@export var asset_texture: Texture2D
@export var visual_size: Vector2 = Vector2(96, 96)

var remaining_amount: int

func _ready() -> void:
	add_to_group("resource_deposits")
	remaining_amount = total_amount
	queue_redraw()

func can_collect() -> bool:
	return remaining_amount > 0

func collect() -> int:
	return extract_amount(collect_amount)

func extract_amount(requested_amount: int) -> int:
	if remaining_amount <= 0:
		return 0
	var amount: int = mini(max(requested_amount, 0), remaining_amount)
	remaining_amount -= amount
	if remaining_amount == 0:
		depleted.emit()
	queue_redraw()
	return amount

func _draw() -> void:
	var ratio := 0.0
	if total_amount > 0:
		ratio = float(remaining_amount) / float(total_amount)
	if asset_texture != null:
		var glow_color := Color(0.35, 1.0, 0.42, 0.22) if remaining_amount > 0 else Color(0.15, 0.15, 0.15, 0.35)
		draw_circle(Vector2.ZERO, 52.0 * ratio, glow_color)
		draw_texture_rect(asset_texture, Rect2(-visual_size * 0.5, visual_size), false)
		if remaining_amount <= 0:
			draw_circle(Vector2.ZERO, 48.0, Color(0.0, 0.0, 0.0, 0.35))
		return
	var fill_color := Color(0.1, 0.9, 1.0, 0.9) if remaining_amount > 0 else Color(0.24, 0.26, 0.28, 0.75)
	var points := PackedVector2Array([
		Vector2(0, -38),
		Vector2(34, -8),
		Vector2(22, 34),
		Vector2(-22, 34),
		Vector2(-34, -8)
	])
	var outline := points
	outline.append(points[0])
	draw_colored_polygon(points, fill_color)
	draw_polyline(outline, Color(0.8, 1.0, 1.0, 0.9), 3.0)
	draw_circle(Vector2.ZERO, 46.0 * ratio, Color(0.35, 0.95, 1.0, 0.18))
