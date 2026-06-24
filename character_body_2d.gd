extends CharacterBody2D

signal mech_status_changed(health: int, max_health: int, shield: int, max_shield: int, energy: int, max_energy: int, weapon_name: String, weapon_level: int)
signal mech_destroyed(resource_penalty: int)

# 移动与相机缩放参数，可以在检查器(Inspector)中直接调整
@export var move_speed: float = 200.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
@export var max_health: int = 160
@export var max_shield: int = 80
@export var max_energy: int = 100
@export var shield_regen_per_second: float = 8.0
@export var energy_regen_per_second: float = 14.0
@export var dash_cost: int = 25
@export var dash_multiplier: float = 3.2
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.9
@export var ranged_damage: int = 18
@export var ranged_range: float = 380.0
@export var ranged_energy_cost: int = 12
@export var melee_damage: int = 34
@export var melee_range: float = 118.0
@export var melee_energy_cost: int = 6
@export var max_weapon_level: int = 3
@export var death_energy_penalty: int = 25

# 引用子节点
@onready var animated_sprite = $AnimatedSprite2D
@onready var camera = $Camera2D

# 记录最后的朝向，用于判断停止时播放哪个待机动画
var last_direction: String = "front"
var _last_move_vector: Vector2 = Vector2.DOWN
var health: int
var shield: int
var mech_energy: int
var active_weapon: String = "ranged"
var weapon_level: int = 1
var is_destroyed: bool = false

var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _respawn_position: Vector2

func _ready():
	add_to_group("player")
	add_to_group("enemy_targets")
	_respawn_position = global_position
	health = max_health
	shield = max_shield
	mech_energy = max_energy
	# 游戏开始时默认播放正面待机
	animated_sprite.play("idle_front")
	call_deferred("_emit_mech_status")

func _physics_process(delta):
	_update_mech_regen(delta)
	_dash_cooldown_timer = max(_dash_cooldown_timer - delta, 0.0)
	_dash_timer = max(_dash_timer - delta, 0.0)
	if is_destroyed:
		velocity = Vector2.ZERO
		return
	# 1. 处理 WASD 移动逻辑
	# 注意：如果你没有自定义按键，默认的 ui_left/right/up/down 包含了键盘方向键。
	# 建议在 项目 -> 项目设置 -> 输入映射 中，确保 WASD 绑定到了这些动作上。
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_direction != Vector2.ZERO:
		_last_move_vector = input_direction.normalized()
	if Input.is_action_just_pressed("dash"):
		try_dash(input_direction)
	var current_speed: float = move_speed
	if _dash_timer > 0.0:
		current_speed *= dash_multiplier
		if _dash_direction != Vector2.ZERO:
			input_direction = _dash_direction
	velocity = input_direction * current_speed
	move_and_slide()

	# 2. 处理动画逻辑
	if velocity.length() > 0:
		_play_move_animation(input_direction)
	else:
		# 角色停止移动，根据最后的状态播放待机动画
		if last_direction == "front":
			animated_sprite.play("idle_front")
		elif last_direction == "back":
			animated_sprite.play("idle_back")

# 3. 处理鼠标滚轮相机缩放逻辑
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# 向上滚放大视野 (拉近)
			_zoom_camera(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# 向下滚缩小视野 (拉远)
			_zoom_camera(-zoom_speed)

# 执行相机缩放并限制缩放范围
func _zoom_camera(zoom_factor: float):
	var new_zoom = camera.zoom + Vector2(zoom_factor, zoom_factor)
	# 使用 clamp 限制缩放最大和最小值，防止穿模或画面过小
	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
	camera.zoom = new_zoom

func switch_weapon() -> void:
	if active_weapon == "ranged":
		active_weapon = "melee"
	else:
		active_weapon = "ranged"
	_emit_mech_status()

func get_active_weapon_label() -> String:
	if active_weapon == "melee":
		return "裂刃"
	return "电磁步枪"

func get_active_weapon_range() -> float:
	if active_weapon == "melee":
		return melee_range
	return ranged_range

func get_active_weapon_damage() -> int:
	var base_damage: int = melee_damage if active_weapon == "melee" else ranged_damage
	return base_damage + (weapon_level - 1) * 8

func get_active_weapon_energy_cost() -> int:
	if active_weapon == "melee":
		return melee_energy_cost
	return ranged_energy_cost

func try_spend_weapon_energy() -> bool:
	var cost: int = get_active_weapon_energy_cost()
	if mech_energy < cost:
		return false
	mech_energy -= cost
	_emit_mech_status()
	return true

func can_upgrade_weapon() -> bool:
	return weapon_level < max_weapon_level

func apply_weapon_upgrade() -> bool:
	if not can_upgrade_weapon():
		return false
	weapon_level += 1
	max_energy += 10
	mech_energy = min(mech_energy + 20, max_energy)
	_emit_mech_status()
	return true

func try_dash(direction: Vector2) -> bool:
	if is_destroyed or _dash_cooldown_timer > 0.0 or mech_energy < dash_cost:
		return false
	_dash_direction = direction.normalized()
	if _dash_direction == Vector2.ZERO:
		_dash_direction = _last_move_vector
	mech_energy -= dash_cost
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_emit_mech_status()
	return true

func _play_move_animation(input_direction: Vector2) -> void:
	var move_direction: Vector2 = input_direction
	if move_direction == Vector2.ZERO:
		move_direction = _last_move_vector
	# 斜向移动时优先使用横向分量，避免右下移动被下方向动作覆盖。
	if move_direction.x > 0.0:
		animated_sprite.play("run_back")
		last_direction = "back"
	elif move_direction.x < 0.0:
		animated_sprite.play("run_front")
		last_direction = "front"
	elif move_direction.y > 0.0:
		animated_sprite.play("run_front")
		last_direction = "front"
	else:
		animated_sprite.play("run_back")
		last_direction = "back"

func take_damage(amount: int) -> void:
	if is_destroyed or amount <= 0:
		return
	var remaining_damage: int = amount
	if shield > 0:
		var absorbed: int = mini(shield, remaining_damage)
		shield -= absorbed
		remaining_damage -= absorbed
	if remaining_damage > 0:
		health = maxi(health - remaining_damage, 0)
	if health == 0:
		_destroy_and_respawn()
	else:
		_emit_mech_status()

func _update_mech_regen(delta: float) -> void:
	if is_destroyed:
		return
	var old_shield: int = shield
	var old_energy: int = mech_energy
	shield = mini(max_shield, shield + int(floor(shield_regen_per_second * delta)))
	mech_energy = mini(max_energy, mech_energy + int(floor(energy_regen_per_second * delta)))
	if shield != old_shield or mech_energy != old_energy:
		_emit_mech_status()

func _destroy_and_respawn() -> void:
	is_destroyed = true
	mech_destroyed.emit(death_energy_penalty)
	global_position = _respawn_position
	health = max_health
	shield = 0
	mech_energy = max(max_energy - death_energy_penalty, 0)
	_dash_timer = 0.0
	_dash_cooldown_timer = dash_cooldown
	is_destroyed = false
	_emit_mech_status()

func _emit_mech_status() -> void:
	mech_status_changed.emit(
		health,
		max_health,
		shield,
		max_shield,
		mech_energy,
		max_energy,
		get_active_weapon_label(),
		weapon_level
	)
