class_name PlayerSeat
extends Control
## 座位视图（对齐官方横屏录屏）：圆形头像+装饰环、豆量、扇形牌背、
## 行动位金色光柱 + 闹钟倒计时徽章 + "选牌中…"气泡

enum Orient { BOTTOM, RIGHT, TOP, LEFT }

var seat_idx: int = 0
var player_state: PlayerState = null
var orient: int = Orient.BOTTOM

var name_label: Label
var beans_label: Label
var status_badge: Label
var float_container: Control

var is_active_turn: bool = false
var ai_card_count: int = 0
var countdown: int = -1 # -1 隐藏闹钟
var _pulse_t: float = 0.0

class FloatRibbon extends Control:
	var delta := 0
	var text_str := ""
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var col := Color(0.93, 0.62, 0.08) if delta >= 0 else Color(0.80, 0.16, 0.12)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, 0), Vector2(w, 0), Vector2(w - 10, h * 0.5), Vector2(w, h), Vector2(0, h), Vector2(10, h * 0.5)
		]), col)
		draw_circle(Vector2(22, h * 0.5), 9.0, Color(1.0, 0.85, 0.2))
		draw_arc(Vector2(22, h * 0.5), 9.0, 0, TAU, 16, Color(0.65, 0.45, 0.05), 1.5)
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(34, h * 0.5 + 7), text_str, HORIZONTAL_ALIGNMENT_CENTER, int(w - 40), 18, 2, Color(0.25, 0.1, 0.0))
		draw_string(font, Vector2(34, h * 0.5 + 7), text_str, HORIZONTAL_ALIGNMENT_CENTER, int(w - 40), 18, Color.WHITE)
const AVATAR_R := 32.0

func _init(p_seat: int = 0) -> void:
	seat_idx = p_seat
	orient = p_seat
	custom_minimum_size = Vector2(240, 170)
	size = custom_minimum_size

func _ready() -> void:
	_setup_ui()

func _process(delta: float) -> void:
	_pulse_t += delta
	if is_active_turn or ai_card_count > 0:
		queue_redraw()

func _setup_ui() -> void:
	# 名字
	name_label = Label.new()
	name_label.size = Vector2(150, 22)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	name_label.add_theme_constant_override("outline_size", 4)
	add_child(name_label)

	# 豆量（金币前缀用绘制实现，这里仅数字）
	beans_label = Label.new()
	beans_label.size = Vector2(150, 22)
	beans_label.add_theme_font_size_override("font_size", 14)
	beans_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	beans_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	beans_label.add_theme_constant_override("outline_size", 4)
	add_child(beans_label)

	# 状态徽标（已胡牌/破产/托管）
	status_badge = Label.new()
	status_badge.size = Vector2(160, 20)
	status_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_badge.add_theme_font_size_override("font_size", 12)
	status_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	status_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	status_badge.add_theme_constant_override("outline_size", 4)
	add_child(status_badge)

	# 浮动豆容器
	float_container = Control.new()
	float_container.size = Vector2(240, 60)
	add_child(float_container)

	_apply_layout()

func _apply_layout() -> void:
	match orient:
		Orient.BOTTOM:
			name_label.position = Vector2(74, 8)
			beans_label.position = Vector2(74, 32)
			status_badge.position = Vector2(40, 56)
			float_container.position = Vector2(0, -50)
		Orient.TOP:
			name_label.position = Vector2(74, 6)
			beans_label.position = Vector2(74, 30)
			status_badge.position = Vector2(40, 54)
			float_container.position = Vector2(0, -40)
		Orient.LEFT:
			name_label.position = Vector2(0, 72)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			beans_label.position = Vector2(0, 94)
			beans_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status_badge.position = Vector2(40, 116)
			float_container.position = Vector2(0, -30)
		Orient.RIGHT:
			name_label.position = Vector2(80, 72)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			beans_label.position = Vector2(80, 94)
			beans_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status_badge.position = Vector2(80, 116)
			float_container.position = Vector2(0, -30)

func _avatar_center() -> Vector2:
	match orient:
		Orient.BOTTOM: return Vector2(38, 34)
		Orient.TOP: return Vector2(38, 34)
		Orient.LEFT: return Vector2(38, 38)
		_: return Vector2(118, 38)

# ---------- 对外接口（保持旧 API） ----------

func set_player(player: PlayerState) -> void:
	player_state = player
	name_label.text = player.name
	update_beans()
	update_status()

func update_beans() -> void:
	if player_state != null:
		beans_label.text = _format_beans(player_state.beans)

func set_active_turn(active: bool) -> void:
	if player_state != null and player_state.is_bankrupt:
		is_active_turn = false
		countdown = -1
		status_badge.text = "【 破产认输 】"
		status_badge.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		queue_redraw()
		return
	is_active_turn = active
	if not active:
		countdown = -1
		update_status()
	else:
		status_badge.text = ""
	queue_redraw()

