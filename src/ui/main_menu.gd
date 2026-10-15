class_name MainMenu
extends Control
## 大厅（对齐官方横屏录屏观感）：薰衣草紫底 + 左侧模式栏 + 竖渐变房卡(小鸡吉祥物) + 快速开始

signal enter_room_requested(room: GameRules.RoomConfig)

var beans_label: Label
var stats_label: Label
var refill_dialog: BeanRefillDialog
var rules_dialog: Panel
var _guide: Coach.Guide = null

class ChickView extends Control:
	var hold_coin: bool = true
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.36
		# 身体
		draw_circle(c + Vector2(0, r * 0.25), r, Color(1.0, 0.85, 0.25))
		draw_circle(c + Vector2(0, r * 0.45), r * 0.62, Color(1.0, 0.95, 0.75))
		# 头
		draw_circle(c + Vector2(0, -r * 0.55), r * 0.62, Color(1.0, 0.87, 0.3))
		# 眼睛
		draw_circle(c + Vector2(-r * 0.22, -r * 0.65), r * 0.09, Color(0.15, 0.1, 0.05))
		draw_circle(c + Vector2(r * 0.22, -r * 0.65), r * 0.09, Color(0.15, 0.1, 0.05))
		# 嘴
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-r * 0.14, -r * 0.42), c + Vector2(r * 0.14, -r * 0.42), c + Vector2(0, -r * 0.22)
		]), Color(0.95, 0.55, 0.1))
		# 翅膀
		draw_circle(c + Vector2(-r * 0.85, r * 0.15), r * 0.3, Color(0.98, 0.78, 0.2))
		draw_circle(c + Vector2(r * 0.85, r * 0.15), r * 0.3, Color(0.98, 0.78, 0.2))
		# 腮红
		draw_circle(c + Vector2(-r * 0.42, -r * 0.4), r * 0.1, Color(1.0, 0.55, 0.45, 0.7))
		draw_circle(c + Vector2(r * 0.42, -r * 0.4), r * 0.1, Color(1.0, 0.55, 0.45, 0.7))
		if hold_coin:
			draw_circle(c + Vector2(r * 0.95, r * 0.5), r * 0.26, Color(1.0, 0.78, 0.15))
			draw_arc(c + Vector2(r * 0.95, r * 0.5), r * 0.26, 0, TAU, 14, Color(0.7, 0.48, 0.05), 1.5)

func _ready() -> void:
	size = Vector2(1280, 720)
	_setup_ui()
	_update_player_info()

func _draw() -> void:
	# 薰衣草紫渐变底
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)])
	var cols := PackedColorArray([
		Color(0.74, 0.72, 0.90), Color(0.74, 0.72, 0.90),
		Color(0.60, 0.58, 0.82), Color(0.60, 0.58, 0.82)
	])
	draw_polygon(pts, cols)
	# 柔光斑
	draw_circle(Vector2(240, 140), 180, Color(1, 1, 1, 0.10))
	draw_circle(Vector2(1080, 560), 220, Color(1, 1, 1, 0.08))
	draw_circle(Vector2(700, 660), 160, Color(0.95, 0.85, 1.0, 0.10))

