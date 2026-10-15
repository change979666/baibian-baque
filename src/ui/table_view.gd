class_name GameTable
extends Control
## 牌桌视图（对齐《欢乐斗地主·百变八雀》官方横屏录屏观感）
## 视觉层：木质书桌边 + 透视绿绒桌面 + 胶囊弃牌槽(槽位/牌堆叠/死牌堆) +
## 座位扇形牌背/闹钟倒计时/金色光柱 + 开局横幅/首出/换牌红徽章/胡牌全屏特效

signal return_to_lobby_requested()

var sm: GameStateMachine
var room: GameRules.RoomConfig

# UI nodes
var seat_views: Array[PlayerSeat] = []
var hand_container: Control
var discard_panel: Control
var discard_container: HBoxContainer
var dead_pile_container: Control
var deck_label: Label
var gold_label: Label
var ting_label: Label
var ting_box: Panel
var room_title_label: Label
var prompt_label: Label

# Top-Left Dedicated Gold Box
var gold_box_panel: Panel
var gold_mini_slots: Array[Label] = []

# Center Deck & Count
var deck_stack_view: Control
var deck_count_label: Label

# Bottom HUD Badges
var gold_count_badge: Label
var points_badge: Label

# Action buttons
var actions_bar: HBoxContainer
var btn_discard: Button
var btn_hu: Button
var btn_pass: Button
var btn_swap: Button
var btn_trust: Button
var btn_chi: Button
var btn_draw: Button
var btn_refill: Button
var btn_back: Button
var btn_chat: Button
var btn_ting_toggle: Button
var btn_plus: Button
var pending_chi_card: Card = null

# Modals & Overlays
var hu_banner: HuBanner
var opp_dialog: OpportunityDialog
var refill_dialog: BeanRefillDialog
var game_over_panel: Panel
var bankrupt_panel: Panel
var bankrupt_dim: ColorRect
var swap_badge: PulseBadge
var hu_prompt_panel: Panel
var coach_panel: Panel
var coach_btn: Button
var guide_btn: Button
var _guide: Coach.Guide = null
var hu_prompt_box: HBoxContainer
var hu_log: Array = []

var selected_card_views: Array[CardView] = []
var is_trust_mode: bool = false
var human_hand_cards: Array = []
var anim_layer: Control

# Pacing state flags
var is_ceremony_playing: bool = false
var is_dealing_in_progress: bool = false
var cards_dealt_pending: bool = false
var pending_gold_ranks: Array[int] = []
var pending_swap_direction: String = ""
var first_turn_pending: bool = false

# Turn countdown
const TURN_SECONDS := 20.0
const CHI_SECONDS := 15.0
var _cd_active: bool = false
var _cd_left: float = 0.0
var _cd_fired: bool = false
var _cd_seat: int = 0

# Pill geometry
const PILL_RECT := Rect2(360, 225, 560, 150)
const SLOT_ORIGIN := Vector2(452, 238)
const SLOT_SIZE := Vector2(62, 88)
const SLOT_PITCH := 68.0
const SLOT_COUNT := 5
const HAND_CARD_SIZE := Vector2(100, 144)
const RIVER_CARD_SIZE := Vector2(62, 88)

var pill_glow: float = 0.0
var _draw_busy: bool = false
var game_paused: bool = false
var _pending_ai_seat: int = -1
var _pending_advance: bool = false

# ---------- 换牌红徽章 ----------
class PulseBadge extends Control:
	var line1: String = ""
	var line2: String = ""
	var t: float = 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var pulse := 1.0 + sin(t * 5.0) * 0.05
		var r := 46.0 * pulse
		draw_circle(c, r + 6.0, Color(1.0, 0.9, 0.4, 0.25))
		draw_circle(c, r + 2.0, Color(0.55, 0.05, 0.05))
		draw_circle(c, r, Color(0.85, 0.12, 0.10))
		draw_arc(c, r, 0, TAU, 32, Color(1.0, 0.85, 0.4, 0.9), 2.5)
		var font := ThemeDB.fallback_font
		draw_string_outline(font, c + Vector2(-60, -4), line1, HORIZONTAL_ALIGNMENT_CENTER, 120, 22, 2, Color(0.3, 0.0, 0.0))
		draw_string(font, c + Vector2(-60, -4), line1, HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color.WHITE)
		draw_string_outline(font, c + Vector2(-70, 18), line2, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, 2, Color(0.3, 0.0, 0.0))
		draw_string(font, c + Vector2(-70, 18), line2, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color(1.0, 0.92, 0.6))

class HuBurst extends Control:
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var c := Vector2(640, 360)
		var fade := clampf(1.0 - t / 1.2, 0.0, 1.0)
		if fade <= 0.0:
			return
		for i in range(14):
			var a := t * 0.55 + float(i) * TAU / 14.0
			var w := 0.055
			var col := Color(1.0, 0.85, 0.35, (0.07 if i % 2 == 0 else 0.03) * fade)
			draw_colored_polygon(PackedVector2Array([
				c, c + Vector2(cos(a - w), sin(a - w)) * 980.0, c + Vector2(cos(a + w), sin(a + w)) * 980.0
			]), col)
		for k in range(2):
			var rt := t - float(k) * 0.14
			if rt > 0.0 and rt < 0.9:
				var p := rt / 0.9
				draw_arc(c, 60.0 + p * 760.0, 0.0, TAU, 56, Color(1.0, 0.86, 0.35, (1.0 - p) * 0.4), 14.0 * (1.0 - p) + 2.0)
		draw_circle(c, 130.0 + t * 90.0, Color(1.0, 0.8, 0.3, 0.12 * fade))
		draw_circle(c, 70.0 + t * 50.0, Color(1.0, 0.9, 0.5, 0.16 * fade))
		# 碎裂岩石飞散
		for j in range(9):
			var a := float(j) * TAU / 9.0 + 0.35
			var sp := 260.0 + float((j * 37) % 5) * 60.0
			var p := c + Vector2(cos(a), sin(a)) * (sp * t) + Vector2(0, 240.0 * t * t)
			var rot := a + t * (3.0 + float(j % 3))
			var sz := 26.0 - float(j % 4) * 4.0
			var alpha := clampf(1.0 - t / 1.1, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			draw_set_transform(p, rot, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-sz, sz * 0.6), Vector2(-sz * 0.2, -sz), Vector2(sz, sz * 0.3), Vector2(0.0, sz)
			]), Color(0.32, 0.26, 0.22, alpha))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 闪电裂纹
		var la := clampf(1.0 - t / 0.7, 0.0, 1.0)
		if la > 0.0:
			for j in range(4):
				var a := float(j) * TAU / 4.0 + 0.7
				var pts := PackedVector2Array()
				var dirv := Vector2(cos(a), sin(a))
				var perp := Vector2(-dirv.y, dirv.x)
				var pos := c + dirv * 60.0
				pts.append(pos)
				for k in range(4):
					pos += dirv * 55.0 + perp * (28.0 if k % 2 == 0 else -28.0)
					pts.append(pos)
				draw_polyline(pts, Color(1.0, 0.95, 0.6, la), 3.0, true)
				draw_polyline(pts, Color(1.0, 1.0, 0.9, la * 0.8), 1.5, true)
		# 3D 金元宝箱
		var s := 1.0 - pow(1.0 - clampf(t / 0.4, 0.0, 1.0), 3.0)
		var sink := clampf((t - 0.9) / 0.8, 0.0, 1.0)
		var isc := (0.7 + 0.5 * s) * (1.0 - sink * 0.3)
		var ia := clampf(1.2 - sink, 0.0, 1.0) * clampf(t / 0.08, 0.0, 1.0)
		if ia > 0.0:
			draw_set_transform(c + Vector2(0, -20.0 + sink * 60.0), -0.06 + sin(t * 2.0) * 0.02, Vector2(isc, isc))
			var w := 150.0
			var h := 90.0
			var d := 60.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -h), Vector2(w * 0.5, -h + d * 0.5), Vector2(0, -h + d), Vector2(-w * 0.5, -h + d * 0.5)
			]), Color(1.0, 0.93, 0.55, ia))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w * 0.5, -h + d * 0.5), Vector2(0, -h + d), Vector2(0, d), Vector2(-w * 0.5, d * 0.5)
			]), Color(0.92, 0.62, 0.10, ia))
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -h + d), Vector2(w * 0.5, -h + d * 0.5), Vector2(w * 0.5, d * 0.5), Vector2(0, d)
			]), Color(0.78, 0.48, 0.06, ia))
			var outline := PackedVector2Array([
				Vector2(0, -h), Vector2(w * 0.5, -h + d * 0.5), Vector2(w * 0.5, d * 0.5), Vector2(0, d),
				Vector2(-w * 0.5, d * 0.5), Vector2(-w * 0.5, -h + d * 0.5), Vector2(0, -h)
			])
			draw_polyline(outline, Color(1.0, 0.95, 0.7, ia), 3.0, true)
			draw_polyline(PackedVector2Array([Vector2(0, -h + d), Vector2(0, d)]), Color(1.0, 0.95, 0.7, ia * 0.8), 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class MultBadge extends Control:
	var text := ""
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var s := 1.0 + 0.7 * pow(maxf(0.0, 1.0 - t / 0.3), 2.0)
		draw_set_transform(c, -0.12, Vector2(s, s))
		draw_circle(Vector2.ZERO, 46.0, Color(0.88, 0.28, 0.04))
		draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 36, Color(1.0, 0.82, 0.2), 4.0)
		draw_circle(Vector2(-12, -14), 15.0, Color(1.0, 0.55, 0.18, 0.55))
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-70, 12), text, HORIZONTAL_ALIGNMENT_CENTER, 140, 36, 3, Color(0.45, 0.12, 0.0))
		draw_string(font, Vector2(-70, 12), text, HORIZONTAL_ALIGNMENT_CENTER, 140, 36, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _init(p_room: GameRules.RoomConfig = null) -> void:
	room = p_room if p_room != null else GameRules.get_room("normal")

func _ready() -> void:
	size = Vector2(1280, 720)
	_setup_ui()
	if DisplayServer.get_name() == "headless":
		_start_new_match()
	else:
		_show_loading()

func _process(delta: float) -> void:
	if _cd_active and not sm.is_headless and not game_paused:
		_cd_left -= delta
		var sec := maxi(0, int(ceil(_cd_left)))
		if _cd_seat > 0 and _cd_seat < seat_views.size():
			seat_views[_cd_seat].set_countdown(sec)
		queue_redraw()
		if _cd_left <= 0.0 and not _cd_fired:
			_cd_fired = true
			_on_turn_timeout()

func _start_countdown(seat: int, seconds: float) -> void:
	_cd_active = true
	_cd_left = seconds
	_cd_fired = false
	_cd_seat = seat

func _stop_countdown() -> void:
	_cd_active = false
	for s in seat_views:
		s.set_countdown(-1)

func _on_turn_timeout() -> void:
	if sm == null:
		return
	var st = sm.state
	if st == GameStateMachine.State.SWAPPING:
		# 超时换牌必须与 AI 使用同一决策函数，不得直接取手牌前两张（会把癞子送走）
		var picks: Array = AIAgent.choose_swap_cards(sm.players[0], sm.gold_mgr.gold_ranks)
		if picks.size() >= 2:
			_show_toast("换牌超时，已按最优策略自动换牌")
			sm.human_confirm_swap([picks[0], picks[1]])
	elif st == GameStateMachine.State.AWAITING_DRAW_SELECTION:
		_show_toast("选牌超时，已自动从牌堆摸牌")
		sm.human_claim_chi(null)
	elif st == GameStateMachine.State.AWAITING_HUMAN_ACTION:
		if btn_hu.visible:
			sm.human_pass_hu()
		else:
			var discard = AIAgent.choose_discard_card(sm.players[0], sm.gold_mgr.gold_ranks)
			sm.human_discard_card(discard)

# ================= 桌面绘制 =================

func _draw() -> void:
	# 1. 木质书桌底（垂直渐变）
	var wood_pts := PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)])
	var wood_cols := PackedColorArray([
		Color(0.30, 0.19, 0.10), Color(0.30, 0.19, 0.10),
		Color(0.18, 0.11, 0.05), Color(0.18, 0.11, 0.05)
	])
	draw_polygon(wood_pts, wood_cols)

	# 2. 透视绿绒桌面（梯形 + 渐变）
	var felt_pts := PackedVector2Array([
		Vector2(150, 26), Vector2(1130, 26), Vector2(1254, 708), Vector2(26, 708)
	])
	var felt_cols := PackedColorArray([
		Color(0.13, 0.47, 0.30), Color(0.13, 0.47, 0.30),
		Color(0.09, 0.38, 0.24), Color(0.09, 0.38, 0.24)
	])
	draw_polygon(felt_pts, felt_cols)
	# 中心光晕
	draw_circle(Vector2(640, 330), 360, Color(0.35, 0.75, 0.50, 0.10))
	draw_circle(Vector2(640, 330), 220, Color(0.40, 0.80, 0.55, 0.08))
	# 桌沿描边
	felt_pts.append(felt_pts[0])
	draw_polyline(felt_pts, Color(0.04, 0.22, 0.13, 0.9), 5.0, true)
	var inner := PackedVector2Array([
		Vector2(158, 34), Vector2(1122, 34), Vector2(1242, 700), Vector2(38, 700), Vector2(158, 34)
	])
	draw_polyline(inner, Color(0.35, 0.70, 0.48, 0.35), 1.5, true)

	# 3. 装饰：左侧绿植 / 右上猫篮
	_draw_decor()

	# 4. 水印
	draw_string(ThemeDB.fallback_font, Vector2(880, 170), "百变八雀", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(1, 1, 1, 0.06))

	# 5. 弃牌槽胶囊
	_draw_pill()

	# 6. 人类行动期小鸡倒计时（官方为底部小鸡徽章而非座位闹钟）
	if _cd_active and _cd_seat == 0 and _cd_left > 0.0:
		var cc := Vector2(538, 470)
		draw_circle(cc, 19.0, Color(0.95, 0.62, 0.08))
		draw_circle(cc, 16.0, Color(1.0, 0.82, 0.18))
		draw_circle(cc + Vector2(-5, -14), 5.0, Color(1.0, 0.82, 0.18))
		draw_circle(cc + Vector2(5, -14), 5.0, Color(1.0, 0.82, 0.18))
		var font := ThemeDB.fallback_font
		var txt := str(maxi(0, int(ceil(_cd_left))))
		draw_string_outline(font, cc + Vector2(-20, 7), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 18, 2, Color(0.55, 0.3, 0.0))
		draw_string(font, cc + Vector2(-20, 7), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 18, Color.WHITE)

