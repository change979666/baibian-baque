class_name CardView
extends Control
## 拟真扑克牌视图（对齐《欢乐斗地主·百变八雀》官方横屏录屏观感）
## 牌面：白底圆角 + 左上大号点数/花色 + 右上分数徽标 + 中央大花色
## 金牌：香槟金渐变底 + 金边 + 右下金币徽标；癞子/机会牌专属卡面；牌背为宝蓝底纹

signal card_clicked(card_view: CardView)

var card: Card = null
var is_face_down: bool = false
var is_selected: bool = false
var is_hovered: bool = false
var is_gold: bool = false
var is_interactive: bool = true
var enable_hover: bool = true
var show_points: bool = true

var base_y: float = 0.0

var action_badge: String = "" # "吃", "胡 x2" 等
var card_points: int = 0

const COL_RED := Color(0.82, 0.11, 0.13)
const COL_BLACK := Color(0.13, 0.13, 0.15)
const COL_GOLD := Color(0.93, 0.72, 0.16)

func _init(p_card: Card = null, p_face_down: bool = false, p_size: Vector2 = Vector2(92, 132)) -> void:
	card = p_card
	is_face_down = p_face_down
	custom_minimum_size = p_size
	size = p_size
	_update_points()

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func set_card_data(p_card: Card, p_is_gold: bool = false) -> void:
	card = p_card
	is_gold = p_is_gold
	_update_points()
	queue_redraw()

func set_action_badge(badge: String) -> void:
	action_badge = badge
	queue_redraw()

func _update_points() -> void:
	if card == null:
		card_points = 0
		return
	card_points = card.get_point_value()

func set_selected(val: bool) -> void:
	is_selected = val
	position.y = base_y - (26.0 if is_selected else (8.0 if is_hovered else 0.0))
	queue_redraw()

func flip_to(new_face_down: bool, duration: float = 0.24) -> Tween:
	pivot_offset = size * 0.5
	var tween = create_tween()
	tween.tween_property(self, "scale:x", 0.0, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		is_face_down = new_face_down
		queue_redraw()
	)
	tween.tween_property(self, "scale:x", 1.0, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween

func _on_mouse_entered() -> void:
	if not is_interactive or not enable_hover or is_face_down:
		return
	is_hovered = true
	position.y = base_y - (26.0 if is_selected else 8.0)
	queue_redraw()

func _on_mouse_exited() -> void:
	if not is_interactive or not enable_hover or is_face_down:
		return
	is_hovered = false
	position.y = base_y - (26.0 if is_selected else 0.0)
	queue_redraw()

func _on_gui_input(event: InputEvent) -> void:
	if not is_interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if SoundManager.instance:
			SoundManager.instance.play_select()
		emit_signal("card_clicked", self)

# ---------- 绘制工具 ----------

func _rounded_pts(r: Rect2, rad: float, seg: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
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
	return pts

func _fill_rounded(r: Rect2, rad: float, col_top: Color, col_bot: Color) -> void:
	var pts := _rounded_pts(r, rad)
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf((p.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)
		cols.append(col_top.lerp(col_bot, t))
	draw_polygon(pts, cols)

func _stroke_rounded(r: Rect2, rad: float, col: Color, width: float) -> void:
	var pts := _rounded_pts(r, rad)
	pts.append(pts[0])
	draw_polyline(pts, col, width, true)

func _text(pos: Vector2, txt: String, fs: int, col: Color, width: int = -1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = false) -> void:
	var font := ThemeDB.fallback_font
	if bold:
		draw_string_outline(font, pos, txt, align, width, fs, 1, col)
	draw_string(font, pos, txt, align, width, fs, col)

func _badge_rounded(r: Rect2, txt: String, bg: Color, fg: Color, fs: int = 11) -> void:
	_fill_rounded(r, r.size.y * 0.35, bg, bg.darkened(0.12))
	_text(Vector2(r.position.x, r.position.y + r.size.y - 4), txt, fs, fg, int(r.size.x), HORIZONTAL_ALIGNMENT_CENTER, true)

# ---------- 主绘制 ----------

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var rad := size.x * 0.09

	# 投影
	var sh := Rect2(Vector2(2, 3), size)
	_fill_rounded(sh, rad, Color(0, 0, 0, 0.28), Color(0, 0, 0, 0.28))

	if is_face_down or card == null:
		_draw_back(rect, rad)
		return

	if card.is_wild():
		_draw_wild(rect, rad)
		_draw_action_badge()
		return

	if card.is_opportunity():
		_draw_opportunity(rect, rad)
		_draw_action_badge()
		return

	_draw_face(rect, rad)
	_draw_action_badge()

func _draw_back(rect: Rect2, rad: float) -> void:
	# 官方宝蓝牌背：深蓝底 + 浅蓝内框 + 中心圆形纹章
	_fill_rounded(rect, rad, Color(0.30, 0.42, 0.75), Color(0.20, 0.30, 0.62))
	_stroke_rounded(rect.grow(-1.0), rad - 1.0, Color(0.55, 0.66, 0.90, 0.9), 1.5)
	_stroke_rounded(rect.grow(-4.0), rad - 2.0, Color(0.62, 0.72, 0.95, 0.55), 1.0)
	var c := rect.size * 0.5
	draw_circle(c, rect.size.x * 0.24, Color(0.62, 0.72, 0.95, 0.35))
	draw_arc(c, rect.size.x * 0.24, 0, TAU, 24, Color(0.75, 0.83, 1.0, 0.8), 1.5)
	var d := rect.size.x * 0.12
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y - d), Vector2(c.x + d, c.y), Vector2(c.x, c.y + d), Vector2(c.x - d, c.y)
	]), Color(0.80, 0.87, 1.0, 0.85))
	if is_selected:
		_stroke_rounded(rect.grow(-0.5), rad, Color(1.0, 0.85, 0.2), 3.0)

