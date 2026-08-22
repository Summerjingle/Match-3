extends Node2D

@export var color: String = "white"
var move_tween: Tween
var matched: bool = false
var special_type: int = 0  # 0=普通, 1=清行, 2=清列

# 每种颜色的清行 / 清列贴图
const ROW_TEXTURES := {
	"blue": preload("res://Art/Pieces/Blue Row.png"),
	"yellow": preload("res://Art/Pieces/Yellow Row.png"),
	"pink": preload("res://Art/Pieces/Pink Row.png"),
	"orange": preload("res://Art/Pieces/Orange Row.png"),
	"green": preload("res://Art/Pieces/Green Row.png"),
}
const COLUMN_TEXTURES := {
	"blue": preload("res://Art/Pieces/Blue Column.png"),
	"yellow": preload("res://Art/Pieces/Yellow Column.png"),
	"pink": preload("res://Art/Pieces/Pink Column.png"),
	"orange": preload("res://Art/Pieces/Orange Column.png"),
	"green": preload("res://Art/Pieces/Green Column.png"),
}

func _ready() -> void:
	pass  # 这里什么都不做

func move(target: Vector2) -> void:
	if move_tween and move_tween.is_valid():
		move_tween.kill()

	move_tween = create_tween()
	move_tween.tween_property(self, "position", target, 0.3)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)

# 把棋子转成特殊棋子：t=1 清行, t=2 清列，并换成对应的贴图
func set_special(t: int) -> void:
	special_type = t
	var sprite = get_node_or_null("Sprite2D")
	if sprite == null:
		return
	if t == 1 and ROW_TEXTURES.has(color):
		sprite.texture = ROW_TEXTURES[color]
	elif t == 2 and COLUMN_TEXTURES.has(color):
		sprite.texture = COLUMN_TEXTURES[color]

func _process(_delta: float) -> void:
	pass
