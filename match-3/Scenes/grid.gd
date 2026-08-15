extends Node2D

#state machine
enum{wait,move}


@export var width:int
@export var hight:int
@export var x_start:int
@export var y_start:int
@export var offset:int
@export var y_offset:int

var state
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
	state=move;
	randomize()
	all_pieces = make_2d_array()
	spawn_pieces()

func _process(_delta):
	if state==move:
		touch_input();
	

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

# 查找所有匹配的函数
func find_matches():
	# 首先重置所有砖块的透明度为1（不透明）
	reset_piece_alpha()
	
	var matched_pieces = []  # 存储所有需要标记的砖块坐标
	
	# 检查水平匹配（横向）
	for row in range(hight):
		for col in range(width - 2):
			if all_pieces[col][row] != null and all_pieces[col+1][row] != null and all_pieces[col+2][row] != null:
				var color = all_pieces[col][row].color
				if all_pieces[col+1][row].color == color and all_pieces[col+2][row].color == color:
					# 找到至少3个连续的相同颜色
					var match_length = 3
					# 继续检查后面是否还有更多
					var check_col = col + 3
					while check_col < width and all_pieces[check_col][row] != null and all_pieces[check_col][row].color == color:
						match_length += 1
						check_col += 1
					
					# 记录所有匹配的砖块
					for k in range(match_length):
						var pos = Vector2(col + k, row)
						if not matched_pieces.has(pos):
							matched_pieces.append(pos)
	
	# 检查垂直匹配（纵向）
	for col in range(width):
		for row in range(hight - 2):
			if all_pieces[col][row] != null and all_pieces[col][row+1] != null and all_pieces[col][row+2] != null:
				var color = all_pieces[col][row].color
				if all_pieces[col][row+1].color == color and all_pieces[col][row+2].color == color:
					# 找到至少3个连续的相同颜色
					var match_length = 3
					# 继续检查后面是否还有更多
					var check_row = row + 3
					while check_row < hight and all_pieces[col][check_row] != null and all_pieces[col][check_row].color == color:
						match_length += 1
						check_row += 1
					
					# 记录所有匹配的砖块
					for k in range(match_length):
						var pos = Vector2(col, row + k)
						if not matched_pieces.has(pos):
							matched_pieces.append(pos)
	# 只有找到匹配时才启动销毁定时器
	if matched_pieces.size() > 0:
		get_parent().get_node("destroy_timer").start()

	# 将所有匹配的砖块透明度设为0.5
	for pos in matched_pieces:
		var piece = all_pieces[pos.x][pos.y]
		if piece != null:
			piece.matched = true  
			piece.modulate = Color(1, 1, 1, 0.5)  # 设置透明度为0.5
	
	# 返回匹配的砖块列表，方便后续处理
	return matched_pieces

# 重置所有砖块的透明度
func reset_piece_alpha():
	for i in range(width):
		for j in range(hight):
			var piece = all_pieces[i][j]
			if piece != null:
				piece.modulate = Color(1, 1, 1, 1)  # 恢复为完全不透明

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
			controlling=false;
	
func swap_pieces(column,row,direction):
	var first_piece=all_pieces[column][row];
	var other_piece=all_pieces[column+direction.x][row+direction.y];
	if first_piece!=null &&other_piece!=null:
		state=wait 
		all_pieces[column][row]=other_piece;
		all_pieces[column+direction.x][row+direction.y]=first_piece;
		first_piece.move(grid_to_pixel(column+direction.x,row+direction.y));
		other_piece.move(grid_to_pixel(column,row));

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
	
	# 交换完成后，延迟检测匹配（等待移动动画完成）
	check_matches_after_swap()
	pass;

# 新增：交换后检测匹配的函数
func check_matches_after_swap():
	# 等待0.15秒让移动动画完成（根据你的动画时长调整）
	await get_tree().create_timer(0.15).timeout
	
	# 执行匹配检测
	var matches = find_matches()
	
	# 如果有匹配，打印信息（方便调试）
	if matches.size() > 0:
		print("找到 ", matches.size(), " 个匹配的砖块")
	else:
		print("没有找到匹配")
		state = move   # 没匹配，恢复玩家操作

func destroy_matched():
	for i in range(width):  
		for j in range(hight):
			if all_pieces[i][j] != null and all_pieces[i][j].matched:
				all_pieces[i][j].queue_free()
				all_pieces[i][j] = null
	# state = move 移到级联全部结束后再设置
	get_parent().get_node("collapse_timer").start()
					
func collapse_columns():
	for i in range(width):   
		for j in range(hight):  
			if all_pieces[i][j] == null:
				for k in range(j+1,hight):
					if all_pieces[i][k]!=null:
						all_pieces[i][k].move(grid_to_pixel(i,j))
						all_pieces[i][j]=all_pieces[i][k]
						all_pieces[i][k]=null
						break
	# refill_timer 已移除，refill 改由 _on_collapse_timer_timeout 手动调用
	pass
						
	

func _on_destroy_timer_timeout() -> void:
	destroy_matched()


func _on_collapse_timer_timeout() -> void:
	collapse_columns()
	await get_tree().create_timer(0.3).timeout      # 等 collapse 动画播完再 refill
	refill_columns()
	await get_tree().create_timer(0.3).timeout      # 等 refill 动画播完再检测
	var matches = find_matches()
	if matches.size() > 0:
		get_parent().get_node("destroy_timer").start()   # 有级联匹配，继续销毁循环
	else:
		state = move   # 全部结束后才恢复玩家操作

func refill_columns():
	for i in range(width):
		for j in range(hight):
			if all_pieces[i][j] == null:
				var rand = randi_range(0, possible_pieces.size()-1)
				var piece = possible_pieces[rand].instantiate()
				
				# 检查是否会产生三连匹配
				while match_at(i, j, piece.color):
					# 如果匹配，重新生成不同的颜色
					piece.queue_free()  # 删除当前生成的piece
					rand = randi_range(0, possible_pieces.size()-1)
					piece = possible_pieces[rand].instantiate()
				
				add_child(piece)
				piece.position = grid_to_pixel(i,j+y_offset)
				piece.move(grid_to_pixel(i,j))
				all_pieces[i][j] = piece

func _on_refill_timer_timeout() -> void:
	refill_columns()
