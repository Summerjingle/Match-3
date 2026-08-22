extends Node2D

#state machine
enum{wait,move}

# 销毁棋子后发出：color_counts = {颜色: 颗数}，由战斗系统处理（boss 掉血、英雄能量）
signal pieces_destroyed(color_counts: Dictionary)


@export var width:int
@export var hight:int
@export var x_start:int
@export var y_start:int
@export var offset:int
@export var y_offset:int

#Score
var score:int=0
@export var score_per_piece:int=10

# 输入锁定标记：战斗系统判定结束后调用 lock_input() 锁住棋盘
var game_over: bool = false

#Swap Back Variables
var piece_one=null
var piece_two=null
var last_place=Vector2(0,0)
var last_direction=Vector2(0,0)
var move_check=false


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
	if state==move and not game_over:
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
func find_matches(from_player_move: bool = false):
	# 首先重置所有砖块的透明度为1（不透明）
	reset_piece_alpha()

	var matched_pieces = []  # 存储所有需要标记的砖块坐标
	var runs = []            # 存储所有匹配段：{start, length, horizontal}

	# 检查水平匹配（横向）
	for row in range(hight):
		for col in range(width - 2):
			if all_pieces[col][row] != null and all_pieces[col+1][row] != null and all_pieces[col+2][row] != null:
				var color = all_pieces[col][row].color
				if all_pieces[col+1][row].color == color and all_pieces[col+2][row].color == color:
					# 只记录真正起点，避免同一段被重复记录（防止重复晋升特殊棋子）
					if col > 0 and all_pieces[col-1][row] != null and all_pieces[col-1][row].color == color:
						continue
					# 找到至少3个连续的相同颜色
					var match_length = 3
					# 继续检查后面是否还有更多
					var check_col = col + 3
					while check_col < width and all_pieces[check_col][row] != null and all_pieces[check_col][row].color == color:
						match_length += 1
						check_col += 1

					# 记录整段匹配（起点、长度、方向）
					runs.append({"start": Vector2(col, row), "length": match_length, "horizontal": true})

	# 检查垂直匹配（纵向）
	for col in range(width):
		for row in range(hight - 2):
			if all_pieces[col][row] != null and all_pieces[col][row+1] != null and all_pieces[col][row+2] != null:
				var color = all_pieces[col][row].color
				if all_pieces[col][row+1].color == color and all_pieces[col][row+2].color == color:
					# 只记录真正起点，避免同一段被重复记录（防止重复晋升特殊棋子）
					if row > 0 and all_pieces[col][row-1] != null and all_pieces[col][row-1].color == color:
						continue
					# 找到至少3个连续的相同颜色
					var match_length = 3
					# 继续检查后面是否还有更多
					var check_row = row + 3
					while check_row < hight and all_pieces[col][check_row] != null and all_pieces[col][check_row].color == color:
						match_length += 1
						check_row += 1

					# 记录整段匹配（起点、长度、方向）
					runs.append({"start": Vector2(col, row), "length": match_length, "horizontal": false})

	# 标记所有匹配的砖块坐标
	for run in runs:
		for k in range(run.length):
			var pos
			if run.horizontal:
				pos = run.start + Vector2(k, 0)
			else:
				pos = run.start + Vector2(0, k)
			if not matched_pieces.has(pos):
				matched_pieces.append(pos)

	# 特殊棋子晋升：任何 ≥4 连的匹配段都产生一颗特殊棋子（不销毁）
	# - 玩家移动：优先晋升被移动的棋子，类型按移动方向（水平→清行，垂直→清列）
	# - 级联/补充（collapse/refill）产生的 ≥4 连同样晋升，类型按匹配段方向（横向段→清行，纵向段→清列）
	var moved_pos = last_place + last_direction
	for run in runs:
		if run.length < 4:
			continue
		var promote_pos = run.start
		var promote_piece = null
		# 玩家移动：被移动的棋子若在这个 ≥4 段里，优先晋升它
		if from_player_move and is_in_grid(moved_pos.x, moved_pos.y) and matched_pieces.has(moved_pos):
			var in_run = false
			if run.horizontal:
				in_run = run.start.y == moved_pos.y and moved_pos.x >= run.start.x and moved_pos.x < run.start.x + run.length
			else:
				in_run = run.start.x == moved_pos.x and moved_pos.y >= run.start.y and moved_pos.y < run.start.y + run.length
			if in_run and all_pieces[moved_pos.x][moved_pos.y] == piece_one:
				promote_pos = moved_pos
				promote_piece = all_pieces[moved_pos.x][moved_pos.y]
		# 否则（或该段不含被移动棋子）：找该段内第一颗普通棋子晋升
		if promote_piece == null or promote_piece.special_type != 0:
			promote_piece = null
			for k in range(run.length):
				var cand_pos
				if run.horizontal:
					cand_pos = run.start + Vector2(k, 0)
				else:
					cand_pos = run.start + Vector2(0, k)
				var cand = all_pieces[cand_pos.x][cand_pos.y]
				if cand != null and cand.special_type == 0:
					promote_piece = cand
					promote_pos = cand_pos
					break
		if promote_piece == null:
			continue
		# 定类型
		if promote_pos == moved_pos and from_player_move:
			if last_direction.x != 0:
				promote_piece.set_special(1)
			else:
				promote_piece.set_special(2)
		else:
			if run.horizontal:
				promote_piece.set_special(1)
			else:
				promote_piece.set_special(2)
		# 被晋升的棋子不销毁，从匹配列表里移除
		matched_pieces.erase(promote_pos)

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
		store_info(first_piece,other_piece,Vector2(column,row),direction)
		state=wait 
		all_pieces[column][row]=other_piece;
		all_pieces[column+direction.x][row+direction.y]=first_piece;
		first_piece.move(grid_to_pixel(column+direction.x,row+direction.y));
		other_piece.move(grid_to_pixel(column,row));
		if !move_check:
			find_matches(true)
			# 玩家移动后必然触发一次销毁判定（有匹配则消除，无匹配则换回）
			get_parent().get_node("destroy_timer").start()