func _draw_decor() -> void:
	# 左：绿植叶片
	for i in range(4):
		var a := deg_to_rad(200.0 + i * 22.0)
		var base := Vector2(18, 150)
		var tip := base + Vector2(cos(a), sin(a)) * -70.0
		draw_colored_polygon(PackedVector2Array([
			base, base + Vector2(cos(a + 0.35), sin(a + 0.35)) * -46.0,
			tip, base + Vector2(cos(a - 0.35), sin(a - 0.35)) * -46.0
		]), Color(0.20, 0.55, 0.25, 0.85))
	# 右上：猫篮 + 猫 + 毛线球
	draw_circle(Vector2(1206, 86), 46, Color(0.45, 0.30, 0.16))
	draw_circle(Vector2(1206, 82), 38, Color(0.62, 0.45, 0.26))
	draw_circle(Vector2(1206, 76), 22, Color(0.90, 0.62, 0.25))
	draw_colored_polygon(PackedVector2Array([
		Vector2(1192, 60), Vector2(1196, 48), Vector2(1202, 58)
	]), Color(0.90, 0.62, 0.25))
	draw_colored_polygon(PackedVector2Array([
		Vector2(1210, 58), Vector2(1216, 48), Vector2(1220, 60)
	]), Color(0.90, 0.62, 0.25))
	draw_circle(Vector2(1160, 150), 12, Color(0.65, 0.45, 0.75))
	draw_circle(Vector2(1244, 142), 10, Color(0.45, 0.60, 0.80))

func _draw_pill() -> void:
	var r := PILL_RECT
	var rad := r.size.y * 0.5
	var lc := Vector2(r.position.x + rad, r.get_center().y)
	var rc := Vector2(r.end.x - rad, r.get_center().y)
	var mid := Rect2(lc.x, r.position.y, rc.x - lc.x, r.size.y)
	# 内部略暗
	draw_circle(lc, rad - 2, Color(0, 0, 0, 0.12))
	draw_circle(rc, rad - 2, Color(0, 0, 0, 0.12))
	draw_rect(Rect2(lc.x, r.position.y + 1, rc.x - lc.x, r.size.y - 2), Color(0, 0, 0, 0.12), true)
	# 描边（仪式期间金色发光）
	var base_col := Color(0.55, 0.86, 0.66, 0.85)
	var glow_col := Color(1.0, 0.85, 0.3, 0.95)
	var col := base_col.lerp(glow_col, pill_glow)
	var w := 3.0 + pill_glow * 2.0
	draw_arc(lc, rad, PI * 0.5, PI * 1.5, 32, col, w)
	draw_arc(rc, rad, -PI * 0.5, PI * 0.5, 32, col, w)
	draw_line(Vector2(lc.x, r.position.y), Vector2(rc.x, r.position.y), col, w)
	draw_line(Vector2(lc.x, r.end.y), Vector2(rc.x, r.end.y), col, w)
	if pill_glow > 0.01:
		draw_arc(lc, rad + 5, PI * 0.5, PI * 1.5, 32, Color(1.0, 0.85, 0.3, 0.35 * pill_glow), 6.0)
		draw_arc(rc, rad + 5, -PI * 0.5, PI * 0.5, 32, Color(1.0, 0.85, 0.3, 0.35 * pill_glow), 6.0)
	# 槽位格
	for i in range(SLOT_COUNT):
		var sr := Rect2(SLOT_ORIGIN.x + i * SLOT_PITCH, SLOT_ORIGIN.y, SLOT_SIZE.x, SLOT_SIZE.y)
		draw_rect(sr, Color(0.05, 0.26, 0.17, 0.55), true)
		draw_rect(sr, Color(0.30, 0.60, 0.42, 0.25), false, 1.0)
	# 末端小槽
	draw_rect(Rect2(846, 262, 30, 46), Color(0.05, 0.26, 0.17, 0.55), true)

# ================= UI 搭建 =================

func _setup_ui() -> void:
	# 模态先建（顶栏按钮引用）；z_index 提到最上层避免被弃牌河/手牌盖住
	hu_banner = HuBanner.new()
	hu_banner.z_index = 40
	add_child(hu_banner)
	opp_dialog = OpportunityDialog.new()
	opp_dialog.z_index = 45
	opp_dialog.card_chosen.connect(_on_opportunity_card_chosen)
	add_child(opp_dialog)
	refill_dialog = BeanRefillDialog.new()
	refill_dialog.z_index = 46
	refill_dialog.beans_refilled.connect(func(new_b):
		if sm and sm.players.size() > 0:
			sm.players[0].beans = new_b
			seat_views[0].update_beans()
	)
	add_child(refill_dialog)

	# 顶栏：退出门图标
	btn_back = Button.new()
	btn_back.flat = true
	btn_back.text = "🚪"
	btn_back.size = Vector2(44, 40)
	btn_back.position = Vector2(12, 8)
	btn_back.add_theme_font_size_override("font_size", 24)
	btn_back.tooltip_text = "返回大厅"
	btn_back.pressed.connect(func(): emit_signal("return_to_lobby_requested"))
	add_child(btn_back)

	# 顶栏：房间名（居中浅绿）
	room_title_label = Label.new()
	room_title_label.size = Vector2(560, 26)
	room_title_label.position = Vector2(360, 122)
	room_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_title_label.text = "百变八雀 · 点字成金  " + room.name + "  底分: " + str(room.base_score)
	room_title_label.add_theme_font_size_override("font_size", 15)
	room_title_label.add_theme_color_override("font_color", Color(0.62, 0.88, 0.72, 0.9))
	add_child(room_title_label)

	# 顶栏右：补豆中心
	btn_refill = Button.new()
	btn_refill.text = "🧧 补豆中心"
	btn_refill.size = Vector2(118, 32)
	btn_refill.position = Vector2(1148, 10)
	var rf := StyleBoxFlat.new()
	rf.bg_color = Color(0.85, 0.60, 0.10, 0.9)
	rf.corner_radius_top_left = 16
	rf.corner_radius_top_right = 16
	rf.corner_radius_bottom_left = 16
	rf.corner_radius_bottom_right = 16
	btn_refill.add_theme_stylebox_override("normal", rf)
	btn_refill.add_theme_color_override("font_color", Color.WHITE)
	btn_refill.add_theme_font_size_override("font_size", 13)
	btn_refill.pressed.connect(func(): refill_dialog.open())
	add_child(btn_refill)

	# 金牌盒（左上）
	_create_gold_box()

	# 隐藏/次要文本标签（逻辑仍会写它们）
	gold_label = Label.new()
	gold_label.visible = false
	add_child(gold_label)

	deck_label = Label.new()
	deck_label.size = Vector2(140, 20)
	deck_label.position = Vector2(930, 292)
	deck_label.text = "牌堆余量：84 张"
	deck_label.add_theme_font_size_override("font_size", 12)
	deck_label.add_theme_color_override("font_color", Color(0.62, 0.88, 0.72, 0.8))
	add_child(deck_label)

	# 4 座位
	_create_seats()

	# 弃牌槽内容层
	discard_panel = Control.new()
	discard_panel.size = Vector2(1280, 720)
	discard_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(discard_panel)

	discard_container = HBoxContainer.new()
	discard_container.position = SLOT_ORIGIN
	discard_container.size = Vector2(SLOT_COUNT * SLOT_PITCH, SLOT_SIZE.y)
	discard_container.add_theme_constant_override("separation", int(SLOT_PITCH - SLOT_SIZE.x))
	discard_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_panel.add_child(discard_container)

	dead_pile_container = Control.new()
	dead_pile_container.position = Vector2(800, 378)
	dead_pile_container.size = Vector2(430, 66)
	dead_pile_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_panel.add_child(dead_pile_container)

	# 牌堆叠（胶囊左端）
	deck_stack_view = Control.new()
	deck_stack_view.position = Vector2(378, 240)
	deck_stack_view.size = Vector2(64, 92)
	add_child(deck_stack_view)
	for i in range(3):
		var layer = Panel.new()
		layer.size = Vector2(64, 92)
		layer.position = Vector2(-i * 1.5, -i * 1.5)
		var ls = StyleBoxFlat.new()
		ls.bg_color = Color(0.24, 0.35, 0.66) if i == 0 else Color(0.18, 0.27, 0.55)
		ls.border_color = Color(0.62, 0.72, 0.95, 0.9)
		ls.border_width_left = 1
		ls.border_width_top = 1
		ls.border_width_right = 1
		ls.border_width_bottom = 1
		ls.corner_radius_top_left = 6
		ls.corner_radius_top_right = 6
		ls.corner_radius_bottom_left = 6
		ls.corner_radius_bottom_right = 6
		layer.add_theme_stylebox_override("panel", ls)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck_stack_view.add_child(layer)
	deck_count_label = Label.new()
	deck_count_label.size = Vector2(64, 92)
	deck_count_label.text = "84"
	deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	deck_count_label.add_theme_font_size_override("font_size", 26)
	deck_count_label.add_theme_color_override("font_color", Color.WHITE)
	deck_count_label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.25, 0.9))
	deck_count_label.add_theme_constant_override("outline_size", 4)
	deck_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_stack_view.add_child(deck_count_label)
	deck_stack_view.gui_input.connect(_on_deck_gui_input)

	# 动画层
	anim_layer = Control.new()
	anim_layer.size = Vector2(1280, 720)
	anim_layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(anim_layer)

	# 手牌容器
	hand_container = Control.new()
	hand_container.size = Vector2(1280, 180)
	hand_container.position = Vector2(0, 540)
	add_child(hand_container)

	# 托管黄胶囊（手牌上方居中）
	btn_trust = Button.new()
	btn_trust.text = "托 管"
	btn_trust.size = Vector2(120, 34)
	btn_trust.position = Vector2(580, 502)
	var tr := StyleBoxFlat.new()
	tr.bg_color = Color(0.98, 0.80, 0.15)
	tr.corner_radius_top_left = 17
	tr.corner_radius_top_right = 17
	tr.corner_radius_bottom_left = 17
	tr.corner_radius_bottom_right = 17
	tr.border_width_bottom = 3
	tr.border_color = Color(0.75, 0.55, 0.05)
	btn_trust.add_theme_stylebox_override("normal", tr)
	btn_trust.add_theme_stylebox_override("hover", tr)
	btn_trust.add_theme_color_override("font_color", Color(0.35, 0.22, 0.0))
	btn_trust.add_theme_font_size_override("font_size", 16)
	btn_trust.pressed.connect(_on_trust_pressed)
	add_child(btn_trust)

	# 动作按钮条
	actions_bar = HBoxContainer.new()
	actions_bar.size = Vector2(640, 48)
	actions_bar.position = Vector2(320, 448)
	actions_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_bar.add_theme_constant_override("separation", 14)
	add_child(actions_bar)

	btn_discard = _make_pill_button("出牌", Color(0.98, 0.65, 0.15), Color(0.80, 0.45, 0.05), 150, 48, 22)
	btn_discard.pressed.connect(_on_discard_pressed)
	actions_bar.add_child(btn_discard)

	btn_hu = _make_pill_button("胡", Color(0.88, 0.18, 0.12), Color(0.60, 0.08, 0.05), 130, 44, 18)
	btn_hu.pressed.connect(_on_hu_pressed)
	actions_bar.add_child(btn_hu)

	btn_pass = _make_pill_button("过", Color(0.45, 0.48, 0.55), Color(0.30, 0.32, 0.38), 80, 44, 18)
	btn_pass.pressed.connect(_on_pass_pressed)
	actions_bar.add_child(btn_pass)

	btn_swap = _make_pill_button("确认换牌 (0/2)", Color(0.20, 0.55, 0.85), Color(0.12, 0.38, 0.62), 170, 44, 16)
	btn_swap.pressed.connect(_on_swap_pressed)
	actions_bar.add_child(btn_swap)

	btn_chi = _make_pill_button("吃牌", Color(0.20, 0.65, 0.30), Color(0.12, 0.45, 0.20), 100, 44, 18)
	btn_chi.pressed.connect(_on_chi_pressed)
	btn_chi.visible = false
	actions_bar.add_child(btn_chi)

	btn_draw = _make_pill_button("摸牌", Color(0.35, 0.40, 0.48), Color(0.22, 0.26, 0.32), 90, 44, 18)
	btn_draw.pressed.connect(_on_draw_pressed)
	btn_draw.visible = false
	actions_bar.add_child(btn_draw)

	# 提示文本（弃牌槽下方）
	prompt_label = Label.new()
	prompt_label.size = Vector2(560, 28)
	prompt_label.position = Vector2(360, 396)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 17)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	prompt_label.add_theme_constant_override("outline_size", 4)
	add_child(prompt_label)

	# 听牌/推荐面板（左上金牌盒下）+ 切换胶囊
	ting_box = Panel.new()
	ting_box.size = Vector2(300, 58)
	ting_box.position = Vector2(48, 502)
	var tb_style = StyleBoxFlat.new()
	tb_style.bg_color = Color(0.04, 0.20, 0.13, 0.85)
	tb_style.border_color = Color(0.55, 0.86, 0.66, 0.5)
	tb_style.border_width_left = 1
	tb_style.border_width_top = 1
	tb_style.border_width_right = 1
	tb_style.border_width_bottom = 1
	tb_style.corner_radius_top_left = 8
	tb_style.corner_radius_top_right = 8
	tb_style.corner_radius_bottom_left = 8
	tb_style.corner_radius_bottom_right = 8
	ting_box.add_theme_stylebox_override("panel", tb_style)
	add_child(ting_box)

	ting_label = Label.new()
	ting_label.size = Vector2(290, 58)
	ting_label.position = Vector2(5, 0)
	ting_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ting_label.text = "听牌分析中..."
	ting_label.add_theme_font_size_override("font_size", 12)
	ting_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	ting_box.add_child(ting_label)

	btn_ting_toggle = _make_pill_button("番型/推荐", Color(0.30, 0.52, 0.90), Color(0.18, 0.36, 0.70), 104, 32, 14)
	btn_ting_toggle.position = Vector2(12, 676)
	btn_ting_toggle.pressed.connect(func(): ting_box.visible = not ting_box.visible)
	add_child(btn_ting_toggle)

	coach_btn = _make_pill_button("教练", Color(0.20, 0.55, 0.42), Color(0.12, 0.38, 0.28), 74, 32, 13)
	coach_btn.position = Vector2(124, 676)
	coach_btn.pressed.connect(func():
		coach_panel.visible = not coach_panel.visible
	)
	add_child(coach_btn)

	guide_btn = _make_pill_button("番型图鉴", Color(0.52, 0.40, 0.75), Color(0.36, 0.27, 0.55), 88, 32, 13)
	guide_btn.position = Vector2(206, 676)
	guide_btn.pressed.connect(_open_guide)
	add_child(guide_btn)

	coach_panel = Panel.new()
	coach_panel.size = Vector2(295, 205)
	coach_panel.position = Vector2(975, 450)
	coach_panel.mouse_filter = MOUSE_FILTER_IGNORE
	var cp_style = StyleBoxFlat.new()
	cp_style.bg_color = Color(0.04, 0.20, 0.13, 0.88)
	cp_style.border_color = Color(0.55, 0.86, 0.66, 0.5)
	cp_style.border_width_left = 1
	cp_style.border_width_top = 1
	cp_style.border_width_right = 1
	cp_style.border_width_bottom = 1
	cp_style.corner_radius_top_left = 10
	cp_style.corner_radius_top_right = 10
	cp_style.corner_radius_bottom_left = 10
	cp_style.corner_radius_bottom_right = 10
	coach_panel.add_theme_stylebox_override("panel", cp_style)
	add_child(coach_panel)

	# 底栏左：加豆按钮（座位0 旁）
	btn_plus = Button.new()
	btn_plus.text = "+"
	btn_plus.size = Vector2(34, 34)
	btn_plus.position = Vector2(252, 584)
	var pl := StyleBoxFlat.new()
	pl.bg_color = Color(0.98, 0.62, 0.10)
	pl.corner_radius_top_left = 17
	pl.corner_radius_top_right = 17
	pl.corner_radius_bottom_left = 17
	pl.corner_radius_bottom_right = 17
	btn_plus.add_theme_stylebox_override("normal", pl)
	btn_plus.add_theme_color_override("font_color", Color.WHITE)
	btn_plus.add_theme_font_size_override("font_size", 20)
	btn_plus.pressed.connect(func(): refill_dialog.open())
	add_child(btn_plus)

	# 底栏右：金币数 / 手牌分 / 聊天
	gold_count_badge = Label.new()
	gold_count_badge.size = Vector2(92, 32)
	gold_count_badge.position = Vector2(1002, 660)
	gold_count_badge.text = "🪙 金 0"
	gold_count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_count_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_count_badge.add_theme_font_size_override("font_size", 14)
	var g_style = StyleBoxFlat.new()
	g_style.bg_color = Color(0.10, 0.12, 0.16, 0.6)
	g_style.corner_radius_top_left = 16
	g_style.corner_radius_top_right = 16
	g_style.corner_radius_bottom_left = 16
	g_style.corner_radius_bottom_right = 16
	gold_count_badge.add_theme_stylebox_override("normal", g_style)
	gold_count_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(gold_count_badge)

	points_badge = Label.new()
	points_badge.size = Vector2(210, 32)
	points_badge.position = Vector2(984, 660)
	points_badge.text = "牌面点 0"
	points_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	points_badge.add_theme_font_size_override("font_size", 14)
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.10, 0.12, 0.16, 0.6)
	p_style.corner_radius_top_left = 16
	p_style.corner_radius_top_right = 16
	p_style.corner_radius_bottom_left = 16
	p_style.corner_radius_bottom_right = 16
	points_badge.add_theme_stylebox_override("normal", p_style)
	points_badge.add_theme_color_override("font_color", Color(0.55, 0.80, 1.0))
	add_child(points_badge)

	btn_chat = _make_pill_button("💬 聊天", Color(0.20, 0.70, 0.40), Color(0.12, 0.50, 0.28), 76, 32, 13)
	btn_chat.position = Vector2(1200, 660)
	btn_chat.pressed.connect(func(): _show_toast("单机版本暂无聊天功能"))
	add_child(btn_chat)

	# 换牌红徽章
	swap_badge = PulseBadge.new()
	swap_badge.size = Vector2(160, 100)
	swap_badge.position = Vector2(560, 148)
	swap_badge.mouse_filter = MOUSE_FILTER_IGNORE
	swap_badge.visible = false
	add_child(swap_badge)

	_setup_hu_prompt_panel()
	_setup_game_over_panel()
	_setup_bankrupt_panel()
	_update_action_buttons(false, false, false, false)
	ting_box.visible = false
	gold_box_panel.visible = false
	for s in seat_views:
		if s.seat_idx != 0:
			s.visible = false

