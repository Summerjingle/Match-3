extends Node2D

@export var width:int
@export var hight:int
@export var x_start:int
@export var y_start:int
@export var offset:int

var all_pieces=[]
var first_touch:Vector2
var final_touch:Vector2
var controlling=false;
var possible_pieces=[
	preload("res://Scenes/blue_piece.tscn"),
	preload("res://Scenes/yellow_piece.tscn"),
	preload("res://Scenes/pink_piece.tscn"),
	preload("res://Scenes/orange_piece.tscn"),
	preload("res://Scenes/green_piece.tscn")
]


func _ready():
	randomize()
	all_pieces = make_2d_array()
	spawn_pieces()

func _process(delta):
	touch_input();
	pass;
func make_2d_array():
	var array=[]
	
	for i in range(width):
		array.append([])
		for j in range(hight):
			array[i].append(null)
	
	return array


func grid_to_pixel(column,row):
	var new_x = x_start + offset * column
	var new_y = y_start - offset * row
	return Vector2(new_x,new_y)
func pixel_to_grid(pixel_x,pixel_y):
	var new_x =round((pixel_x-x_start)/offset);
	var new_y =round((pixel_y-y_start)/-offset);
	return Vector2(new_x,new_y)


func spawn_pieces():
	for i in range(width):
		for j in range(hight):
			var rand = randi_range(0, possible_pieces.size()-1)
			var piece = possible_pieces[rand].instantiate()
			
			# 检查是否会产生三连匹配
			while match_at(i, j, piece.color):
				# 如果匹配，重新生成不同的颜色
				piece.queue_free()  # 删除当前生成的piece
				rand = randi_range(0, possible_pieces.size()-1)
				piece = possible_pieces[rand].instantiate()
			
			add_child(piece)
			piece.position = grid_to_pixel(i,j)
			all_pieces[i][j] = piece


func match_at(column, row, color):
	# 检查水平方向（左边两个）
	if column > 1:
		if all_pieces[column-1][row] != null and all_pieces[column-2][row] != null:
			if all_pieces[column-1][row].color == color and all_pieces[column-2][row].color == color:
				return true
	
	# 检查垂直方向（上边两个）
	if row > 1:
		if all_pieces[column][row-1] != null and all_pieces[column][row-2] != null:
			if all_pieces[column][row-1].color == color and all_pieces[column][row-2].color == color:
				return true
	
	return false

func is_in_grid(column,row):
	if column>=0&&column<width:
		if row>=0&&row<hight:
			return true;
	return false;
	
func touch_input():
	if Input.is_action_just_pressed("ui_touch"):
		first_touch=get_global_mouse_position();
		var grid_position=pixel_to_grid(first_touch.x,first_touch.y);
		if is_in_grid(grid_position.x,grid_position.y):
			controlling=true;
	if Input.is_action_just_released("ui_touch"):
		final_touch=get_global_mouse_position();
		var grid_position=pixel_to_grid(final_touch.x,final_touch.y);
		if is_in_grid(grid_position.x,grid_position.y)&& controlling:
			touch_difference(pixel_to_grid(first_touch.x,first_touch.y),grid_position);
	pass;
	
func swap_pieces(column,row,direction):
	var first_piece=all_pieces[column][row];
	var other_piece=all_pieces[column+direction.x][row+direction.y];
	all_pieces[column][row]=other_piece;
	all_pieces[column+direction.x][row+direction.y]=first_piece;
	first_piece.position=grid_to_pixel(column+direction.x,row+direction.y);
	other_piece.position=grid_to_pixel(column,row);

func touch_difference(grid_1,grid_2):
	var difference=grid_2-grid_1;
	if abs(difference.x)>abs(difference.y):
		if difference.x>0:
			swap_pieces(grid_1.x,grid_1.y,Vector2(1,0))
		elif difference.x<0:
			swap_pieces(grid_1.x,grid_1.y,Vector2(-1,0))
	elif abs(difference.y)>abs(difference.x):
		if difference.y>0:
			swap_pieces(grid_1.x,grid_1.y,Vector2(0,1))
		elif difference.y<0:
			swap_pieces(grid_1.x,grid_1.y,Vector2(0,-1))
	pass;
	
	
