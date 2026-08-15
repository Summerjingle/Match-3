extends Node2D  # 或你的父类

@export var color: String = "white"
var move_tween: Tween
var matched: bool = false 


func _ready() -> void:
	# 在 _ready 中初始化 Tween
	move_tween = create_tween()
	# 可选：设置 tween 属性
	move_tween.set_parallel(false)  # 串行执行

func move(target: Vector2) -> void:
	if move_tween:
		move_tween.kill()
	
	move_tween = create_tween()
	move_tween.tween_property(self, "position", target, 0.3)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)
	
func _process(delta: float) -> void:
	pass