func _make_pill_button(txt: String, bg: Color, border: Color, w: int, h: int, fs: int) -> Button:
	var b = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(w, h)
	b.size = Vector2(w, h)
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = h / 2
	s.corner_radius_top_right = h / 2
	s.corner_radius_bottom_left = h / 2
	s.corner_radius_bottom_right = h / 2
	s.border_width_bottom = 3
	s.border_color = border
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	var sp = s.duplicate()
	sp.border_width_bottom = 0
	sp.bg_color = bg.darkened(0.12)
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", fs)
	return b

func _create_gold_box() -> void:
	gold_box_panel = Panel.new()
	gold_box_panel.size = Vector2(150, 54)
	gold_box_panel.position = Vector2(62, 52)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.24, 0.15, 0.95)
	sb.border_color = Color(0.88, 0.72, 0.25)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	gold_box_panel.add_theme_stylebox_override("panel", sb)
	add_child(gold_box_panel)

	var tag = Label.new()
	tag.size = Vector2(30, 54)
	tag.position = Vector2(4, 0)
	tag.text = "金\n牌"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	gold_box_panel.add_child(tag)

	gold_mini_slots.clear()
	for i in range(3):
		var slot_p = Panel.new()
		slot_p.size = Vector2(32, 42)
		slot_p.position = Vector2(38 + i * 36, 6)
		var sp_style = StyleBoxFlat.new()
		sp_style.bg_color = Color(0.99, 0.96, 0.80)
		sp_style.border_color = Color(0.85, 0.65, 0.15)
		sp_style.border_width_left = 1
		sp_style.border_width_top = 1
		sp_style.border_width_right = 1
		sp_style.border_width_bottom = 1
		sp_style.corner_radius_top_left = 4
		sp_style.corner_radius_top_right = 4
		sp_style.corner_radius_bottom_left = 4
		sp_style.corner_radius_bottom_right = 4
		slot_p.add_theme_stylebox_override("panel", sp_style)
		gold_box_panel.add_child(slot_p)

		var lbl = Label.new()
		lbl.size = Vector2(32, 42)
		lbl.text = "?"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.2, 0.1, 0.0))
		slot_p.add_child(lbl)
		gold_mini_slots.append(lbl)

func _update_gold_box_ranks(ranks: Array[int]) -> void:
	for i in range(mini(ranks.size(), gold_mini_slots.size())):
		var r = ranks[i]
		var r_str = "A" if r == 14 else ("K" if r == 13 else ("Q" if r == 12 else ("J" if r == 11 else str(r))))
		gold_mini_slots[i].text = r_str

func _create_seats() -> void:
	var s0 = PlayerSeat.new(0)
	s0.position = Vector2(24, 556)
	add_child(s0)
	seat_views.append(s0)

	var s1 = PlayerSeat.new(1)
	s1.position = Vector2(1040, 240)
	add_child(s1)
	seat_views.append(s1)

	var s2 = PlayerSeat.new(2)
	s2.position = Vector2(602, 16)
	add_child(s2)
	seat_views.append(s2)

	var s3 = PlayerSeat.new(3)
	s3.position = Vector2(20, 240)
	add_child(s3)
	seat_views.append(s3)

func _seat_fan_global(seat: int) -> Vector2:
	match seat:
		1: return seat_views[1].global_position + Vector2(43, 42)
		2: return seat_views[2].global_position + Vector2(-58, 28)
		3: return seat_views[3].global_position + Vector2(110, 42)
		_: return seat_views[0].global_position + Vector2(120, 30)

# ================= 面板 =================

func _setup_hu_prompt_panel() -> void:
	hu_prompt_panel = Panel.new()
	hu_prompt_panel.size = Vector2(560, 132)
	hu_prompt_panel.position = Vector2(660, 140)
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.97, 0.97, 0.99, 0.96)
	st.border_color = Color(0.75, 0.80, 0.88, 1.0)
	st.border_width_left = 2
	st.border_width_top = 2
	st.border_width_right = 2
	st.border_width_bottom = 2
	st.corner_radius_top_left = 10
	st.corner_radius_top_right = 10
	st.corner_radius_bottom_left = 10
	st.corner_radius_bottom_right = 10
	hu_prompt_panel.add_theme_stylebox_override("panel", st)
	hu_prompt_panel.visible = false
	hu_prompt_panel.z_index = 35
	add_child(hu_prompt_panel)
	var ttl = Label.new()
	ttl.name = "Title"
	ttl.text = "─── 胡牌提示 ───"
	ttl.size = Vector2(520, 26)
	ttl.position = Vector2(0, 6)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.add_theme_font_size_override("font_size", 15)
	ttl.add_theme_color_override("font_color", Color(0.30, 0.35, 0.50))
	hu_prompt_panel.add_child(ttl)
	hu_prompt_box = HBoxContainer.new()
	hu_prompt_box.position = Vector2(16, 40)
	hu_prompt_box.size = Vector2(528, 86)
	hu_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hu_prompt_box.add_theme_constant_override("separation", 14)
	hu_prompt_panel.add_child(hu_prompt_box)

func _fill_hu_prompt(eval_res: HandEvaluator.HandEvalResult) -> void:
	for c in hu_prompt_box.get_children():
		c.queue_free()
	var hand = sm.players[0].hand
	var shown := 0
	for g in eval_res.groups:
		if shown >= 5:
			break
		var rank := g.rank_idx + 6
		var suit := g.suit
		if suit == Card.Suit.NONE:
			suit = -1
			for c in hand:
				if c.rank == rank and not c.is_wild() and not c.is_opportunity():
					suit = c.suit
					break
			if suit == -1:
				suit = Card.Suit.HEART
		var dummy = Card.new(-1, suit, rank, Card.CardType.NORMAL)
		var cv = CardView.new(dummy, false, Vector2(44, 62))
		cv.is_interactive = false
		cv.enable_hover = false
		cv.show_points = false
		cv.is_gold = sm.gold_mgr.is_gold_rank(rank)
		hu_prompt_box.add_child(cv)
		var vb = VBoxContainer.new()
		var rp := 30 if rank == 14 else (20 if rank >= 11 else 10)
		var pts := rp * g.size
		if sm.gold_mgr.is_gold_rank(rank):
			pts *= eval_res.gold_multiplier
		var l1 = Label.new()
		l1.text = str(pts) + "分"
		l1.add_theme_font_size_override("font_size", 14)
		l1.add_theme_color_override("font_color", Color(0.25, 0.30, 0.45))
		var l2 = Label.new()
		l2.text = str(g.size) + "张"
		l2.add_theme_font_size_override("font_size", 13)
		l2.add_theme_color_override("font_color", Color(0.50, 0.55, 0.65))
		var l3 = Label.new()
		l3.text = str(eval_res.final_multiplier) + "倍"
		l3.add_theme_font_size_override("font_size", 14)
		l3.add_theme_color_override("font_color", Color(0.85, 0.25, 0.15))
		vb.add_child(l1)
		vb.add_child(l2)
		vb.add_child(l3)
		hu_prompt_box.add_child(vb)
		shown += 1
	hu_prompt_panel.visible = true

func _hide_hu_prompt() -> void:
	hu_prompt_panel.visible = false

func _set_paused(v: bool) -> void:
	game_paused = v
	if not v:
		var ai := _pending_ai_seat
		var adv := _pending_advance
		_pending_ai_seat = -1
		_pending_advance = false
		if ai >= 0:
			_on_ai_turn_ready(ai)
		elif adv:
			sm.advance_to_next_turn()

func _set_bankrupt(v: bool) -> void:
	bankrupt_panel.visible = v
	bankrupt_dim.visible = v