func _setup_ui() -> void:
	# 顶栏：返回 + 标题
	var back = Label.new()
	back.text = "‹"
	back.position = Vector2(24, 14)
	back.add_theme_font_size_override("font_size", 34)
	back.add_theme_color_override("font_color", Color.WHITE)
	add_child(back)

	var title = Label.new()
	title.text = "百变八雀 · 点字成金"
	title.position = Vector2(48, 22)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(0.35, 0.3, 0.55, 0.8))
	title.add_theme_constant_override("outline_size", 6)
	add_child(title)

	# 顶栏右：欢乐豆 chip
	var chip = Panel.new()
	chip.size = Vector2(230, 40)
	chip.position = Vector2(880, 16)
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(1, 1, 1, 0.85)
	cs.corner_radius_top_left = 20
	cs.corner_radius_top_right = 20
	cs.corner_radius_bottom_left = 20
	cs.corner_radius_bottom_right = 20
	chip.add_theme_stylebox_override("panel", cs)
	add_child(chip)
	beans_label = Label.new()
	beans_label.size = Vector2(230, 40)
	beans_label.text = "🪙 1,000,000"
	beans_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	beans_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	beans_label.add_theme_font_size_override("font_size", 16)
	beans_label.add_theme_color_override("font_color", Color(0.85, 0.55, 0.05))
	chip.add_child(beans_label)

	var btn_refill = Button.new()
	btn_refill.text = "🪙 补豆"
	btn_refill.size = Vector2(90, 40)
	btn_refill.position = Vector2(1130, 16)
	var rs = StyleBoxFlat.new()
	rs.bg_color = Color(0.98, 0.72, 0.15)
	rs.corner_radius_top_left = 20
	rs.corner_radius_top_right = 20
	rs.corner_radius_bottom_left = 20
	rs.corner_radius_bottom_right = 20
	btn_refill.add_theme_stylebox_override("normal", rs)
	btn_refill.add_theme_color_override("font_color", Color.WHITE)
	btn_refill.pressed.connect(func(): refill_dialog.open())
	add_child(btn_refill)

	# 左侧模式栏
	var side = Panel.new()
	side.size = Vector2(150, 420)
	side.position = Vector2(0, 120)
	var ss = StyleBoxFlat.new()
	ss.bg_color = Color(0.32, 0.28, 0.52, 0.55)
	ss.corner_radius_top_right = 16
	ss.corner_radius_bottom_right = 16
	side.add_theme_stylebox_override("panel", ss)
	add_child(side)
	var modes = ["百变八雀\n点字成金", "血流麻将", "血流八雀牌", "七连牌"]
	for i in range(modes.size()):
		var ml = Label.new()
		ml.text = modes[i]
		ml.size = Vector2(140, 64)
		ml.position = Vector2(10, 18 + i * 88)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ml.add_theme_font_size_override("font_size", 17 if i == 0 else 15)
		if i == 0:
			ml.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			var bar = ColorRect.new()
			bar.color = Color(1.0, 0.85, 0.3)
			bar.size = Vector2(5, 56)
			bar.position = Vector2(0, 22 + i * 88)
			side.add_child(bar)
		else:
			ml.add_theme_color_override("font_color", Color(0.92, 0.90, 1.0, 0.85))
		side.add_child(ml)

	# 房卡（竖渐变 + 小鸡）
	var room_keys = ["beginner", "normal", "advanced", "top"]
	var grads = [
		[Color(0.55, 0.88, 0.62), Color(0.30, 0.72, 0.42)],
		[Color(0.72, 0.68, 0.95), Color(0.50, 0.45, 0.85)],
		[Color(1.0, 0.80, 0.45), Color(0.95, 0.55, 0.20)],
		[Color(1.0, 0.62, 0.62), Color(0.90, 0.35, 0.40)]
	]
	for i in range(room_keys.size()):
		var r = GameRules.get_room(room_keys[i])
		add_child(_create_room_card(r, Vector2(190 + i * 268, 110), grads[i]))

	# 快速开始
	var btn_quick = Button.new()
	btn_quick.text = "快速开始\n低底分 · 高底分"
	btn_quick.size = Vector2(180, 56)
	btn_quick.position = Vector2(1060, 620)
	var qs = StyleBoxFlat.new()
	qs.bg_color = Color(0.98, 0.62, 0.10)
	qs.corner_radius_top_left = 28
	qs.corner_radius_top_right = 28
	qs.corner_radius_bottom_left = 28
	qs.corner_radius_bottom_right = 28
	qs.border_width_bottom = 4
	qs.border_color = Color(0.80, 0.45, 0.05)
	btn_quick.add_theme_stylebox_override("normal", qs)
	btn_quick.add_theme_color_override("font_color", Color.WHITE)
	btn_quick.add_theme_font_size_override("font_size", 15)
	btn_quick.pressed.connect(func():
		var b = SaveManager.get_beans()
		var pick = GameRules.get_room("beginner")
		for k in ["top", "advanced", "normal"]:
			if b >= GameRules.get_room(k).min_beans:
				pick = GameRules.get_room(k)
				break
		_on_room_clicked(pick)
	)
	add_child(btn_quick)

	# 底部战绩（半透明白）
	var bottom_panel = Panel.new()
	bottom_panel.size = Vector2(620, 84)
	bottom_panel.position = Vector2(190, 600)
	var bp_style = StyleBoxFlat.new()
	bp_style.bg_color = Color(1, 1, 1, 0.75)
	bp_style.corner_radius_top_left = 12
	bp_style.corner_radius_top_right = 12
	bp_style.corner_radius_bottom_left = 12
	bp_style.corner_radius_bottom_right = 12
	bottom_panel.add_theme_stylebox_override("panel", bp_style)
	add_child(bottom_panel)

	stats_label = Label.new()
	stats_label.size = Vector2(300, 84)
	stats_label.position = Vector2(16, 0)
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.30, 0.28, 0.45))
	bottom_panel.add_child(stats_label)

	var btn_rules = Button.new()
	btn_rules.text = "📖 玩法说明"
	btn_rules.size = Vector2(130, 40)
	btn_rules.position = Vector2(474, 22)
	var rr = StyleBoxFlat.new()
	rr.bg_color = Color(0.45, 0.40, 0.75)
	rr.corner_radius_top_left = 20
	rr.corner_radius_top_right = 20
	rr.corner_radius_bottom_left = 20
	rr.corner_radius_bottom_right = 20
	btn_rules.add_theme_stylebox_override("normal", rr)
	btn_rules.add_theme_color_override("font_color", Color.WHITE)
	btn_rules.pressed.connect(_show_rules_dialog)
	bottom_panel.add_child(btn_rules)

	var build_lbl = Label.new()
	build_lbl.text = "构建 2026-09-14 23:20"
	build_lbl.size = Vector2(200, 20)
	build_lbl.position = Vector2(1064, 700)
	build_lbl.add_theme_font_size_override("font_size", 11)
	build_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	add_child(build_lbl)

	var btn_guide = Button.new()
	btn_guide.text = "📚 番型图鉴"
	btn_guide.size = Vector2(136, 40)
	btn_guide.position = Vector2(330, 22)
	var gs = StyleBoxFlat.new()
	gs.bg_color = Color(0.52, 0.40, 0.75)
	gs.corner_radius_top_left = 20
	gs.corner_radius_top_right = 20
	gs.corner_radius_bottom_left = 20
	gs.corner_radius_bottom_right = 20
	btn_guide.add_theme_stylebox_override("normal", gs)
	btn_guide.add_theme_color_override("font_color", Color.WHITE)
	btn_guide.pressed.connect(func():
		if _guide == null:
			_guide = Coach.Guide.new()
			add_child(_guide)
		else:
			_guide.visible = true
	)
	bottom_panel.add_child(btn_guide)

	# Modals
	refill_dialog = BeanRefillDialog.new()
	refill_dialog.beans_refilled.connect(func(nb): _update_player_info())
	add_child(refill_dialog)

	_setup_rules_dialog()