func _draw_face(rect: Rect2, rad: float) -> void:
	var top := Color(1.0, 1.0, 1.0)
	var bot := Color(0.90, 0.90, 0.92)
	if is_gold:
		top = Color(1.0, 0.97, 0.80)
		bot = Color(0.94, 0.87, 0.58)
	_fill_rounded(rect, rad, top, bot)

	# 边框
	if is_selected:
		_stroke_rounded(rect.grow(-1.0), rad, Color(1.0, 0.8, 0.1), 3.5)
	elif is_gold:
		_stroke_rounded(rect.grow(-1.0), rad, Color(0.88, 0.68, 0.12), 2.5)
	else:
		_stroke_rounded(rect.grow(-0.8), rad, Color(0.72, 0.72, 0.76), 1.5)

	var text_color := COL_RED if card.get_suit_color() == Color.RED or _is_red_suit() else COL_BLACK
	var rank_str := card.get_rank_str()
	var suit_sym := card.get_suit_symbol()

	# 左上：大号点数 + 花色
	_text(Vector2(size.x * 0.09, size.y * 0.30), rank_str, int(size.y * 0.30), text_color, -1, HORIZONTAL_ALIGNMENT_LEFT, true)
	_text(Vector2(size.x * 0.09, size.y * 0.52), suit_sym, int(size.y * 0.22), text_color)

	# 中央大花色
	_text(Vector2(0, size.y * 0.86), suit_sym, int(size.y * 0.36), Color(text_color.r, text_color.g, text_color.b, 0.92), int(size.x), HORIZONTAL_ALIGNMENT_CENTER, true)

	# 右上分数徽标（>=20 分红底，其余灰底）
	if card_points > 0 and show_points:
		var bw := size.x * 0.38
		var bh := size.y * 0.16
		var bg := Color(0.86, 0.22, 0.18) if card_points >= 20 else Color(0.60, 0.60, 0.65)
		_badge_rounded(Rect2(size.x - bw - size.x * 0.06, size.y * 0.05, bw, bh), str(card_points) + "分", bg, Color.WHITE, int(size.y * 0.10))

	# 金牌：右下金币徽标
	if is_gold:
		var cc := Vector2(size.x * 0.80, size.y * 0.88)
		draw_circle(cc, size.x * 0.13, COL_GOLD)
		draw_arc(cc, size.x * 0.13, 0, TAU, 20, Color(0.65, 0.45, 0.05), 1.5)
		_text(Vector2(cc.x - size.x * 0.5, cc.y + size.y * 0.045), "金", int(size.y * 0.11), Color(0.35, 0.20, 0.02), int(size.x), HORIZONTAL_ALIGNMENT_CENTER, true)