func _setup_game_over_panel() -> void:
	game_over_panel = Panel.new()
	game_over_panel.size = Vector2(480, 300)
	game_over_panel.position = Vector2((1280 - 480) * 0.5, (720 - 300) * 0.5)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.98)
	style.border_color = Color(1.0, 0.8, 0.2, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	game_over_panel.add_theme_stylebox_override("panel", style)
	game_over_panel.visible = false
	game_over_panel.z_index = 50
	add_child(game_over_panel)

	var title = Label.new()
	title.name = "Title"
	title.size = Vector2(480, 44)
	title.position = Vector2(0, 16)
	title.text = "🏆 对局结束 · 战绩结算"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	game_over_panel.add_child(title)

	var stats = Label.new()
	stats.name = "Stats"
	stats.size = Vector2(440, 140)
	stats.position = Vector2(20, 70)
	stats.text = ""
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	game_over_panel.add_child(stats)

	var btn_again = Button.new()
	btn_again.text = "再来一局"
	btn_again.size = Vector2(130, 42)
	btn_again.position = Vector2(90, 230)
	btn_again.pressed.connect(func():
		game_over_panel.visible = false
		_start_new_match()
	)
	game_over_panel.add_child(btn_again)

	var btn_exit = Button.new()
	btn_exit.text = "返回大厅"
	btn_exit.size = Vector2(130, 42)
	btn_exit.position = Vector2(260, 230)
	btn_exit.pressed.connect(func(): emit_signal("return_to_lobby_requested"))
	game_over_panel.add_child(btn_exit)

func _setup_bankrupt_panel() -> void:
	bankrupt_panel = Panel.new()
	bankrupt_panel.size = Vector2(500, 310)
	bankrupt_panel.position = Vector2((1280 - 500) * 0.5, (720 - 310) * 0.5)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.07, 0.08, 0.98)
	style.border_color = Color(1.0, 0.35, 0.35, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	bankrupt_panel.add_theme_stylebox_override("panel", style)
	bankrupt_panel.z_index = 60
	add_child(bankrupt_panel)
	bankrupt_dim = ColorRect.new()
	bankrupt_dim.color = Color(0, 0, 0, 0.55)
	bankrupt_dim.size = Vector2(1280, 720)
	bankrupt_dim.z_index = 55
	bankrupt_dim.visible = false
	add_child(bankrupt_dim)
	_set_bankrupt(false)

	var title = Label.new()
	title.size = Vector2(500, 44)
	title.position = Vector2(0, 16)
	title.text = " 豆子不足啦 · 破产认输"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	bankrupt_panel.add_child(title)

	var desc = Label.new()
	desc.size = Vector2(440, 95)
	desc.position = Vector2(30, 68)
	desc.text = "您的欢乐豆已输光 (0 豆)，根据竞技规则判定【破产认输】！\n\n您可以立即免费领取救济豆满血复活，或选择认输观战剩余玩家决出胜负。"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	bankrupt_panel.add_child(desc)

	var btn_refill_resume = Button.new()
	btn_refill_resume.text = "💪 免费领取 200,000 救济豆 (满血复活)"
	btn_refill_resume.size = Vector2(280, 42)
	btn_refill_resume.position = Vector2(110, 180)
	var s_green = StyleBoxFlat.new()
	s_green.bg_color = Color(0.18, 0.58, 0.28)
	s_green.corner_radius_top_left = 6
	s_green.corner_radius_top_right = 6
	s_green.corner_radius_bottom_left = 6
	s_green.corner_radius_bottom_right = 6
	btn_refill_resume.add_theme_stylebox_override("normal", s_green)
	btn_refill_resume.pressed.connect(func():
		_set_bankrupt(false)
		_set_paused(false)
		SaveManager.refill_beans(200000)
		if sm:
			sm.human_refill_and_resume(200000)
		seat_views[0].set_bankrupt(false)
		seat_views[0].update_beans()
		_refresh_human_hand()
		_show_toast("已领取 200,000 救济豆，成功复活继续游戏！")
	)
	bankrupt_panel.add_child(btn_refill_resume)

	var btn_spectate = Button.new()
	btn_spectate.text = "👁️ 认输观战"
	btn_spectate.size = Vector2(130, 40)
	btn_spectate.position = Vector2(100, 240)
	btn_spectate.pressed.connect(func():
		_set_bankrupt(false)
		_set_paused(false)
		if sm:
			sm.human_forfeit()
		seat_views[0].set_bankrupt(true)
		_dim_human_hand()
		_update_action_buttons(false, false, false, false)
		_show_toast("您已认输观战，剩余玩家将继续对决！")
	)
	bankrupt_panel.add_child(btn_spectate)

	var btn_exit_lobby = Button.new()
	btn_exit_lobby.text = "🚪 认输离开"
	btn_exit_lobby.size = Vector2(130, 40)
	btn_exit_lobby.position = Vector2(270, 240)
	btn_exit_lobby.pressed.connect(func():
		emit_signal("return_to_lobby_requested")
	)
	bankrupt_panel.add_child(btn_exit_lobby)

# ================= 对局流程 =================

class PlaneView extends Control:
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5 + Vector2(sin(t * 3.0) * 6.0, sin(t * 5.0) * 4.0)
		# 机身
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-70, 0), c + Vector2(40, -16), c + Vector2(78, 0), c + Vector2(40, 14)
		]), Color(0.95, 0.45, 0.35))
		# 机翼
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-6, -4), c + Vector2(-34, -44), c + Vector2(-14, -44), c + Vector2(18, -6)
		]), Color(0.88, 0.35, 0.28))
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-6, 6), c + Vector2(-30, 40), c + Vector2(-12, 40), c + Vector2(18, 8)
		]), Color(0.82, 0.30, 0.24))
		# 尾翼
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-66, -2), c + Vector2(-84, -26), c + Vector2(-70, -26), c + Vector2(-52, -4)
		]), Color(0.88, 0.35, 0.28))
		# 窗
		draw_circle(c + Vector2(30, -4), 7.0, Color(0.75, 0.9, 1.0))
		# 小鸡乘客
		draw_circle(c + Vector2(-2, -26), 15.0, Color(1.0, 0.87, 0.3))
		draw_circle(c + Vector2(-7, -30), 2.4, Color(0.15, 0.1, 0.05))
		draw_circle(c + Vector2(3, -30), 2.4, Color(0.15, 0.1, 0.05))
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-4, -22), c + Vector2(4, -22), c + Vector2(0, -16)
		]), Color(0.95, 0.55, 0.1))

class SpinChick extends Control:
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		for i in range(3):
			var a := t * 6.0 + float(i) * TAU / 3.0
			draw_arc(c, 34.0, a, a + 1.2, 12, Color(1.0, 0.85, 0.3, 0.85), 6.0)
		draw_circle(c, 20.0, Color(1.0, 0.87, 0.3))
		draw_circle(c + Vector2(-6, -4), 3.0, Color(0.15, 0.1, 0.05))
		draw_circle(c + Vector2(6, -4), 3.0, Color(0.15, 0.1, 0.05))
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-5, 3), c + Vector2(5, 3), c + Vector2(0, 10)
		]), Color(0.95, 0.55, 0.1))

func _show_loading() -> void:
	var overlay = Control.new()
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(overlay)
	var bg = ColorRect.new()
	bg.color = Color(0.10, 0.36, 0.24)
	bg.size = Vector2(1280, 720)
	overlay.add_child(bg)
	var plane = PlaneView.new()
	plane.size = Vector2(240, 160)
	plane.position = Vector2(520, 220)
	overlay.add_child(plane)
	var tip = Label.new()
	tip.text = "正在进入牌桌…"
	tip.size = Vector2(1280, 30)
	tip.position = Vector2(0, 400)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	overlay.add_child(tip)
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.35)
	bar_bg.size = Vector2(400, 14)
	bar_bg.position = Vector2(440, 440)
	overlay.add_child(bar_bg)
	var bar1 = ColorRect.new()
	bar1.color = Color(1.0, 0.85, 0.3)
	bar1.size = Vector2(0, 14)
	bar1.position = Vector2(440, 440)
	overlay.add_child(bar1)
	var t = create_tween()
	t.tween_property(bar1, "size:x", 400.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func():
		overlay.queue_free()
		_show_start_capsule()
	)

func _show_start_capsule() -> void:
	var btn = Button.new()
	btn.text = "开始游戏"
	btn.size = Vector2(170, 52)
	btn.position = Vector2(555, 300)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.98, 0.62, 0.10)
	s.corner_radius_top_left = 26
	s.corner_radius_top_right = 26
	s.corner_radius_bottom_left = 26
	s.corner_radius_bottom_right = 26
	s.border_width_bottom = 4
	s.border_color = Color(0.80, 0.45, 0.05)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func():
		btn.queue_free()
		_show_matching()
	)
	add_child(btn)

func _show_matching() -> void:
	var overlay = Control.new()
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(overlay)
	var spin = SpinChick.new()
	spin.size = Vector2(90, 90)
	spin.position = Vector2(595, 280)
	overlay.add_child(spin)
	var lbl = Label.new()
	lbl.text = "正在匹配玩家，30秒"
	lbl.size = Vector2(1280, 30)
	lbl.position = Vector2(0, 380)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	overlay.add_child(lbl)
	var t = create_tween()
	t.tween_interval(1.3)
	t.tween_callback(func():
		overlay.queue_free()
		_start_new_match()
	)
func _start_new_match() -> void:
	var beans = SaveManager.get_beans()
	# P1-2: 进房强制校验——欢乐豆低于本房入场线时不允许开局
	if beans < room.min_beans:
		_show_toast("欢乐豆不足本房入场线（" + room.entry_label + "），请先补豆")
		refill_dialog.open()
		return
	sm = GameStateMachine.new(room, false)
	sm.setup_game(beans, 200000)

	_set_bankrupt(false)
	hu_log.clear()
	gold_box_panel.visible = true
	for i in range(4):
		seat_views[i].visible = true
		seat_views[i].set_player(sm.players[i])
		seat_views[i].set_bankrupt(false)

	sm.game_started.connect(_on_game_started)
	sm.gold_revealed.connect(_on_gold_revealed)
	sm.cards_dealt.connect(_on_cards_dealt)
	sm.swap_requested.connect(_on_swap_requested)
	sm.swap_completed.connect(_on_swap_completed)
	sm.turn_started.connect(_on_turn_started)
	sm.card_drawn.connect(_on_card_drawn)
	sm.hu_prompt_requested.connect(_on_hu_prompt_requested)
	sm.human_action_requested.connect(_on_human_action_requested)
	sm.hu_settled.connect(_on_hu_settled)
	sm.card_discarded.connect(_on_card_discarded)
	sm.card_discarded_dead.connect(_on_card_discarded_dead)
	sm.draw_selection_requested.connect(_on_draw_selection_requested)
	sm.card_chi_claimed.connect(_on_card_chi_claimed)
	sm.opportunity_triggered.connect(_on_opportunity_triggered)
	sm.ai_turn_ready.connect(_on_ai_turn_ready)
	sm.player_bankrupt.connect(_on_player_bankrupt)
	sm.human_bankrupt_prompt.connect(_on_human_bankrupt_prompt)
	sm.player_resumed.connect(_on_player_resumed)
	sm.game_over.connect(_on_game_over)

	for child in discard_container.get_children():
		child.queue_free()
	for child in dead_pile_container.get_children():
		child.queue_free()

	sm.start_round()

func _on_game_started() -> void:
	for child in discard_container.get_children():
		child.queue_free()
	for child in dead_pile_container.get_children():
		child.queue_free()

	_update_action_buttons(false, false, false, false)
	deck_label.text = "牌堆余量：" + str(sm.deck.remaining_count()) + " 张"
	first_turn_pending = true
	if not sm.is_headless:
		_show_start_banner()

func _show_start_banner() -> void:
	var overlay = Control.new()
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	anim_layer.add_child(overlay)
	var band_l = ColorRect.new()
	band_l.color = Color(0.15, 0.45, 0.85, 0.95)
	band_l.size = Vector2(660, 84)
	band_l.position = Vector2(-680, 300)
	band_l.rotation = -0.06
	overlay.add_child(band_l)
	var band_r = ColorRect.new()
	band_r.color = Color(0.95, 0.55, 0.10, 0.95)
	band_r.size = Vector2(660, 84)
	band_r.position = Vector2(1300, 330)
	band_r.rotation = -0.06
	overlay.add_child(band_r)
	var txt = Label.new()
	txt.text = "游 戏 开 始"
	txt.size = Vector2(1280, 70)
	txt.position = Vector2(0, 306)
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.add_theme_font_size_override("font_size", 44)
	txt.add_theme_color_override("font_color", Color.WHITE)
	txt.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.4, 0.9))
	txt.add_theme_constant_override("outline_size", 8)
	txt.modulate.a = 0.0
	overlay.add_child(txt)
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(band_l, "position:x", -10.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(band_r, "position:x", 630.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(txt, "modulate:a", 1.0, 0.3).set_delay(0.2)
	t.set_parallel(false)
	t.tween_interval(0.8)
	t.tween_property(overlay, "modulate:a", 0.0, 0.3)
	t.tween_callback(overlay.queue_free)

func _show_first_play(seat: int) -> void:
	var lbl = Label.new()
	lbl.text = "首出"
	lbl.size = Vector2(80, 40)
	lbl.position = Vector2(268, 282)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0, 0.9))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.modulate.a = 0.0
	add_child(lbl)
	var t = create_tween()
	t.tween_property(lbl, "modulate:a", 1.0, 0.2)
	t.tween_interval(1.2)
	t.tween_property(lbl, "modulate:a", 0.0, 0.4)
	t.tween_callback(lbl.queue_free)

func _on_gold_revealed(ranks: Array[int]) -> void:
	if sm.is_headless:
		gold_box_panel.visible = true
		_update_gold_box_ranks(ranks)
		gold_label.text = "★金牌：" + sm.gold_mgr.get_gold_ranks_display()
		return
	_play_gold_ceremony(ranks)

func _on_cards_dealt() -> void:
	deck_label.text = "牌堆余量：" + str(sm.deck.remaining_count()) + " 张"
	if deck_count_label:
		deck_count_label.text = str(sm.deck.remaining_count())

	if sm.is_headless:
		_refresh_human_hand()
		for i in range(1, 4):
			seat_views[i].update_ai_card_count(7)
		return

	if is_ceremony_playing:
		cards_dealt_pending = true
	else:
		_start_dealing_animation()