func _create_room_card(room_conf: GameRules.RoomConfig, pos: Vector2, grad: Array) -> Panel:
	var card = Panel.new()
	card.size = Vector2(248, 460)
	card.position = pos
	var style = StyleBoxFlat.new()
	style.bg_color = grad[1]
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.6)
	card.add_theme_stylebox_override("panel", style)

	# 渐变覆层
	var gl = ColorRect.new()
	gl.color = grad[0]
	gl.size = Vector2(248, 200)
	gl.position = Vector2(0, 0)
	gl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(gl)
	var fade = ColorRect.new()
	fade.color = Color(grad[1].r, grad[1].g, grad[1].b, 0.0)
	fade.size = Vector2(248, 120)
	fade.position = Vector2(0, 140)
	fade.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(fade)

	var r_name = Label.new()
	r_name.size = Vector2(248, 40)
	r_name.position = Vector2(0, 18)
	r_name.text = room_conf.name
	r_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_name.add_theme_font_size_override("font_size", 21)
	r_name.add_theme_color_override("font_color", Color.WHITE)
	r_name.add_theme_color_override("font_outline_color", Color(0.2, 0.2, 0.3, 0.6))
	r_name.add_theme_constant_override("outline_size", 5)
	card.add_child(r_name)

	var base_lbl = Label.new()
	base_lbl.size = Vector2(248, 30)
	base_lbl.position = Vector2(0, 62)
	base_lbl.text = "底分"
	base_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_lbl.add_theme_font_size_override("font_size", 14)
	base_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	card.add_child(base_lbl)

	var num_lbl = Label.new()
	num_lbl.size = Vector2(248, 52)
	num_lbl.position = Vector2(0, 88)
	num_lbl.text = str(room_conf.base_score)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.add_theme_font_size_override("font_size", 40)
	num_lbl.add_theme_color_override("font_color", Color.WHITE)
	num_lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.2, 0.3, 0.6))
	num_lbl.add_theme_constant_override("outline_size", 6)
	card.add_child(num_lbl)

	var chick = ChickView.new()
	chick.size = Vector2(120, 120)
	chick.position = Vector2(64, 190)
	chick.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(chick)

	var entry_lbl = Label.new()
	entry_lbl.size = Vector2(248, 26)
	entry_lbl.position = Vector2(0, 320)
	entry_lbl.text = "👤 " + _short_count(room_conf.min_beans) + "  🪙 " + room_conf.entry_label
	entry_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_lbl.add_theme_font_size_override("font_size", 12)
	entry_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	card.add_child(entry_lbl)

	var win_lbl = Label.new()
	win_lbl.size = Vector2(248, 24)
	win_lbl.position = Vector2(0, 348)
	var win_str = "单次结算不限" if room_conf.max_win >= 999999999 else ("单局封顶 " + _format_beans(room_conf.max_win))
	win_lbl.text = win_str
	win_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_lbl.add_theme_font_size_override("font_size", 12)
	win_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	card.add_child(win_lbl)

	var btn_enter = Button.new()
	btn_enter.text = "立即进入"
	btn_enter.size = Vector2(160, 44)
	btn_enter.position = Vector2(44, 392)
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(1, 1, 1, 0.92)
	bs.corner_radius_top_left = 22
	bs.corner_radius_top_right = 22
	bs.corner_radius_bottom_left = 22
	bs.corner_radius_bottom_right = 22
	btn_enter.add_theme_stylebox_override("normal", bs)
	btn_enter.add_theme_color_override("font_color", grad[1].darkened(0.25))
	btn_enter.add_theme_font_size_override("font_size", 16)
	btn_enter.pressed.connect(func(): _on_room_clicked(room_conf))
	card.add_child(btn_enter)

	return card

