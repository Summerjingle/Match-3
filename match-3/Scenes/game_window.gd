extends Node2D

# 战斗系统：Boss 血量 + 底部英雄的能量/血量。
# grid.gd 只负责棋盘，销毁棋子后发 pieces_destroyed 信号到这里统一处理。
# 数值来自 Match3Config 导出的 res://Config/*.json（GlobaConfigl / EnemyAbout / HeroAbout）。

const HERO_COLORS := ["yellow", "pink", "orange", "green", "blue"]

#Boss
@export var boss_max_hp: int = 60
var boss_hp: int = 0

# 每颗棋子造成的伤害，来自 GlobaConfigl.MatchDmg
var match_dmg: int = 1

#英雄
@export var energy_per_piece: int = 1
# 满能量点头像放技能的单次伤害（可调）
@export var energy_attack_dmg: int = 100
var hero_cards: Array[Node] = []
var hero_charge_rate: Array[int] = []

var game_over: bool = false


func _ready():
	var boss = get_node_or_null("boss")
	for color in HERO_COLORS:
		var card = get_node_or_null("HeroCard_" + color)
		if card != null:
			hero_cards.append(card)
			card.attack_target = boss  # 满能量点头像时跳过去打 boss
			card.attacked.connect(_on_hero_attack)
	_load_config()
	boss_hp = boss_max_hp
	_update_all_bars()


# 读取配置：boss 血/贴图、每颗伤害、英雄血量/充能/头像
func _load_config():
	var enemy = _load_json("res://Config/EnemyAbout.json")
	if enemy.has("1"):
		boss_max_hp = int(enemy["1"].get("EnemyHp", boss_max_hp))
		var eimg = str(enemy["1"].get("EnemyImg", ""))
		if eimg != "":
			var boss = get_node_or_null("boss")
			if boss != null:
				var tex = load(_img_path(eimg))
				if tex is Texture2D:
					boss.texture = tex
	var glob = _load_json("res://Config/GlobaConfigl.json")
	if glob.has("1"):
		var v = str(glob["1"].get("Value", ""))
		if v != "":
			match_dmg = int(v)
	var heros = _load_json("res://Config/HeroAbout.json")
	for i in range(hero_cards.size()):
		var rec = heros.get(str(i + 1), {})
		var hp = int(rec.get("HeroHp", 100))
		var charge = int(rec.get("HeroChargeValue", 100))
		hero_cards[i].setup(hp, charge)
		hero_charge_rate.append(int(rec.get("HeroChargeRate", 1)))
		var himg = str(rec.get("HeroImg", ""))
		if himg != "":
			hero_cards[i].set_portrait(_img_path(himg))


# 配置里的相对路径（反斜杠）→ res:// 路径
func _img_path(cfg_path: String) -> String:
	return "res://" + cfg_path.replace("\\", "/")


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text = FileAccess.get_file_as_string(path)
	if text == "":
		return {}
	var data = JSON.parse_string(text)
	return data if data is Dictionary else {}


# grid 每销毁一轮棋子后触发。counts = {颜色: 颗数}，含级联。
func _on_pieces_destroyed(counts: Dictionary):
	if game_over:
		return
	for color in counts:
		var n: int = counts[color]
		# Boss 掉血：每颗扣 match_dmg
		boss_hp = max(boss_hp - n * match_dmg, 0)
		# 英雄能量：对应颜色 +n × energy_per_piece × HeroChargeRate
		var ci = HERO_COLORS.find(color)
		if ci >= 0:
			var card = hero_cards[ci]
			card.set_energy(card.energy + n * energy_per_piece * hero_charge_rate[ci])
	_update_all_bars()
	if boss_hp <= 0:
		_on_boss_defeated()


func _update_all_bars():
	var bbar = get_node_or_null("BossHPBar")
	if bbar != null:
		bbar.max_value = boss_max_hp
		bbar.value = boss_hp
	# 英雄血/能量条由 hero_card 自己刷新，这里无需处理


# 英雄满能量点头像放技能命中：扣 boss 血 + 受击闪红
func _on_hero_attack():
	if game_over:
		return
	boss_hp = max(boss_hp - energy_attack_dmg, 0)
	_update_all_bars()
	var boss = get_node_or_null("boss")
	if boss != null:
		boss.modulate = Color(1.2, 0.3, 0.3)
		create_tween().tween_property(boss, "modulate", Color.WHITE, 0.2)
	if boss_hp <= 0:
		_on_boss_defeated()


func _on_boss_defeated():
	game_over = true
	var grid = get_node_or_null("grid")
	if grid != null:
		grid.lock_input()
	print("BOSS 已击败！")
	var label = get_node_or_null("ResultLabel")
	if label != null:
		label.text = "BOSS 击败！"