func _play_gold_ceremony(ranks: Array[int]) -> void:
	gold_box_panel.visible = true
	is_ceremony_playing = true
	pill_glow = 1.0
	queue_redraw()

	var overlay = Control.new()
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	anim_layer.add_child(overlay)

	var ribbon = Panel.new()
	ribbon.size = Vector2(560, 250)
	ribbon.position = Vector2((1280 - 560) * 0.5, 175)
	var rb_style = StyleBoxFlat.new()
	rb_style.bg_color = Color(0.05, 0.22, 0.14, 0.96)
	rb_style.border_color = Color(1.0, 0.85, 0.28, 1.0)
	rb_style.border_width_left = 3
	rb_style.border_width_top = 3
	rb_style.border_width_right = 3
	rb_style.border_width_bottom = 3
	rb_style.corner_radius_top_left = 16
	rb_style.corner_radius_top_right = 16
	rb_style.corner_radius_bottom_left = 16
	rb_style.corner_radius_bottom_right = 16
	ribbon.add_theme_stylebox_override("panel", rb_style)
	overlay.add_child(ribbon)

	var title = Label.new()
	title.size = Vector2(560, 44)
	title.position = Vector2(0, 14)
	title.text = "★ 点 字 成 金 ★"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	ribbon.add_child(title)

	var subtitle = Label.new()
	subtitle.size = Vector2(560, 24)
	subtitle.position = Vector2(0, 58)
	subtitle.text = "对应点数的牌成为金牌 · 胡牌获得额外倍数加成"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.82, 0.65))
	ribbon.add_child(subtitle)

	var ceremony_cards: Array[CardView] = []
	var card_x_starts = [65.0, 225.0, 385.0]
	var suits_to_use = [Card.Suit.HEART, Card.Suit.SPADE, Card.Suit.DIAMOND]

	for i in range(mini(3, ranks.size())):
		var r = ranks[i]
		var suit = suits_to_use[i % 3]
		var dummy_card = Card.new(-1, suit, r, Card.CardType.NORMAL)
		var cv = CardView.new(dummy_card, true)
		cv.position = Vector2(card_x_starts[i], 94)
		cv.is_interactive = false
		cv.enable_hover = false
		ribbon.add_child(cv)
		ceremony_cards.append(cv)

	var t = create_tween()
	t.tween_interval(0.25)
	t.tween_callback(func():
		if ceremony_cards.size() > 0:
			ceremony_cards[0].flip_to(false, 0.18)
			ceremony_cards[0].is_gold = true
			if SoundManager.instance:
				SoundManager.instance.play_gold_chime()
	)
	t.tween_interval(0.35)
	t.tween_callback(func():
		if ceremony_cards.size() > 1:
			ceremony_cards[1].flip_to(false, 0.18)
			ceremony_cards[1].is_gold = true
			if SoundManager.instance:
				SoundManager.instance.play_gold_chime()
	)
	t.tween_interval(0.35)
	t.tween_callback(func():
		if ceremony_cards.size() > 2:
			ceremony_cards[2].flip_to(false, 0.18)
			ceremony_cards[2].is_gold = true
			if SoundManager.instance:
				SoundManager.instance.play_gold_chime()
	)
	t.tween_interval(0.45)
	t.tween_callback(func():
		if SoundManager.instance:
			SoundManager.instance.play_gold_fly()
		var t_fade = create_tween()
		t_fade.tween_property(ribbon, "modulate:a", 0.0, 0.3)
		for idx in range(ceremony_cards.size()):
			var c_card = ceremony_cards[idx]
			var start_gpos = c_card.global_position
			c_card.get_parent().remove_child(c_card)
			anim_layer.add_child(c_card)
			c_card.global_position = start_gpos
			var target_gpos = gold_box_panel.global_position + Vector2(38 + idx * 36, 6)
			var fly_tw = create_tween()
			fly_tw.set_parallel(true)
			fly_tw.tween_property(c_card, "global_position", target_gpos, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			fly_tw.tween_property(c_card, "scale", Vector2(0.35, 0.32), 0.32)
	)
	t.tween_interval(0.35)
	t.tween_callback(func():
		overlay.queue_free()
		for c_card in ceremony_cards:
			c_card.queue_free()
		_update_gold_box_ranks(ranks)
		gold_label.text = "★金牌：" + sm.gold_mgr.get_gold_ranks_display()
		pill_glow = 0.0
		queue_redraw()
		is_ceremony_playing = false
		if cards_dealt_pending:
			cards_dealt_pending = false
			_start_dealing_animation()
	)

func _start_dealing_animation() -> void:
	is_dealing_in_progress = true
	human_hand_cards = sm.players[0].hand.duplicate()

	for child in hand_container.get_children():
		child.queue_free()
	for child in anim_layer.get_children():
		child.queue_free()
	selected_card_views.clear()

	for s in range(1, 4):
		seat_views[s].update_ai_card_count(0)

	var deck_pos = deck_stack_view.global_position + Vector2(10, 10)
	var N = human_hand_cards.size()

	for card_idx in range(N):
		var delay = card_idx * GameTiming.T["deal_interval"]
		var c = human_hand_cards[card_idx]
		var layout = _hand_layout(card_idx, N)
		var target_pos = hand_container.global_position + layout["pos"]
		var target_rot = layout["rot"]

		var flying = CardView.new(c, true, HAND_CARD_SIZE)
		flying.global_position = deck_pos
		flying.scale = Vector2(0.64, 0.64)
		flying.is_interactive = false
		flying.enable_hover = false
		anim_layer.add_child(flying)

		var tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(func():
			if SoundManager.instance:
				SoundManager.instance.play_deal()
			for s in range(1, 4):
				seat_views[s].update_ai_card_count(card_idx + 1)
		)
		tween.tween_property(flying, "global_position", target_pos, GameTiming.T["deal_flight"]).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(flying, "scale", Vector2(1.0, 1.0), GameTiming.T["deal_flight"])
		tween.parallel().tween_property(flying, "rotation", target_rot, GameTiming.T["deal_flight"])
		tween.tween_callback(func():
			flying.flip_to(false, 0.14)
			if sm.gold_mgr.is_gold_card(c):
				flying.is_gold = true
			if SoundManager.instance:
				SoundManager.instance.play_snap()
		)

	var finish_delay = (N - 1) * GameTiming.T["deal_interval"] + GameTiming.T["deal_flight"] + 0.2
	var finish_tween = create_tween()
	finish_tween.tween_interval(finish_delay)
	finish_tween.tween_callback(func():
		for child in anim_layer.get_children():
			child.queue_free()
		is_dealing_in_progress = false
		_refresh_human_hand()
		if pending_swap_direction != "":
			_show_swap_ui()
	)

func _hand_layout(i: int, n: int) -> Dictionary:
	var spacing = 66.0 if n <= 7 else 62.0
	var extra_gap = 16.0 if n == 8 else 0.0
	var total_w = (n - 1) * spacing + extra_gap + HAND_CARD_SIZE.x
	var start_x = (1280.0 - total_w) * 0.5
	var rel = float(i) - float(n - 1) * 0.5
	var x = start_x + i * spacing + (extra_gap if (n == 8 and i == 7) else 0.0)
	var y = pow(abs(rel), 1.8) * 7.0 + 6.0
	return {"pos": Vector2(x, y), "rot": deg_to_rad(rel * 3.5), "base_y": y}

func _on_swap_requested(direction: String) -> void:
	pending_swap_direction = direction
	if sm.is_headless:
		return
	if not is_ceremony_playing and not is_dealing_in_progress:
		_show_swap_ui()

func _show_swap_ui() -> void:
	var dir_name = "逆时针" if pending_swap_direction == "ccw" else ("顺时针" if pending_swap_direction == "cw" else "对家")
	swap_badge.line1 = "换 2 张"
	swap_badge.line2 = "本局" + dir_name + "换牌"
	swap_badge.visible = false
	var ribbon = YakuRibbon.new()
	ribbon.line1 = "换 2 张"
	ribbon.line2 = "选择 2 张牌后随机换给其他玩家"
	ribbon.size = Vector2(360, 74)
	ribbon.position = Vector2(430, 118)
	ribbon.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(ribbon)
	var rt = create_tween()
	rt.tween_interval(1.2)
	rt.tween_callback(func():
		swap_badge.visible = true
	)
	rt.tween_property(ribbon, "modulate:a", 0.0, 0.3)
	rt.tween_callback(ribbon.queue_free)
	prompt_label.text = "请选择 2 张牌进行换牌"
	btn_swap.text = "确认换牌 (0/2)"
	_update_action_buttons(false, false, false, true)
	_start_countdown(0, TURN_SECONDS)

func _on_swap_completed(direction: String) -> void:
	pending_swap_direction = ""
	swap_badge.visible = false
	prompt_label.text = ""
	_stop_countdown()
	if SoundManager.instance:
		SoundManager.instance.play_snap()
	_refresh_human_hand()
	_update_action_buttons(false, false, false, false)

func _on_turn_started(seat: int, is_human: bool) -> void:
	_hide_hu_prompt()
	for i in range(4):
		seat_views[i].set_active_turn(i == seat)
	deck_label.text = "牌堆余量：" + str(sm.deck.remaining_count()) + " 张"
	if deck_count_label:
		deck_count_label.text = str(sm.deck.remaining_count())
	if first_turn_pending:
		first_turn_pending = false
		if not sm.is_headless:
			_show_first_play(seat)
	if not sm.is_headless:
		_start_countdown(seat, TURN_SECONDS)

func _on_card_drawn(seat: int, card: Card, is_hai_di: bool) -> void:
	deck_label.text = "牌堆余量：" + str(sm.deck.remaining_count()) + " 张"
	if deck_count_label:
		deck_count_label.text = str(sm.deck.remaining_count())

	if sm.is_headless:
		if seat == 0:
			_refresh_human_hand()
		else:
			seat_views[seat].update_ai_card_count(8)
		return

	if SoundManager.instance:
		SoundManager.instance.play_deal()

	var deck_pos = deck_stack_view.global_position + Vector2(10, 10)

	if seat == 0:
		_draw_busy = true
		for child in hand_container.get_children():
			child.queue_free()
		selected_card_views.clear()

		var player = sm.players[0]
		var sorted7 = _group_sort(player.hand.duplicate())
		for i in range(mini(7, sorted7.size())):
			var c = sorted7[i]
			var cv = CardView.new(c, false, HAND_CARD_SIZE)
			cv.is_gold = sm.gold_mgr.is_gold_card(c)
			cv.card_clicked.connect(_on_card_clicked)
			var layout = _hand_layout(i, 8)
			cv.base_y = layout["base_y"]
			cv.position = layout["pos"]
			cv.rotation = layout["rot"]
			cv.pivot_offset = Vector2(50, 130)
			hand_container.add_child(cv)

		var target_pos = hand_container.global_position + _hand_layout(7, 8)["pos"]
		var flying = CardView.new(card, true, HAND_CARD_SIZE)
		flying.global_position = deck_pos
		flying.scale = Vector2(0.64, 0.64)
		flying.is_interactive = false
		flying.enable_hover = false
		anim_layer.add_child(flying)

		var tween = create_tween()
		tween.tween_property(flying, "global_position", target_pos, GameTiming.T["draw_duration"]).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(flying, "scale", Vector2(1.0, 1.0), GameTiming.T["draw_duration"])
		tween.tween_callback(func():
			flying.flip_to(false, GameTiming.T["flip_duration"])
			if sm.gold_mgr.is_gold_card(card):
				flying.is_gold = true
			if SoundManager.instance:
				SoundManager.instance.play_snap()
		)
		tween.tween_interval(GameTiming.T["draw_pause"])
		tween.tween_callback(func():
			flying.queue_free()
			_draw_busy = false
			_refresh_human_hand()
		)
	else:
		var target_pos = _seat_fan_global(seat)
		var flying = CardView.new(null, true, RIVER_CARD_SIZE)
		flying.global_position = deck_pos
		flying.is_interactive = false
		flying.enable_hover = false
		anim_layer.add_child(flying)

		var tween = create_tween()
		tween.tween_property(flying, "global_position", target_pos, GameTiming.T["ai_draw_duration"]).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			flying.queue_free()
			seat_views[seat].update_ai_card_count(8)
			if SoundManager.instance:
				SoundManager.instance.play_snap()
		)

func _on_ai_turn_ready(seat: int) -> void:
	if sm.is_headless:
		return
	if game_paused:
		_pending_ai_seat = seat
		return
	var think_time = GameTiming.T["draw_pause"] + randf_range(GameTiming.T["ai_think_min"], GameTiming.T["ai_think_max"]) + GameTiming.AI_BIAS[seat % 4]
	var tween = create_tween()
	tween.tween_interval(think_time)
	tween.tween_callback(func():
		var player = sm.players[seat]
		if player.hand.size() == 7:
			sm.execute_ai_draw_selection()
		else:
			sm.execute_ai_discard()
	)

func _on_human_action_requested() -> void:
	if is_trust_mode:
		var t = create_tween()
		t.tween_interval(GameTiming.T["draw_pause"] + 0.4)
		t.tween_callback(func():
			var discard = AIAgent.choose_discard_card(sm.players[0], sm.gold_mgr.gold_ranks)
			sm.human_discard_card(discard)
		)
	else:
		_start_countdown(0, TURN_SECONDS)
		if _draw_busy:
			var t2 = create_tween()
			t2.tween_interval(GameTiming.T["draw_pause"])
			t2.tween_callback(func(): _update_action_buttons(true, false, false, false))
		else:
			_update_action_buttons(true, false, false, false)

func _on_hu_prompt_requested(eval_res: HandEvaluator.HandEvalResult) -> void:
	if _draw_busy:
		var t3 = create_tween()
		t3.tween_interval(GameTiming.T["draw_pause"])
		t3.tween_callback(func(): _fill_hu_prompt(eval_res))
	else:
		_fill_hu_prompt(eval_res)
	btn_hu.text = "⭐ 胡 (" + eval_res.pattern_name + " x" + str(eval_res.final_multiplier) + ")"
	if is_trust_mode:
		var t = create_tween()
		t.tween_interval(1.6)
		t.tween_callback(func():
			sm.human_declare_hu()
		)
	else:
		_update_action_buttons(true, true, true, false)
		_start_countdown(0, TURN_SECONDS)

func _on_hu_settled(seat: int, eval_res: HandEvaluator.HandEvalResult, deltas: Dictionary) -> void:
	_hide_hu_prompt()
	if SoundManager.instance:
		SoundManager.instance.play_hu()
		SoundManager.instance.play_coin()
	_stop_countdown()

	var winner_name = sm.players[seat].name
	hu_log.append({"winner": winner_name, "pattern": eval_res.pattern_name, "mult": eval_res.final_multiplier, "human_delta": deltas.get(0, 0)})
	for s in deltas.keys():
		seat_views[s].update_beans()
		seat_views[s].show_floating_beans(deltas[s])
		seat_views[s].update_status()

	if sm.is_headless:
		hu_banner.show_hu(winner_name, eval_res)
		return

	_show_hu_action(seat, eval_res)
	var ht = create_tween()
	ht.tween_interval(GameTiming.T["hu_pause"])
	ht.tween_callback(func(): _play_hu_fx(winner_name, eval_res))