func store_info(first_piece,other_piece,place,direction):
	piece_one=first_piece
	piece_two=other_piece
	last_place=place
	last_direction=direction
	pass
	

func swap_back():
	print("no match")
	if piece_one!=null && piece_two!=null:
		swap_pieces(last_place.x,last_place.y,last_direction)
	state=move
	move_check=false
	pass

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


func destroy_matched():
	var was_matched=false
	# 收集所有被标记（matched）的棋子
	var destroy_list = []
	for i in range(width):
		for j in range(hight):
			if all_pieces[i][j] != null and all_pieces[i][j].matched:
				destroy_list.append(Vector2(i, j))
	was_matched = destroy_list.size() > 0

	# 特殊棋子触发清行/清列（无视匹配），并连锁扩散
	var queue = destroy_list.duplicate()
	while queue.size() > 0:
		var pos = queue.pop_front()
		var piece = all_pieces[pos.x][pos.y]
		if piece == null:
			continue
		if piece.special_type == 1:  # 清行：整行全部消除
			for x in range(width):
				var p = Vector2(x, pos.y)
				if not destroy_list.has(p):
					destroy_list.append(p)
					queue.append(p)
		elif piece.special_type == 2:  # 清列：整列全部消除
			for y in range(hight):
				var p = Vector2(pos.x, y)
				if not destroy_list.has(p):
					destroy_list.append(p)
					queue.append(p)

	# 执行销毁，并统计各颜色销毁的颗数
	var color_counts := {}
	for pos in destroy_list:
		var piece = all_pieces[pos.x][pos.y]
		if piece != null:
			color_counts[piece.color] = color_counts.get(piece.color, 0) + 1
			piece.queue_free()
			all_pieces[pos.x][pos.y] = null

	# 计分：本轮回销毁的棋子数（含特殊棋子清行/列波及的）乘单颗分
	score += destroy_list.size() * score_per_piece
	_update_score_label()

	# 通知战斗系统：boss 掉血、对应英雄加能量（含级联）
	pieces_destroyed.emit(color_counts)

	move_check=true
	# state = move 移到级联全部结束后再设置
	if was_matched:
		get_parent().get_node("collapse_timer").start()
	else:
		swap_back()
					
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
	pass
						
	

func _on_destroy_timer_timeout() -> void:
	destroy_matched()


func _on_collapse_timer_timeout() -> void:
	collapse_columns()
	await get_tree().create_timer(0.3).timeout      # 等 collapse 动画播完再 refill
	refill_columns()
	await get_tree().create_timer(0.3).timeout      # 等 refill 动画播完再检测
	var matches = find_matches(false)   # 级联匹配同样能晋升特殊棋子
	if matches.size() > 0:
		get_parent().get_node("destroy_timer").start()   # 有级联匹配，继续销毁循环
	else:
		state = move   # 全部结束后才恢复玩家操作
		move_check = false   # 复位，让下一次移动正常判定

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

func _update_score_label():
	var label = get_parent().get_node_or_null("ScoreLabel")
	if label != null:
		label.text = str(score)

# 战斗系统判定结束后调用：锁定玩家输入
func lock_input():
	game_over = true
	state = wait