func _short_count(v: int) -> String:
	if v >= 10000:
		return str(int(v / 10000)) + "万+"
	return str(v) + "+"

func _on_room_clicked(room_conf: GameRules.RoomConfig) -> void:
	var cur_beans = SaveManager.get_beans()
	if cur_beans < room_conf.min_beans:
		refill_dialog.open()
		return
	emit_signal("enter_room_requested", room_conf)

func _update_player_info() -> void:
	var data = SaveManager.load_data()
	var b = int(data.get("beans", 200000))
	beans_label.text = "🪙 " + _format_beans(b)

	var played = int(data.get("games_played", 0))
	var wins = int(data.get("wins", 0))
	var hus = int(data.get("total_hus", 0))
	var win_rate = 0.0 if played == 0 else (float(wins) / float(played) * 100.0)
	var highest_win = int(data.get("highest_win_beans", 0))
	var highest_pat = str(data.get("highest_pattern", "无"))

	var s_text = "对局 " + str(played) + " · 胜 " + str(wins) + " (" + str(snapped(win_rate, 0.1)) + "%) · 胡 " + str(hus) + " 次\n最高单局 " + _format_beans(highest_win) + " 豆 · 最高番型 " + highest_pat
	stats_label.text = s_text

func _setup_rules_dialog() -> void:
	rules_dialog = Panel.new()
	rules_dialog.size = Vector2(680, 520)
	rules_dialog.position = Vector2((1280 - 680) * 0.5, (720 - 520) * 0.5)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.98, 1.0, 0.98)
	style.border_color = Color(0.65, 0.60, 0.85, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	rules_dialog.add_theme_stylebox_override("panel", style)
	rules_dialog.visible = false
	add_child(rules_dialog)

	var r_title = Label.new()
	r_title.text = "📖《百变八雀 · 点字成金》核心玩法说明"
	r_title.size = Vector2(680, 44)
	r_title.position = Vector2(0, 16)
	r_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_title.add_theme_font_size_override("font_size", 20)
	r_title.add_theme_color_override("font_color", Color(0.35, 0.30, 0.55))
	rules_dialog.add_child(r_title)

	var text = RichTextLabel.new()
	text.size = Vector2(620, 380)
	text.position = Vector2(30, 65)
	text.bbcode_enabled = true
	text.add_theme_color_override("default_color", Color(0.25, 0.25, 0.35))
	text.text = """[b]1. 牌库构成（共84张）[/b]
• 基础牌：6~A（9个点数 × 4花色 × 2副 = 72张）
• 天下为八：追加 4 张 8（全场 12 张 8）
• 癞子（🃏）：4 张万能牌，[color=#cc3333]持癞子不能胡平胡[/color]
• 机会牌（🎁）：4 张，打出后牌堆顶 4 选 1，其余按原序放回

[b]2. 对局流程与血流成河[/b]
• 起手 7 张，摸 1 打 1 保持 7 张；摸到第 8 张拆成合法牌型即胡。
• [color=#aa7700]血流成河[/color]：第一次胡牌手动操作，之后锁定自动胡牌，继续摸打直至牌堆摸空。

[b]3. 核心番型倍数[/b]
• [color=#aa7700]×100[/color]：独一无二(8张A)、君临天下(8张K)、十全十美(8张10)、八方来财(8张8)
• [color=#aa7700]×50[/color]：八方来贺(8张单组)
• [color=#bb6600]×32[/color]：顶峰相见(K*6+A对)、心心相连(J*6+Q对)、十拿九稳(10*6+9对)、六事兴旺(6*6+7对)
• [color=#cc5500]×16[/color]：比翼为邻(6+2相邻)、六朝金粉(6+2同色)
• [color=#0077aa]×8[/color]：六六大顺(6+2基础)、永恒相随(5+3相邻)、五谷丰登(5+3同色)
• [color=#009955]×4[/color]：二龙腾飞(4+4相邻)、四季发财(4+4同色)
• [color=#55aa00]×2[/color]：四季如春(4+4基础)
• [color=#777777]×1[/color]：平胡(3+3+2基础，无癞子)

[b]4. 特殊倍数与结算[/b]
• 自摸 ×3、地胡 ×16、海底捞月 ×4、硬气(无癞子) ×2
• 点字成金：最终倍数额外乘以手牌中金牌点数牌张数（癞子也计为金牌）"""
	rules_dialog.add_child(text)

	var btn_close = Button.new()
	btn_close.text = "我知道了"
	btn_close.size = Vector2(130, 38)
	btn_close.position = Vector2((680 - 130) * 0.5, 460)
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.55, 0.50, 0.82)
	cs.corner_radius_top_left = 19
	cs.corner_radius_top_right = 19
	cs.corner_radius_bottom_left = 19
	cs.corner_radius_bottom_right = 19
	btn_close.add_theme_stylebox_override("normal", cs)
	btn_close.add_theme_color_override("font_color", Color.WHITE)
	btn_close.pressed.connect(func(): rules_dialog.visible = false)
	rules_dialog.add_child(btn_close)

func _show_rules_dialog() -> void:
	rules_dialog.visible = true

func _format_beans(val: int) -> String:
	var abs_val = abs(val)
	var s = str(abs_val)
	var res = ""
	var cnt = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "," + res
	return ("-" if val < 0 else "") + res