func _show_hu_action(seat: int, eval_res: HandEvaluator.HandEvalResult) -> void:
	var ev := " · ".join(eval_res.events)
	var stamp = Label.new()
	stamp.text = ("胡  " + ev) if ev != "" else "胡!"
	stamp.size = Vector2(500, 46)
	stamp.position = Vector2(390, 246)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.add_theme_font_size_override("font_size", 40)
	stamp.add_theme_color_override("font_color", Color(0.30, 1.0, 0.45))
	stamp.add_theme_color_override("font_outline_color", Color(0.0, 0.35, 0.1, 0.9))
	stamp.add_theme_constant_override("outline_size", 10)
	stamp.modulate.a = 0.0
	add_child(stamp)
	var stamp2 = Label.new()
	stamp2.text = "胡 x" + str(eval_res.final_multiplier)
	stamp2.size = Vector2(500, 40)
	stamp2.position = Vector2(390, 296)
	stamp2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp2.add_theme_font_size_override("font_size", 30)
	stamp2.add_theme_color_override("font_color", Color(1.0, 0.30, 0.18))
	stamp2.add_theme_color_override("font_outline_color", Color(0.35, 0.05, 0.0, 0.9))
	stamp2.add_theme_constant_override("outline_size", 8)
	stamp2.modulate.a = 0.0
	add_child(stamp2)
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(stamp, "modulate:a", 1.0, 0.12)
	t.tween_property(stamp2, "modulate:a", 1.0, 0.12).set_delay(0.08)
	t.set_parallel(false)
	t.tween_interval(0.9)
	t.tween_property(stamp, "modulate:a", 0.0, 0.2)
	t.tween_property(stamp2, "modulate:a", 0.0, 0.2)
	t.tween_callback(func():
		stamp.queue_free()
		stamp2.queue_free()
	)

func _play_hu_fx(winner_name: String, eval_res: HandEvaluator.HandEvalResult) -> void:
	var big := eval_res.final_multiplier >= 12
	var overlay = Control.new()
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(overlay)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62) if big else Color(0, 0, 0, 0.45)
	dim.size = Vector2(1280, 720)
	overlay.add_child(dim)

	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.88, 0.45, 0.55) if big else Color(1.0, 0.88, 0.45, 0.3)
	flash.size = Vector2(1280, 720)
	overlay.add_child(flash)

	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var tex = _get_spark_texture()
	var sparks = CPUParticles2D.new()
	sparks.material = mat
	sparks.texture = tex
	sparks.position = Vector2(640, 360)
	sparks.amount = 60 if big else 36
	sparks.lifetime = 0.7
	sparks.one_shot = true
	sparks.emitting = true
	sparks.explosiveness = 0.9
	sparks.spread = 180.0
	sparks.initial_velocity_min = 200.0
	sparks.initial_velocity_max = 520.0
	sparks.gravity = Vector2(0, 420)
	sparks.damping_min = 60.0
	sparks.scale_amount_min = 1.2
	sparks.scale_amount_max = 2.6
	sparks.color = Color(1.0, 0.82, 0.3)
	overlay.add_child(sparks)

	var txt_wrap: Control = null
	if big:
		var burst = HuBurst.new()
		burst.size = Vector2(1280, 720)
		burst.mouse_filter = MOUSE_FILTER_IGNORE
		overlay.add_child(burst)
		var embers = CPUParticles2D.new()
		embers.material = mat
		embers.texture = tex
		embers.position = Vector2(640, 430)
		embers.amount = 24
		embers.lifetime = 1.0
		embers.one_shot = true
		embers.emitting = true
		embers.explosiveness = 0.5
		embers.direction = Vector2(0, -1)
		embers.spread = 35.0
		embers.initial_velocity_min = 60.0
		embers.initial_velocity_max = 180.0
		embers.gravity = Vector2(0, -30)
		embers.scale_amount_min = 1.0
		embers.scale_amount_max = 2.0
		embers.color = Color(1.0, 0.65, 0.2)
		overlay.add_child(embers)
		txt_wrap = Control.new()
		txt_wrap.size = Vector2(1280, 120)
		txt_wrap.position = Vector2(0, 452)
		txt_wrap.pivot_offset = Vector2(640, 60)
		txt_wrap.scale = Vector2(2.6, 2.6)
		txt_wrap.rotation = -0.09
		overlay.add_child(txt_wrap)
		var shadow = Label.new()
		shadow.text = eval_res.pattern_name
		shadow.size = Vector2(1280, 90)
		shadow.position = Vector2(5, 52)
		shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shadow.add_theme_font_size_override("font_size", 64)
		shadow.add_theme_color_override("font_color", Color(0.28, 0.10, 0.0, 0.9))
		txt_wrap.add_child(shadow)
		var fx = Label.new()
		fx.text = eval_res.pattern_name
		fx.size = Vector2(1280, 90)
		fx.position = Vector2(0, 46)
		fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fx.add_theme_font_size_override("font_size", 64)
		fx.add_theme_color_override("font_color", Color(1.0, 0.80, 0.12))
		fx.add_theme_color_override("font_outline_color", Color(0.42, 0.14, 0.0))
		fx.add_theme_constant_override("outline_size", 10)
		txt_wrap.add_child(fx)
		var shake = create_tween()
		for off in [Vector2(6, -5), Vector2(-5, 4), Vector2(4, -3), Vector2(-2, 2), Vector2.ZERO]:
			shake.tween_property(self, "position", off, 0.045)

	# 番型带翼横幅（官方标准表现）
	var ribbon = YakuRibbon.new()
	ribbon.line1 = eval_res.pattern_name
	ribbon.line2 = winner_name + " 胡牌"
	ribbon.size = Vector2(420, 90)
	ribbon.position = Vector2(460, 235 if big else 285)
	ribbon.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(ribbon)


	var badge = MultBadge.new()
	badge.size = Vector2(150, 100)
	badge.position = Vector2(1030, 60)
	badge.text = "x" + str(eval_res.final_multiplier)
	overlay.add_child(badge)

	var settling = Label.new()
	settling.text = "结算中…"
	settling.size = Vector2(1280, 30)
	settling.position = Vector2(0, 14)
	settling.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settling.add_theme_font_size_override("font_size", 18)
	settling.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	overlay.add_child(settling)

	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(flash, "modulate:a", 0.0, 0.3)
	if big:
		t.tween_property(txt_wrap, "scale", Vector2(1.0, 1.0), 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)
		t.tween_property(txt_wrap, "rotation", 0.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.08)
	t.set_parallel(false)
	t.tween_interval(0.45 if big else 0.30)
	if big:
		t.tween_property(txt_wrap, "scale", Vector2(1.05, 1.05), 0.16)
		t.tween_property(txt_wrap, "scale", Vector2(1.0, 1.0), 0.16)
	t.tween_interval(0.35 if big else 0.25)
	t.tween_property(overlay, "modulate:a", 0.0, 0.25)
	t.tween_callback(func():
		overlay.queue_free()
		position = Vector2.ZERO
		hu_banner.show_hu(winner_name, eval_res)
	)

# ================= 弃牌河 / 死牌堆 =================

class YakuRibbon extends Control:
	var line1 := ""
	var line2 := ""
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var pop := 1.0 + 0.5 * pow(maxf(0.0, 1.0 - t / 0.3), 2.0)
		draw_set_transform(c, 0.0, Vector2(pop, pop))
		for k in range(3):
			var y0 := -14.0 + k * 12.0
			var ln := 70.0 - k * 16.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(-c.x + 12, y0), Vector2(-c.x + 12 - ln, y0 + 6), Vector2(-c.x + 12, y0 + 12)
			]), Color(1.0, 0.80, 0.25, 0.85 - 0.2 * k))
			draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - 12, y0), Vector2(c.x - 12 + ln, y0 + 6), Vector2(c.x - 12, y0 + 12)
			]), Color(1.0, 0.80, 0.25, 0.85 - 0.2 * k))
		var r := Rect2(-c.x + 12, -27, size.x - 24, 54)
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		var cols := PackedColorArray([
			Color(1.0, 0.88, 0.45), Color(1.0, 0.88, 0.45),
			Color(0.88, 0.58, 0.08), Color(0.88, 0.58, 0.08)
		])
		draw_polygon(pts, cols)
		pts.append(pts[0])
		draw_polyline(pts, Color(1.0, 0.95, 0.7, 0.9), 2.0, true)
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-c.x + 12, 4), line1, HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 24), 30, 2, Color(1.0, 0.95, 0.75))
		draw_string(font, Vector2(-c.x + 12, 4), line1, HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 24), 30, Color(0.45, 0.10, 0.05))
		if line2 != "":
			draw_string(font, Vector2(-c.x + 12, 22), line2, HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 24), 13, Color(0.55, 0.20, 0.05))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
var _spark_tex: ImageTexture = null

func _get_spark_texture() -> ImageTexture:
	if _spark_tex != null:
		return _spark_tex
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_spark_tex = ImageTexture.create_from_image(img)
	return _spark_tex


func _make_river_card(card: Card) -> CardView:
	var cv = CardView.new(card, false, RIVER_CARD_SIZE)
	cv.is_gold = sm.gold_mgr.is_gold_card(card)
	cv.is_interactive = true
	cv.enable_hover = false
	cv.show_points = false
	cv.card_clicked.connect(_on_river_card_clicked)
	var tag = Label.new()
	tag.name = "ActionTag"
	tag.size = Vector2(30, 30)
	tag.position = Vector2(36, 62)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.rotation = -0.2
	tag.add_theme_font_size_override("font_size", 17)
	tag.add_theme_color_override("font_color", Color.WHITE)
	tag.add_theme_color_override("font_outline_color", Color(0.85, 0.35, 0.0))
	tag.add_theme_constant_override("outline_size", 5)
	tag.visible = false
	cv.add_child(tag)
	return cv

func _on_river_card_clicked(cv: CardView) -> void:
	if sm.state == GameStateMachine.State.AWAITING_DRAW_SELECTION:
		# 规则校验：必须经过与 AI 相同的吃牌判定，UI 不得直接拿牌
		if HandEvaluator.can_chi(sm.players[0].hand, cv.card):
			_hide_river_action_tags()
			sm.human_claim_chi(cv.card)
		else:
			_show_toast("无法吃这张牌：需与手牌组成同点刻子或同花顺")

func _add_to_discard_river(card: Card) -> CardView:
	var cv = _make_river_card(card)
	discard_container.add_child(cv)
	discard_container.move_child(cv, 0)
	if discard_container.get_child_count() > SLOT_COUNT:
		var oldest = discard_container.get_child(discard_container.get_child_count() - 1)
		oldest.get_parent().remove_child(oldest)
		_add_to_dead_pile_node(oldest)
	return cv

func _add_to_dead_pile(card: Card) -> void:
	var cv = CardView.new(card, false, Vector2(44, 64))
	cv.is_gold = sm.gold_mgr.is_gold_card(card)
	cv.show_points = false
	cv.is_interactive = false
	cv.enable_hover = false
	dead_pile_container.add_child(cv)
	dead_pile_container.move_child(cv, 0)
	if dead_pile_container.get_child_count() > 10:
		dead_pile_container.get_child(dead_pile_container.get_child_count() - 1).queue_free()
	_restack_dead()

func _add_to_dead_pile_node(node: Node) -> void:
	dead_pile_container.add_child(node)
	dead_pile_container.move_child(node, 0)
	if dead_pile_container.get_child_count() > 10:
		dead_pile_container.get_child(dead_pile_container.get_child_count() - 1).queue_free()
	_restack_dead()

func _restack_dead() -> void:
	var children = dead_pile_container.get_children()
	for i in range(children.size()):
		children[i].position = Vector2(i * 32.0, 0.0)

func _on_card_discarded_dead(seat: int, card: Card) -> void:
	if sm.is_headless:
		_add_to_dead_pile(card)
		if seat == 0:
			_refresh_human_hand()
			_update_action_buttons(false, false, false, false)
		elif seat > 0:
			seat_views[seat].update_ai_card_count(7)
		return

	if seat == 0:
		_update_action_buttons(false, false, false, false)
	if seat > 0:
		seat_views[seat].update_ai_card_count(7)
	if SoundManager.instance:
		SoundManager.instance.play_snap()

	var river_target_gpos = dead_pile_container.global_position
	var start_pos = Vector2(640, 560)
	if seat > 0 and seat < seat_views.size():
		start_pos = _seat_fan_global(seat)

	if seat == 0:
		_refresh_human_hand()

	var flying = CardView.new(card, seat != 0, RIVER_CARD_SIZE)
	flying.global_position = start_pos
	flying.is_gold = sm.gold_mgr.is_gold_card(card)
	flying.is_interactive = false
	flying.enable_hover = false
	anim_layer.add_child(flying)

	var dead_mid: Vector2 = (flying.global_position + river_target_gpos) * 0.5 + Vector2(0, -40.0)
	var dd2: float = GameTiming.T["discard_duration"]
	var tween = create_tween()
	tween.tween_property(flying, "global_position", dead_mid, dd2 * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flying, "rotation", deg_to_rad(randf_range(-18.0, 18.0)) * 0.6, dd2 * 0.45)
	tween.tween_property(flying, "global_position", river_target_gpos, dd2 * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		flying.queue_free()
		_add_to_dead_pile(card)
		if SoundManager.instance:
			SoundManager.instance.play_snap()
	)

