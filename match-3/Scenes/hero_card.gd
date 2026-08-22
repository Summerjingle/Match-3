extends Node2D

# 英雄卡片：一个节点包含 头像 + 能量条 + 血条。
# 颜色名 + 头像贴图由场景实例的 @export 覆盖设置。

@export var color_name: String = "yellow"
@export var hero_texture: Texture2D

@export var max_energy: int = 100
@export var max_hp: int = 100

var energy: int = 0
var hp: int = max_hp

# 充能满后的头像晃动（原地微转）
var _full_tween: Tween = null

# 充能满后点头像放技能：跳到 boss 脸上打一下
# 命中瞬间发 attacked，game_window 接它扣 boss 血
signal attacked
var attack_target: Control = null  # 被打目标，game_window 在 _ready 里赋值为 boss
var _attacking: bool = false
var _attack_tween: Tween = null

@onready var portrait: TextureRect = $Portrait
@onready var energy_bar: ProgressBar = $EnergyBar
@onready var hp_bar: ProgressBar = $HPBar


func _ready():
	if hero_texture != null:
		portrait.texture = hero_texture
	energy_bar.max_value = max_energy
	energy_bar.value = energy
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	portrait.gui_input.connect(_on_portrait_gui_input)


# 按配置路径换头像贴图（game_window 在 _load_config 里调用）
func set_portrait(texture_path: String):
	var tex = load(texture_path)
	if tex is Texture2D:
		portrait.texture = tex
		hero_texture = tex


# 用配置初始化最大血量/充能（game_window 在 _ready 里调用）
func setup(new_max_hp: int, new_max_energy: int):
	max_hp = new_max_hp
	max_energy = new_max_energy
	hp = max_hp
	energy = 0
	if is_node_ready():
		energy_bar.max_value = max_energy
		energy_bar.value = energy
		hp_bar.max_value = max_hp
		hp_bar.value = hp


func set_energy(v: int):
	energy = clampi(v, 0, max_energy)
	if is_node_ready():
		energy_bar.value = energy
		if energy >= max_energy:
			_start_full_shake()
		else:
			_stop_full_shake()


# 充能满了：头像绕自身中心正弦摆动，直到能量被消耗
func _start_full_shake():
	if _full_tween != null:
		return
	portrait.pivot_offset = portrait.size / 2.0  # 旋转轴放到头像中心
	var amp := 0.12  # 弧度，约 ±7°
	_full_tween = create_tween().set_loops()
	_full_tween.tween_property(portrait, "rotation", amp, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_full_tween.tween_property(portrait, "rotation", -amp, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_full_tween.tween_property(portrait, "rotation", 0.0, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_full_shake():
	if _full_tween != null:
		_full_tween.kill()
		_full_tween = null
	portrait.rotation = 0.0
	portrait.pivot_offset = Vector2.ZERO


func set_hp(v: int):
	hp = clampi(v, 0, max_hp)
	if is_node_ready():
		hp_bar.value = hp


# 点击头像：充能满了就放技能（清空能量、跳过去打 boss）
func _on_portrait_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if energy >= max_energy and not _attacking:
			_start_attack()


func _start_attack():
	_attacking = true
	_stop_full_shake()
	set_energy(0)  # 清空充能槽
	var start_pos: Vector2 = portrait.global_position
	var target_pos: Vector2 = start_pos
	if attack_target != null:
		target_pos = attack_target.global_position + attack_target.size / 2.0
		target_pos.y -= attack_target.size.y * 0.3  # 落在 boss 脸上而不是正中心
	portrait.z_index = 100  # 飞行时画在 boss 上面
	# 飞行：tween_method 插值，直线 + 正弦抛高形成弧线
	_attack_tween = create_tween()
	_attack_tween.tween_method(_hop.bind(start_pos, target_pos), 0.0, 1.0, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.tween_callback(_land_attack)
	_attack_tween.tween_property(portrait, "global_position", start_pos, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_attack_tween.tween_callback(_finish_attack.bind(start_pos))


# 弧线插值：t∈[0,1]，起点到终点线性插值并额外抛高 150px
func _hop(t: float, start: Vector2, target: Vector2):
	var pos: Vector2 = start.lerp(target, t)
	pos.y -= sin(t * PI) * 150.0
	portrait.global_position = pos


# 飞到 boss 面前的瞬间：通知 game_window 扣血
func _land_attack():
	attacked.emit()


func _finish_attack(start_pos: Vector2):
	portrait.global_position = start_pos
	portrait.z_index = 0
	_attacking = false
	_attack_tween = null
