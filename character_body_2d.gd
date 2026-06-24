extends CharacterBody2D

# 移动与相机缩放参数，可以在检查器(Inspector)中直接调整
@export var move_speed: float = 200.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0

# 引用子节点
@onready var animated_sprite = $AnimatedSprite2D
@onready var camera = $Camera2D

# 记录最后的朝向，用于判断停止时播放哪个待机动画
var last_direction: String = "front"

func _ready():
	add_to_group("player")
	# 游戏开始时默认播放正面待机
	animated_sprite.play("idle_front")

func _physics_process(_delta):
	# 1. 处理 WASD 移动逻辑
	# 注意：如果你没有自定义按键，默认的 ui_left/right/up/down 包含了键盘方向键。
	# 建议在 项目 -> 项目设置 -> 输入映射 中，确保 WASD 绑定到了这些动作上。
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_direction * move_speed
	move_and_slide()

	# 2. 处理动画逻辑
	if velocity.length() > 0:
		# 角色正在移动
		# 根据你的逻辑：向左(A)或向下(S) -> run_front
		if Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_down"):
			animated_sprite.play("run_front")
			last_direction = "front"
		# 向右(D)或向上(W) -> run_back
		elif Input.is_action_pressed("ui_right") or Input.is_action_pressed("ui_up"):
			animated_sprite.play("run_back")
			last_direction = "back"
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