func _on_card_discarded(seat: int, card: Card) -> void:
	_hide_river_action_tags()
	_hide_hu_prompt()
	if sm.is_headless:
		_add_to_discard_river(card)
		if seat == 0:
			_refresh_human_hand()
			_update_action_buttons(false, false, false, false)
		elif seat > 0:
			seat_views[seat].update_ai_card_count(7)
		return

	if seat == 0:
		_update_action_buttons(false, false, false, false)
	if seat > 0:
		seat_views[seat].update_ai_card_count(7)
	if SoundManager.instance:
		SoundManager.instance.play_snap()

	var river_idx = discard_container.get_child_count()
	var river_target_gpos = discard_container.global_position + Vector2(mini(river_idx, SLOT_COUNT - 1) * SLOT_PITCH, 0)

	var start_pos = Vector2(640, 560)
	if seat == 0:
		for ch in hand_container.get_children():
			if ch is CardView and ch.card == card:
				start_pos = ch.global_position
				break
	elif seat < seat_views.size():
		start_pos = _seat_fan_global(seat)

	if seat == 0:
		_refresh_human_hand()

	var flying = CardView.new(card, seat != 0, HAND_CARD_SIZE if seat == 0 else RIVER_CARD_SIZE)
	flying.global_position = start_pos
	flying.is_gold = sm.gold_mgr.is_gold_card(card)
	flying.is_interactive = false
	flying.enable_hover = false
	anim_layer.add_child(flying)

	# 抛掷：弧线升起+旋转 → 加速落槽+回弹
	var spin := deg_to_rad(randf_range(-26.0, 26.0))
	var base_rot: float = flying.rotation
	var mid: Vector2 = (start_pos + river_target_gpos) * 0.5 + Vector2(0, -58.0)
	var land_scale := Vector2(RIVER_CARD_SIZE.x / HAND_CARD_SIZE.x, RIVER_CARD_SIZE.y / HAND_CARD_SIZE.y) if seat == 0 else Vector2(1, 1)
	var dd: float = GameTiming.T["discard_duration"]
	var tween = create_tween()
	tween.tween_property(flying, "global_position", mid, dd * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flying, "rotation", base_rot + spin * 0.55, dd * 0.45)
	if seat == 0:
		tween.parallel().tween_property(flying, "scale", (Vector2(1, 1) + land_scale) * 0.5, dd * 0.45)
	tween.tween_property(flying, "global_position", river_target_gpos, dd * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(flying, "rotation", base_rot + spin, dd * 0.55)
	if seat == 0:
		tween.parallel().tween_property(flying, "scale", land_scale, dd * 0.55)
	if seat != 0:
		tween.tween_callback(func():
			flying.flip_to(false, GameTiming.T["flip_duration"])
		)
		tween.tween_interval(GameTiming.T["flip_duration"])
	tween.tween_callback(func():
		flying.queue_free()
		var landed = _add_to_discard_river(card)
		if landed:
			landed.pivot_offset = RIVER_CARD_SIZE * 0.5
			landed.scale = Vector2(1.18, 1.18)
			var b = create_tween()
			b.tween_property(landed, "scale", Vector2(0.94, 0.94), 0.08)
			b.tween_property(landed, "scale", Vector2(1, 1), 0.08)
		if SoundManager.instance:
			SoundManager.instance.play_snap()
	)
	tween.tween_interval(GameTiming.T["discard_pause"] + GameTiming.T["turn_pause"])
	tween.tween_callback(func():
		if not card.is_opportunity() and seat != -1:
			if game_paused:
				_pending_advance = true
			else:
				sm.advance_to_next_turn()
	)

func _on_opportunity_triggered(seat: int, options: Array[Card]) -> void:
	_stop_countdown()
	if seat == 0:
		if is_trust_mode:
			var picked = AIAgent.choose_opportunity_card(options, sm.players[0].hand, sm.gold_mgr.gold_ranks)
			sm.human_pick_opportunity.call_deferred(picked)
		else:
			opp_dialog.show_options(options, sm.gold_mgr.gold_ranks)

func _on_opportunity_card_chosen(card: Card) -> void:
	sm.human_pick_opportunity(card)
	_refresh_human_hand()
	_update_action_buttons(true, false, false, false)
	_start_countdown(0, TURN_SECONDS)

func _on_game_over(summary: Dictionary) -> void:
	_set_bankrupt(false)
	_stop_countdown()
	_hide_hu_prompt()
	for i in range(4):
		seat_views[i].set_active_turn(false)

	for child in game_over_panel.get_children():
		child.queue_free()
	game_over_panel.size = Vector2(760, 520)
	game_over_panel.position = Vector2((1280 - 760) * 0.5, (720 - 520) * 0.5)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.98, 1.0, 0.98)
	style.border_color = Color(0.70, 0.75, 0.88, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	game_over_panel.add_theme_stylebox_override("panel", style)

	var title = Label.new()
	title.text = "本局结算"
	title.size = Vector2(760, 40)
	title.position = Vector2(0, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.30, 0.35, 0.52))
	game_over_panel.add_child(title)

	var players = summary.get("players", [])
	var y := 60.0
	for p in players:
		var row = Control.new()
		row.size = Vector2(700, 44)
		row.position = Vector2(30, y)
		game_over_panel.add_child(row)
		var av = Panel.new()
		av.size = Vector2(36, 36)
		av.position = Vector2(0, 4)
		var avs = StyleBoxFlat.new()
		avs.bg_color = _seat_color(int(p.seat_idx))
		avs.corner_radius_top_left = 18
		avs.corner_radius_top_right = 18
		avs.corner_radius_bottom_left = 18
		avs.corner_radius_bottom_right = 18
		avs.border_width_left = 2
		avs.border_width_top = 2
		avs.border_width_right = 2
		avs.border_width_bottom = 2
		avs.border_color = Color(1, 1, 1, 0.9)
		av.add_theme_stylebox_override("panel", avs)
		row.add_child(av)
		var avl = Label.new()
		avl.text = _seat_char(int(p.seat_idx))
		avl.size = Vector2(36, 36)
		avl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		avl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		avl.add_theme_font_size_override("font_size", 16)
		avl.add_theme_color_override("font_color", Color.WHITE)
		av.add_child(avl)
		var nm = Label.new()
		nm.text = str(p.name) + ("  (胡 x" + str(p.hu_count) + ")" if p.hu_count > 0 else "")
		nm.size = Vector2(300, 44)
		nm.position = Vector2(46, 0)
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 16)
		nm.add_theme_color_override("font_color", Color(0.25, 0.28, 0.40))
		row.add_child(nm)
		var net = int(p.round_net_beans)
		var dl = Label.new()
		dl.text = ("+" if net >= 0 else "-") + _format_beans(net)
		dl.size = Vector2(200, 44)
		dl.position = Vector2(480, 0)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dl.add_theme_font_size_override("font_size", 18)
		dl.add_theme_color_override("font_color", Color(0.90, 0.45, 0.05) if net >= 0 else Color(0.80, 0.20, 0.15))
		row.add_child(dl)
		y += 46.0

	var sep = ColorRect.new()
	sep.color = Color(0.75, 0.78, 0.88, 0.8)
	sep.size = Vector2(700, 2)
	sep.position = Vector2(30, y)
	game_over_panel.add_child(sep)
	y += 10.0

	var hi = 0
	for e in hu_log:
		if hi >= 4:
			break
		var hl = Label.new()
		var hd = int(e.get("human_delta", 0))
		hl.text = str(e.get("pattern", "")) + "  ·  " + str(e.get("winner", "")) + " 胡  ·  x" + str(e.get("mult", 0)) + "  ·  " + (("+" if hd >= 0 else "-") + _format_beans(hd))
		hl.size = Vector2(700, 26)
		hl.position = Vector2(30, y)
		hl.add_theme_font_size_override("font_size", 14)
		hl.add_theme_color_override("font_color", Color(0.45, 0.50, 0.62))
		game_over_panel.add_child(hl)
		y += 26.0
		hi += 1

	var broke := int(SaveManager.get_beans()) < room.min_beans
	var rec_l = Label.new()
	rec_l.text = Coach.recap_tip(players[0].hand if players.size() > 0 else [], sm.gold_mgr.gold_ranks)
	rec_l.size = Vector2(700, 26)
	rec_l.position = Vector2(30, y + 2)
	rec_l.add_theme_font_size_override("font_size", 13)
	rec_l.add_theme_color_override("font_color", Color(0.42, 0.38, 0.62))
	game_over_panel.add_child(rec_l)
	if broke:
		var warn = Label.new()
		warn.text = "⚠ 欢乐豆不足本房入场线：领取救济豆后才能再开一局（或返回大厅）"
		warn.size = Vector2(700, 24)
		warn.position = Vector2(30, y + 28)
		warn.add_theme_font_size_override("font_size", 13)
		warn.add_theme_color_override("font_color", Color(0.80, 0.30, 0.20))
		game_over_panel.add_child(warn)

	var btn_again = Button.new()
	btn_again.text = "下一局"
	btn_again.size = Vector2(160, 46)
	btn_again.position = Vector2(220, 458)
	btn_again.visible = not broke
	var as2 = StyleBoxFlat.new()
	as2.bg_color = Color(0.98, 0.72, 0.10)
	as2.corner_radius_top_left = 23
	as2.corner_radius_top_right = 23
	as2.corner_radius_bottom_left = 23
	as2.corner_radius_bottom_right = 23
	btn_again.add_theme_stylebox_override("normal", as2)
	btn_again.add_theme_color_override("font_color", Color.WHITE)
	btn_again.add_theme_font_size_override("font_size", 18)
	btn_again.pressed.connect(func():
		game_over_panel.visible = false
		_start_new_match()
	)
	game_over_panel.add_child(btn_again)

	var btn_exit = Button.new()
	btn_exit.text = "返回大厅"
	btn_exit.size = Vector2(160, 46)
	btn_exit.position = Vector2(400, 458)
	var es = StyleBoxFlat.new()
	es.bg_color = Color(0.60, 0.63, 0.75)
	es.corner_radius_top_left = 23
	es.corner_radius_top_right = 23
	es.corner_radius_bottom_left = 23
	es.corner_radius_bottom_right = 23
	btn_exit.add_theme_stylebox_override("normal", es)
	btn_exit.add_theme_color_override("font_color", Color.WHITE)
	btn_exit.add_theme_font_size_override("font_size", 18)
	btn_exit.pressed.connect(func(): emit_signal("return_to_lobby_requested"))
	game_over_panel.add_child(btn_exit)

	if int(SaveManager.get_beans()) < room.min_beans:
		var btn_relief2 = Button.new()
		btn_relief2.text = "💪 免费领取 200,000 救济豆并再战"
		btn_relief2.size = Vector2(300, 46)
		btn_relief2.position = Vector2(230, 398)
		var rls2 = StyleBoxFlat.new()
		rls2.bg_color = Color(0.85, 0.55, 0.08)
		rls2.corner_radius_top_left = 23
		rls2.corner_radius_top_right = 23
		rls2.corner_radius_bottom_left = 23
		rls2.corner_radius_bottom_right = 23
		btn_relief2.add_theme_stylebox_override("normal", rls2)
		btn_relief2.add_theme_color_override("font_color", Color.WHITE)
		btn_relief2.add_theme_font_size_override("font_size", 16)
		btn_relief2.pressed.connect(func():
			SaveManager.refill_beans(200000)
			game_over_panel.visible = false
			_start_new_match()
		)
		game_over_panel.add_child(btn_relief2)

	game_over_panel.visible = true

func _seat_color(seat: int) -> Color:
	match seat:
		0: return Color(0.25, 0.55, 0.85)
		1: return Color(0.85, 0.35, 0.30)
		2: return Color(0.30, 0.70, 0.45)
		_: return Color(0.90, 0.62, 0.15)

func _seat_char(seat: int) -> String:
	match seat:
		0: return "我"
		1: return "龙"
		2: return "孔"
		_: return "财"

func _on_player_bankrupt(seat: int) -> void:
	seat_views[seat].set_bankrupt(true)
	if seat != 0:
		_show_toast("【" + sm.players[seat].name + "】欢乐豆输光，已破产认输出局！")
		if SoundManager.instance:
			SoundManager.instance.play_coin()

func _on_human_bankrupt_prompt() -> void:
	_set_paused(true)
	_set_bankrupt(true)
	_update_action_buttons(false, false, false, false)

func _on_player_resumed(seat: int) -> void:
	seat_views[seat].set_bankrupt(false)
	seat_views[seat].update_beans()
	if seat == 0:
		_refresh_human_hand()

# ================= 手牌 / 交互 =================

func _show_toast(msg: String) -> void:
	var toast = Label.new()
	toast.text = msg
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.size = Vector2(560, 36)
	toast.position = Vector2((1280 - 560) * 0.5, 120)
	toast.add_theme_font_size_override("font_size", 16)
	toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.85, 0.7, 0.2, 0.8)
	toast.add_theme_stylebox_override("normal", s)
	add_child(toast)
	var tw = create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(toast, "modulate:a", 0.0, 0.6)
	tw.tween_callback(toast.queue_free)

func _dim_human_hand() -> void:
	for child in hand_container.get_children():
		child.modulate = Color(0.5, 0.5, 0.5, 0.6)
		if child is CardView:
			child.is_interactive = false