func _is_red_suit() -> bool:
	if card == null:
		return false
	return card.suit in ["Hearts", "Diamonds"]

func _draw_wild(rect: Rect2, rad: float) -> void:
	_fill_rounded(rect, rad, Color(0.99, 0.96, 1.0), Color(0.90, 0.82, 0.96))
	_stroke_rounded(rect.grow(-1.0), rad, Color(0.72, 0.32, 0.85), 2.5)
	_text(Vector2(size.x * 0.09, size.y * 0.32), "?", int(size.y * 0.32), COL_RED, -1, HORIZONTAL_ALIGNMENT_LEFT, true)
	var c := size * 0.5
	draw_circle(c, size.x * 0.26, Color(0.80, 0.25, 0.30, 0.18))
	draw_circle(c, size.x * 0.21, Color(0.80, 0.25, 0.30, 0.9))
	_text(Vector2(c.x - size.x * 0.5, c.y + size.y * 0.06), "变", int(size.y * 0.16), Color.WHITE, int(size.x), HORIZONTAL_ALIGNMENT_CENTER, true)
	_badge_rounded(Rect2(size.x * 0.52, size.y * 0.05, size.x * 0.42, size.y * 0.14), "癞子", Color(0.80, 0.22, 0.25), Color.WHITE, int(size.y * 0.10))
	_text(Vector2(0, size.y * 0.96), "万能牌", int(size.y * 0.11), Color(0.55, 0.25, 0.65), int(size.x), HORIZONTAL_ALIGNMENT_CENTER)

func _draw_opportunity(rect: Rect2, rad: float) -> void:
	_fill_rounded(rect, rad, Color(1.0, 0.97, 0.90), Color(0.98, 0.88, 0.72))
	_stroke_rounded(rect.grow(-1.0), rad, Color(0.92, 0.55, 0.10), 2.5)
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	draw_circle(c, size.x * 0.24, Color(0.95, 0.60, 0.12, 0.9))
	_text(Vector2(c.x - size.x * 0.5, c.y + size.y * 0.07), "礼", int(size.y * 0.20), Color.WHITE, int(size.x), HORIZONTAL_ALIGNMENT_CENTER, true)
	_badge_rounded(Rect2(size.x * 0.52, size.y * 0.05, size.x * 0.42, size.y * 0.14), "机会", Color(0.92, 0.52, 0.08), Color.WHITE, int(size.y * 0.10))
	_text(Vector2(0, size.y * 0.80), "时来运转", int(size.y * 0.13), Color(0.80, 0.42, 0.05), int(size.x), HORIZONTAL_ALIGNMENT_CENTER, true)
	_text(Vector2(0, size.y * 0.95), "4 选 1", int(size.y * 0.11), Color(0.55, 0.38, 0.10), int(size.x), HORIZONTAL_ALIGNMENT_CENTER)

func _draw_action_badge() -> void:
	if action_badge.is_empty():
		return
	var s := size.x * 0.36
	var center := Vector2(size.x * 0.78, size.y * 0.84)
	draw_set_transform(center, -0.18, Vector2.ONE)
	var r := Rect2(-s * 0.5, -s * 0.5, s, s)
	var bg := Color(0.88, 0.15, 0.12) if action_badge.begins_with("胡") else Color(0.96, 0.55, 0.10)
	_fill_rounded(r, s * 0.25, bg, bg.darkened(0.15))
	_stroke_rounded(r, s * 0.25, Color.WHITE, 2.0)
	_text(Vector2(-s * 0.5, s * 0.16), action_badge, int(s * 0.5), Color.WHITE, int(s), HORIZONTAL_ALIGNMENT_CENTER, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