func set_countdown(sec: int) -> void:
	if countdown != sec:
		countdown = sec
		queue_redraw()

func update_status() -> void:
	if player_state == null:
		return
	if player_state.is_bankrupt:
		status_badge.text = "【 破产认输 】"
		status_badge.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		return
	if player_state.hu_count > 0:
		status_badge.text = "已胡牌 x" + str(player_state.hu_count)
		status_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	elif player_state.auto_hu:
		status_badge.text = "自动托管中"
		status_badge.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	else:
		status_badge.text = ""

func set_bankrupt(bankrupt: bool) -> void:
	if bankrupt:
		status_badge.text = "【 破产认输 】"
		status_badge.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		is_active_turn = false
		countdown = -1
		modulate = Color(0.65, 0.65, 0.65, 0.85)
		if seat_idx != 0:
			update_ai_card_count(0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		update_status()
	queue_redraw()

func show_floating_beans(delta: int) -> void:
	var rib = FloatRibbon.new()
	rib.delta = delta
	rib.text_str = ("+" if delta >= 0 else "-") + _format_beans(delta)
	rib.size = Vector2(150, 34)
	rib.position = Vector2(45, 20)
	float_container.add_child(rib)
	var tween = create_tween()
	tween.tween_property(rib, "position:y", -40.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(rib, "modulate:a", 0.0, 1.8)
	tween.tween_callback(rib.queue_free)

func update_ai_card_count(count: int) -> void:
	ai_card_count = count
	queue_redraw()

# ---------- 绘制 ----------

func _draw() -> void:
	var ac := _avatar_center()

	# 行动位金色光柱
	if is_active_turn:
		_draw_beam(ac)

	# 扇形牌背（AI 座位）
	if seat_idx != 0 and ai_card_count > 0:
		_draw_fan(ac)

	# 头像
	_draw_avatar(ac)

	# 闹钟倒计时徽章
	if is_active_turn and countdown >= 0:
		_draw_alarm(_alarm_pos(ac))

	# 选牌中气泡
	if is_active_turn and seat_idx != 0:
		_draw_thinking_bubble(ac)

func _draw_beam(ac: Vector2) -> void:
	var w := 46.0
	var top := ac.y - AVATAR_R - 26.0
	var bot := ac.y + AVATAR_R + 40.0
	var pts := PackedVector2Array([
		Vector2(ac.x - w * 0.32, top), Vector2(ac.x + w * 0.32, top),
		Vector2(ac.x + w * 0.5, bot), Vector2(ac.x - w * 0.5, bot)
	])
	var cols := PackedColorArray([
		Color(1.0, 0.85, 0.3, 0.0), Color(1.0, 0.85, 0.3, 0.0),
		Color(1.0, 0.8, 0.25, 0.35), Color(1.0, 0.8, 0.25, 0.35)
	])
	draw_polygon(pts, cols)

func _draw_fan(ac: Vector2) -> void:
	var n := clampi(ai_card_count, 1, 8)
	var cw := 34.0
	var ch := 50.0
	match orient:
		Orient.TOP:
			# 头像左侧水平弧（官方横屏顶家牌背在左）
			var cx := ac.x - 96.0
			for i in range(n):
				var t := float(i) / maxf(float(n - 1), 1.0) - 0.5
				var ang := -t * 0.9
				var pos := Vector2(cx + t * 96.0, ac.y - 6.0 + absf(t) * 26.0)
				_draw_mini_back(pos, ang, cw, ch)
		Orient.LEFT:
			var cy := ac.y + 4.0
			for i in range(n):
				var t := float(i) / maxf(float(n - 1), 1.0) - 0.5
				var ang := -t * 0.9 + PI * 0.5
				var pos := Vector2(ac.x + 62.0 + absf(t) * 26.0, cy + t * 96.0)
				_draw_mini_back(pos, ang, cw, ch)
		Orient.RIGHT:
			var cy := ac.y + 4.0
			for i in range(n):
				var t := float(i) / maxf(float(n - 1), 1.0) - 0.5
				var ang := t * 0.9 + PI * 0.5
				var pos := Vector2(ac.x - 62.0 - absf(t) * 26.0, cy + t * 96.0)
				_draw_mini_back(pos, ang, cw, ch)

func _draw_mini_back(center: Vector2, ang: float, cw: float, ch: float) -> void:
	draw_set_transform(center, ang, Vector2.ONE)
	var r := Rect2(-cw * 0.5, -ch * 0.5, cw, ch)
	var pts := PackedVector2Array()
	var rad := 4.0
	var seg := 3
	var c_tl := Vector2(r.position.x + rad, r.position.y + rad)
	var c_tr := Vector2(r.end.x - rad, r.position.y + rad)
	var c_br := Vector2(r.end.x - rad, r.end.y - rad)
	var c_bl := Vector2(r.position.x + rad, r.end.y - rad)
	for i in range(seg + 1):
		var a := PI + (PI * 0.5) * float(i) / float(seg)
		pts.append(c_tl + Vector2(cos(a), sin(a)) * rad)
	for i in range(seg + 1):
		var a := PI * 1.5 + (PI * 0.5) * float(i) / float(seg)
		pts.append(c_tr + Vector2(cos(a), sin(a)) * rad)
	for i in range(seg + 1):
		var a := (PI * 0.5) * float(i) / float(seg)
		pts.append(c_br + Vector2(cos(a), sin(a)) * rad)
	for i in range(seg + 1):
		var a := PI * 0.5 + (PI * 0.5) * float(i) / float(seg)
		pts.append(c_bl + Vector2(cos(a), sin(a)) * rad)
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf((p.y - r.position.y) / ch, 0.0, 1.0)
		cols.append(Color(0.32, 0.44, 0.76).lerp(Color(0.20, 0.30, 0.62), t))
	draw_polygon(pts, cols)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.62, 0.72, 0.95, 0.8), 1.0, true)
	draw_circle(Vector2.ZERO, 6.0, Color(0.62, 0.72, 0.95, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_avatar(ac: Vector2) -> void:
	var bankrupt := player_state != null and player_state.is_bankrupt
	# 外环
	var ring_col := Color(1.0, 0.85, 0.3) if is_active_turn else Color(0.85, 0.9, 1.0, 0.9)
	draw_circle(ac, AVATAR_R + 4.0, ring_col)
	draw_circle(ac, AVATAR_R + 1.5, Color(0.15, 0.35, 0.55))
	# 头像底
	draw_circle(ac, AVATAR_R, _get_avatar_color(seat_idx))
	# 头像字符
	var font := ThemeDB.fallback_font
	var txt := _get_avatar_text(seat_idx)
	draw_string_outline(font, ac + Vector2(-20, 10), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 26, 2, Color(0, 0, 0, 0.5))
	draw_string(font, ac + Vector2(-20, 10), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 26, Color.WHITE)
	if bankrupt:
		draw_arc(ac, AVATAR_R + 2.0, 0, TAU, 24, Color(1.0, 0.3, 0.3, 0.9), 3.0)

func _alarm_pos(ac: Vector2) -> Vector2:
	match orient:
		Orient.BOTTOM: return ac + Vector2(120, -6)
		Orient.TOP: return ac + Vector2(86, 44)
		Orient.LEFT: return ac + Vector2(118, 8)
		_: return ac + Vector2(-118, 8)

func _draw_alarm(c: Vector2) -> void:
	var pulse := 1.0 + sin(_pulse_t * 6.0) * 0.04
	var r := 24.0 * pulse
	# 铃铛
	draw_circle(c + Vector2(-r * 0.62, -r * 0.78), r * 0.30, Color(0.85, 0.87, 0.92))
	draw_circle(c + Vector2(r * 0.62, -r * 0.78), r * 0.30, Color(0.85, 0.87, 0.92))
	draw_rect(Rect2(c.x - r * 0.12, c.y - r * 1.18, r * 0.24, r * 0.22), Color(0.85, 0.87, 0.92), true)
	# 钟体
	draw_circle(c, r + 2.5, Color(0.55, 0.30, 0.02))
	draw_circle(c, r, Color(0.98, 0.72, 0.12))
	draw_circle(c, r * 0.78, Color(0.99, 0.82, 0.30))
	# 数字
	var font := ThemeDB.fallback_font
	var txt := str(countdown)
	draw_string_outline(font, c + Vector2(-20, 10), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 26, 2, Color(0.55, 0.25, 0.0))
	draw_string(font, c + Vector2(-20, 10), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 26, Color.WHITE)

func _draw_thinking_bubble(ac: Vector2) -> void:
	var pos := ac + Vector2(-42, AVATAR_R + 12)
	if orient == Orient.TOP:
		pos = ac + Vector2(44, 100)
	var r := Rect2(pos, Vector2(84, 24))
	var pts := PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)
	])
	draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	var font := ThemeDB.fallback_font
	draw_string(font, pos + Vector2(0, 17), "选牌中…", HORIZONTAL_ALIGNMENT_CENTER, 84, 13, Color(1.0, 0.92, 0.6))

# ---------- 工具 ----------

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

func _get_avatar_color(seat: int) -> Color:
	match seat:
		0: return Color(0.25, 0.55, 0.85)
		1: return Color(0.85, 0.35, 0.30)
		2: return Color(0.30, 0.70, 0.45)
		3: return Color(0.90, 0.62, 0.15)
		_: return Color(0.5, 0.5, 0.5)

func _get_avatar_text(seat: int) -> String:
	match seat:
		0: return "我"
		1: return "龙"
		2: return "孔"
		3: return "财"
		_: return "客"