func _group_sort(cards: Array) -> Array:
	# 显示分组：同花顺>=3 → 同点刻>=3 → 对子 → 同花两张连 → 单张，让成结构/潜结构的牌挨在一起
	var used := []
	var blocks := []
	var suits = [Card.Suit.SPADE, Card.Suit.HEART, Card.Suit.CLUB, Card.Suit.DIAMOND]
	# same-suit runs >=3
	for su in suits:
		var pool := []
		for c in cards:
			if c.suit == su and c.rank > 0 and not used.has(c):
				pool.append(c)
		pool.sort_custom(func(a, b): return a.rank < b.rank)
		var cur := []
		for c in pool:
			if cur.size() and c.rank == cur[cur.size() - 1].rank + 1:
				cur.append(c)
			else:
				if cur.size() >= 3:
					blocks.append({"type": 0, "cards": cur.duplicate()})
					used.append_array(cur)
				cur = [c]
		if cur.size() >= 3:
			blocks.append({"type": 0, "cards": cur.duplicate()})
			used.append_array(cur)
	# sets >=3
	var ranks := []
	for c in cards:
		if c.rank > 0 and not ranks.has(c.rank):
			ranks.append(c.rank)
	ranks.sort()
	for r in ranks:
		var grp := []
		for c in cards:
			if c.rank == r and not used.has(c):
				grp.append(c)
		if grp.size() >= 3:
			blocks.append({"type": 1, "cards": grp})
			used.append_array(grp)
	# pairs
	for r in ranks:
		var grp := []
		for c in cards:
			if c.rank == r and not used.has(c):
				grp.append(c)
		if grp.size() == 2:
			blocks.append({"type": 2, "cards": grp})
			used.append_array(grp)
	# same-suit 2-seeds
	for su in suits:
		var pool := []
		for c in cards:
			if c.suit == su and c.rank > 0 and not used.has(c):
				pool.append(c)
		pool.sort_custom(func(a, b): return a.rank < b.rank)
		var cur := []
		for c in pool:
			if cur.size() and c.rank == cur[cur.size() - 1].rank + 1:
				cur.append(c)
			else:
				if cur.size() == 2:
					blocks.append({"type": 3, "cards": cur.duplicate()})
					used.append_array(cur)
				cur = [c]
		if cur.size() == 2:
			blocks.append({"type": 3, "cards": cur.duplicate()})
			used.append_array(cur)
	# singles + wilds/opportunity at end
	var rest := []
	for c in cards:
		if not used.has(c):
			rest.append(c)
	rest.sort_custom(func(a, b): return a.rank < b.rank)
	blocks.sort_custom(func(a, b): return a.type < b.type)
	var out := []
	for b in blocks:
		out.append_array(b.cards)
	out.append_array(rest)
	return out

func _refresh_human_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	selected_card_views.clear()

	var player = sm.players[0]
	human_hand_cards = _group_sort(player.hand.duplicate())

	var n = human_hand_cards.size()
	var total_pts = 0
	var gold_cnt = 0
	# 牌面点（A=30/JQK=20/6~10=10）仅为官方视觉展示指标，不参与结算；
	# 结算用分为 Scoring.card_score（rank 原值 6~14，癞子 10）。名称必须与含义一致。
	var settle_pts: int = 0
	for i in range(n):
		var c = human_hand_cards[i]
		total_pts += c.get_point_value()
		settle_pts += Scoring.card_score(c)
		if sm.gold_mgr.is_gold_card(c):
			gold_cnt += 1
		var cv = CardView.new(c, false, HAND_CARD_SIZE)
		cv.is_gold = sm.gold_mgr.is_gold_card(c)
		cv.card_clicked.connect(_on_card_clicked)
		var layout = _hand_layout(i, n)
		cv.base_y = layout["base_y"]
		cv.position = layout["pos"]
		cv.rotation = layout["rot"]
		cv.pivot_offset = Vector2(50, 130)
		hand_container.add_child(cv)

	if points_badge:
		points_badge.text = "牌面点 " + str(total_pts) + " · 结算分 " + str(settle_pts)
	if gold_count_badge:
		gold_count_badge.text = " 金 " + str(gold_cnt)
	if deck_count_label and sm and sm.deck:
		deck_count_label.text = str(sm.deck.remaining_count())

	_update_ting_hint()

func _open_guide() -> void:
	if _guide == null:
		_guide = Coach.Guide.new()
		add_child(_guide)
	else:
		_guide.visible = not _guide.visible

func _update_coach() -> void:
	for ch in coach_panel.get_children():
		ch.queue_free()
	if sm == null:
		return
	var a = Coach.analyze(sm.players[0].hand, sm.gold_mgr.gold_ranks)
	if a.is_empty():
		return
	var l1 = Label.new()
	l1.text = "教练 · 目标【" + str(a.name) + "】x" + str(a.mult)
	l1.size = Vector2(280, 22)
	l1.position = Vector2(8, 6)
	l1.add_theme_font_size_override("font_size", 14)
	l1.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	coach_panel.add_child(l1)
	var l2 = Label.new()
	l2.text = "进度 " + str(a.have) + "/" + str(a.need) + " · 还差约 " + str(a.missing) + " 张"
	l2.size = Vector2(280, 20)
	l2.position = Vector2(8, 28)
	l2.add_theme_font_size_override("font_size", 12)
	l2.add_theme_color_override("font_color", Color(0.75, 0.9, 0.8))
	coach_panel.add_child(l2)
	var kl = Label.new()
	kl.text = "留:"
	kl.size = Vector2(30, 36)
	kl.position = Vector2(8, 50)
	kl.add_theme_font_size_override("font_size", 11)
	kl.add_theme_color_override("font_color", Color(0.75, 0.9, 0.8))
	coach_panel.add_child(kl)
	var kx = 34
	for c in a.keep:
		if kx > 250:
			break
		var cv = CardView.new(c, false, Vector2(24, 34))
		cv.is_interactive = false
		cv.enable_hover = false
		cv.show_points = false
		cv.position = Vector2(kx, 48)
		coach_panel.add_child(cv)
		kx += 27
	var dl = Label.new()
	var dstr = ""
	for c in a.disc:
		dstr += c.get_rank_str() + c.get_suit_symbol() + " "
	dl.text = "考虑打: " + (dstr if dstr != "" else "无孤张")
	dl.size = Vector2(280, 20)
	dl.position = Vector2(8, 88)
	dl.add_theme_font_size_override("font_size", 12)
	dl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	coach_panel.add_child(dl)
	var tl = Label.new()
	tl.text = str(a.tip)
	tl.size = Vector2(280, 92)
	tl.position = Vector2(8, 110)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.add_theme_font_size_override("font_size", 11)
	tl.add_theme_color_override("font_color", Color(0.72, 0.88, 0.78))
	coach_panel.add_child(tl)

func _update_ting_hint() -> void:
	var player = sm.players[0]
	var tile_str := ""
	for c in player.hand:
		tile_str += c.get_rank_str() + c.get_suit_symbol() + " "
	if player.hand.size() == 7:
		var ting = HandEvaluator.ting_info(player.hand, sm.gold_mgr.gold_ranks)
		if ting["multiplier"] > 0:
			ting_label.text = tile_str + "
当前推荐: " + str(ting["name"]) + " x" + str(ting["multiplier"])
			ting_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			ting_label.text = tile_str + "
组牌中: 尚未听牌"
			ting_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.8))
	else:
		ting_label.text = tile_str + "
当前有 8 张牌，请选择打出"
	ting_box.visible = not ting_label.text.is_empty()
	if coach_panel:
		_update_coach()

func _on_card_clicked(cv: CardView) -> void:
	if SoundManager.instance:
		SoundManager.instance.play_select()

	if sm.state == GameStateMachine.State.SWAPPING:
		if selected_card_views.has(cv):
			selected_card_views.erase(cv)
			cv.set_selected(false)
		else:
			if selected_card_views.size() < GameRules.SWAP_COUNT:
				selected_card_views.append(cv)
				cv.set_selected(true)
		btn_swap.text = "确认换牌 (" + str(selected_card_views.size()) + "/2)"
		btn_swap.disabled = (selected_card_views.size() != 2)
	elif sm.state == GameStateMachine.State.AWAITING_HUMAN_ACTION:
		if selected_card_views.has(cv):
			sm.human_discard_card(cv.card)
			return
		for other in selected_card_views:
			if other != cv:
				other.set_selected(false)
		selected_card_views.clear()
		cv.set_selected(true)
		selected_card_views.append(cv)
		btn_discard.disabled = false

func _on_discard_pressed() -> void:
	if SoundManager.instance:
		SoundManager.instance.play_snap()
	if selected_card_views.is_empty():
		return
	var chosen_card = selected_card_views[0].card
	sm.human_discard_card(chosen_card)

func _on_hu_pressed() -> void:
	_hide_hu_prompt()
	if SoundManager.instance:
		SoundManager.instance.play_snap()
	sm.human_declare_hu()

func _on_pass_pressed() -> void:
	_hide_hu_prompt()
	if SoundManager.instance:
		SoundManager.instance.play_snap()
	sm.human_pass_hu()

func _on_swap_pressed() -> void:
	if SoundManager.instance:
		SoundManager.instance.play_snap()
	if selected_card_views.size() != 2:
		return
	var cards_to_swap: Array[Card] = [selected_card_views[0].card, selected_card_views[1].card]
	sm.human_confirm_swap(cards_to_swap)

func _on_trust_pressed() -> void:
	is_trust_mode = not is_trust_mode
	btn_trust.text = "取消托管" if is_trust_mode else "托 管"
	if is_trust_mode:
		btn_trust.add_theme_color_override("font_color", Color(0.85, 0.15, 0.1))
		if sm.state == GameStateMachine.State.AWAITING_DRAW_SELECTION:
			sm.human_claim_chi.call_deferred(null)
		elif sm.state == GameStateMachine.State.SWAPPING:
			var picks: Array = AIAgent.choose_swap_cards(sm.players[0], sm.gold_mgr.gold_ranks)
			if picks.size() >= 2:
				sm.human_confirm_swap.call_deferred([picks[0], picks[1]])
		elif sm.state == GameStateMachine.State.AWAITING_HUMAN_ACTION:
			var discard = AIAgent.choose_discard_card(sm.players[0], sm.gold_mgr.gold_ranks)
			sm.human_discard_card.call_deferred(discard)
	else:
		btn_trust.add_theme_color_override("font_color", Color(0.35, 0.22, 0.0))

func _on_chi_pressed() -> void:
	if SoundManager.instance:
		SoundManager.instance.play_snap()
	if pending_chi_card:
		var card = pending_chi_card
		pending_chi_card = null
		sm.human_claim_chi(card)

func _on_draw_pressed() -> void:
	if SoundManager.instance:
		SoundManager.instance.play_snap()
	pending_chi_card = null
	sm.human_pass_chi()

func _on_draw_selection_requested(seat: int) -> void:
	if is_trust_mode:
		var t = create_tween()
		t.tween_interval(GameTiming.T["draw_pause"] + 0.4)
		t.tween_callback(func():
			sm.human_claim_chi(null)
		)
		return

	_update_action_buttons(false, false, false, false, false, false)
	ting_label.text = ""
	ting_box.visible = false
	prompt_label.text = "👉 请从牌堆或亮牌中选择一张牌"
	prompt_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_start_countdown(0, CHI_SECONDS)

	for i in range(discard_container.get_child_count()):
		var c = discard_container.get_child(i)
		var tag = c.get_node_or_null("ActionTag")
		if tag:
			# 只有真正可吃（通过 get_chi_combinations 校验）的河牌才亮「吃」标
			var chi_combos: Array = []
			if c is CardView and c.card != null:
				chi_combos = HandEvaluator.get_chi_combinations(sm.players[0].hand, c.card)
			tag.text = "吃"
			tag.visible = not chi_combos.is_empty()

func _on_deck_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if sm.state == GameStateMachine.State.AWAITING_DRAW_SELECTION:
			_hide_river_action_tags()
			sm.human_claim_chi(null)

func _hide_river_action_tags() -> void:
	for c in discard_container.get_children():
		var tag = c.get_node_or_null("ActionTag")
		if tag:
			tag.visible = false

func _on_card_chi_claimed(seat: int, card: Card) -> void:
	pending_chi_card = null
	_stop_countdown()
	_update_action_buttons(false, false, false, false, false, false)
	_hide_river_action_tags()

	for c in discard_container.get_children():
		if c is CardView and c.card != null and c.card.to_display_string() == card.to_display_string():
			c.queue_free()
			break

	if seat == 0 and not sm.is_headless:
		_start_countdown(0, TURN_SECONDS)

	if sm.is_headless:
		if seat == 0:
			_refresh_human_hand()
		else:
			seat_views[seat].update_ai_card_count(8)
		return

	if SoundManager.instance:
		SoundManager.instance.play_snap()

	var river_idx = max(0, discard_container.get_child_count() - 1)
	var river_gpos = discard_container.global_position + Vector2(river_idx * SLOT_PITCH, 0)

	if seat == 0:
		var target_pos = hand_container.global_position + _hand_layout(7, 8)["pos"]
		var flying = CardView.new(card, false, RIVER_CARD_SIZE)
		flying.global_position = river_gpos
		flying.is_gold = sm.gold_mgr.is_gold_card(card)
		flying.is_interactive = false
		flying.enable_hover = false
		anim_layer.add_child(flying)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(flying, "global_position", target_pos, GameTiming.T["draw_duration"]).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(flying, "scale", Vector2(HAND_CARD_SIZE.x / RIVER_CARD_SIZE.x, HAND_CARD_SIZE.y / RIVER_CARD_SIZE.y), GameTiming.T["draw_duration"])
		tween.set_parallel(false)
		tween.tween_callback(func():
			flying.queue_free()
			_refresh_human_hand()
			if SoundManager.instance:
				SoundManager.instance.play_snap()
		)
	else:
		var target_pos = _seat_fan_global(seat)
		var flying = CardView.new(card, false, RIVER_CARD_SIZE)
		flying.global_position = river_gpos
		flying.is_interactive = false
		flying.enable_hover = false
		anim_layer.add_child(flying)

		var tween = create_tween()
		tween.tween_property(flying, "global_position", target_pos, GameTiming.T["ai_draw_duration"]).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			flying.queue_free()
			seat_views[seat].update_ai_card_count(8)
		)

func _update_action_buttons(can_discard: bool, can_hu: bool, can_pass: bool, can_swap: bool, can_chi: bool = false, can_draw: bool = false) -> void:
	btn_discard.visible = can_discard
	btn_discard.disabled = selected_card_views.is_empty()
	btn_hu.visible = can_hu
	btn_pass.visible = can_pass
	btn_swap.visible = can_swap
	btn_swap.disabled = (selected_card_views.size() != 2)
	btn_chi.visible = can_chi
	btn_draw.visible = can_draw
	if can_discard:
		prompt_label.text = ""
	elif not can_chi and not can_draw:
		if sm and sm.state != GameStateMachine.State.AWAITING_DRAW_SELECTION:
			prompt_label.text = ""

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
