class_name Coach
extends RefCounted
## 教学教练：分析当前手牌的高倍目标进度、留牌/打牌建议，并提供番型图鉴。
## 定位：真人对局前的训练器——每回合告诉你"该追什么大番、还缺什么、该打哪张"。

const TIPS := {
	"独一无二": "开局同点已≥4张才追 x100，否则果断放弃；追时其余牌全做弃子保点数。",
	"君临天下": "开局同点已≥4张才追 x100，否则果断放弃；追时其余牌全做弃子保点数。",
	"十全十美": "开局同点已≥4张才追 x100，否则果断放弃；追时其余牌全做弃子保点数。",
	"八方来财": "开局同点已≥4张才追 x100，否则果断放弃；8 全场有 12 张，机会牌/吃牌是补张利器。",
	"八方来贺": "同点≥5 或同花连≥5 才开始想 x50；癞子优先用来补最后一个缺口。",
	"顶峰相见": "六大番套路固定：K六+A对 / J六+Q对 / 10六+9对 / 6六+7对。开局先数这四组，沾边的对子务必留。",
	"心心相连": "六大番套路固定：K六+A对 / J六+Q对 / 10六+9对 / 6六+7对。开局先数这四组，沾边的对子务必留。",
	"十拿九稳": "六大番套路固定：K六+A对 / J六+Q对 / 10六+9对 / 6六+7对。开局先数这四组，沾边的对子务必留。",
	"六事兴旺": "六大番套路固定：K六+A对 / J六+Q对 / 10六+9对 / 6六+7对。开局先数这四组，沾边的对子务必留。",
	"比翼为邻": "留六连张+对子，且对子点数要与连张端点相邻（如 6-11 连配 Q 对）。拆牌前先检查邻位。",
	"六朝金粉": "整手统一颜色（全红/全黑）是 x16 捷径：早期就按颜色留牌，异色孤张先打。",
	"六六大顺": "最实用的中番：六张连/组+任意对子=x8。连张差一张时宁可等一轮不拆。",
	"永恒相随": "五连张+相邻三点组（如 6-10 连 + JJJ）。持两组中牌时优先凑相邻点数。",
	"五谷丰登": "全同色的 5+3：先定颜色再凑组，异色牌即使成对也要舍得打。",
	"二龙腾飞": "两组四连且端点相邻（如 6-9 + 10-13）。真人局最常见的进阶目标，x4 起步稳。",
	"四季发财": "两组四张且全同色：红黑二选一早期定调，x4 与颜色纪律绑定。",
	"四季如春": "入门番 x2：任意两组四张合法牌型。大番无望时的保底路线。",
	"平胡": "3+3+2 保底番 x1，注意持癞子不能平胡。大番无望时快速小胡止损也是技术。",
}

const GENERAL_TIP := "金牌(点字成金)会让最终倍数×手牌金牌张数——持金牌时优先追大番；癞子可代任意牌但持癞子不能平胡。"

static func _cand(name: String, mult: int, have: int, need: int, ranks: Array) -> Dictionary:
	return {"name": name, "mult": mult, "have": have, "need": need, "ranks": ranks}

static func analyze(hand: Array, gold_ranks: Array) -> Dictionary:
	if hand == null or hand.is_empty():
		return {}
	var counts := {}
	for c in hand:
		if c.rank > 0:
			counts[c.rank] = int(counts.get(c.rank, 0)) + 1
	var cands := []
	var eight_map = {14: PatternDef.DU_YI_WU_ER, 13: PatternDef.JUN_LIN_TIAN_XIA, 10: PatternDef.SHI_QUAN_SHI_MEI, 8: PatternDef.BA_FANG_LAI_CAI}
	for r in eight_map:
		var hv = int(counts.get(r, 0))
		if hv >= 3:
			cands.append(_cand(eight_map[r], 100, hv, 8, [r]))
	var best_r = -1
	var best_n = 0
	for r in counts:
		if int(counts[r]) > best_n and not eight_map.has(r):
			best_n = int(counts[r])
			best_r = int(r)
	if best_n >= 5:
		cands.append(_cand(PatternDef.BA_FANG_LAI_HE, 50, best_n, 8, [best_r]))
	for trip in [[13, 14, PatternDef.DING_FENG_XIANG_JIAN], [11, 12, PatternDef.XIN_XIN_XIANG_LIAN], [10, 9, PatternDef.SHI_NA_JIU_WEN], [6, 7, PatternDef.LIU_SHI_XING_WANG]]:
		var hv = mini(int(counts.get(trip[0], 0)), 6) + mini(int(counts.get(trip[1], 0)), 2)
		if hv >= 4:
			cands.append(_cand(str(trip[2]), 32, hv, 8, [trip[0], trip[1]]))
	var suits = [Card.Suit.SPADE, Card.Suit.HEART, Card.Suit.CLUB, Card.Suit.DIAMOND]
	var best_run := 0
	var best_run_ranks: Array = []
	for s in suits:
		var rs := []
		for c in hand:
			if c.suit == s and c.rank > 0 and not rs.has(c.rank):
				rs.append(c.rank)
		rs.sort()
		var cur := []
		for r in rs:
			if cur.size() and int(r) == int(cur[cur.size() - 1]) + 1:
				cur.append(r)
			else:
				if cur.size() > best_run:
					best_run = cur.size()
					best_run_ranks = cur.duplicate()
				cur = [r]
		if cur.size() > best_run:
			best_run = cur.size()
			best_run_ranks = cur.duplicate()
	var has_pair := false
	for r in counts:
		if int(counts[r]) >= 2:
			has_pair = true
	if best_run >= 4:
		cands.append(_cand(PatternDef.LIU_LIU_DA_SHUN, 8, mini(best_run, 6) + (2 if has_pair else 0), 8, best_run_ranks))
		cands.append(_cand(PatternDef.BI_YI_WEI_LIN, 16, mini(best_run, 6) + (2 if has_pair else 0), 8, best_run_ranks))
		cands.append(_cand(PatternDef.ER_LONG_TENG_FEI, 4, mini(best_run, 4) + 4, 8, best_run_ranks))
	if best_run >= 3:
		cands.append(_cand(PatternDef.SI_JI_RU_CHUN, 2, mini(best_run, 4) + 4, 8, best_run_ranks))
		cands.append(_cand(PatternDef.YONG_HENG_XIANG_SUI, 8, mini(best_run, 5) + 3, 8, best_run_ranks))
	var red := 0
	var black := 0
	for c in hand:
		if c.rank > 0:
			if c.is_red():
				red += 1
			else:
				black += 1
	var mc = maxi(red, black)
	if mc >= 5:
		cands.append(_cand(PatternDef.LIU_CHAO_JIN_FEN, 16, mc, 8, []))
		cands.append(_cand(PatternDef.WU_GU_FENG_DENG, 8, mc, 8, []))
		cands.append(_cand(PatternDef.SI_JI_FA_CAI, 4, mc, 8, []))
	cands.append(_cand(PatternDef.PING_HU, 1, mini(hand.size(), 8), 8, []))

	var best := {}
	var bs := -1.0
	for cd in cands:
		var sc = float(cd.mult) * pow(float(cd.have) / float(cd.need), 2.0)
		if sc > bs:
			bs = sc
			best = cd
	if best.is_empty():
		best = cands[cands.size() - 1]

	var keep := []
	var disc := []
	var target_ranks: Array = best.get("ranks", [])
	for c in hand:
		if target_ranks.is_empty() or target_ranks.has(c.rank):
			keep.append(c)
		else:
			disc.append(c)
	disc.sort_custom(func(a, b): return int(counts.get(a.rank, 0)) < int(counts.get(b.rank, 0)))
	var missing := int(best.need) - int(best.have)
	best["keep"] = keep
	best["disc"] = disc.slice(0, mini(2, disc.size()))
	best["missing"] = missing
	best["tip"] = str(TIPS.get(best.name, GENERAL_TIP))
	return best

static func recap_tip(hand: Array, gold_ranks: Array) -> String:
	var a = analyze(hand, gold_ranks)
	if a.is_empty():
		return GENERAL_TIP
	return "教学复盘：末手最接近【" + str(a.name) + " x" + str(a.mult) + "】(" + str(a.have) + "/" + str(a.need) + ")。" + str(a.tip)

# ---------------- 番型图鉴 ----------------

class Guide extends Control:
	const EXAMPLES := {
		"独一无二": [[14, 0], [14, 1], [14, 2], [14, 3], [14, 0], [14, 1], [14, 2], [14, 3]],
		"君临天下": [[13, 0], [13, 1], [13, 2], [13, 3], [13, 0], [13, 1], [13, 2], [13, 3]],
		"十全十美": [[10, 0], [10, 1], [10, 2], [10, 3], [10, 0], [10, 1], [10, 2], [10, 3]],
		"八方来财": [[8, 0], [8, 1], [8, 2], [8, 3], [8, 0], [8, 1], [8, 2], [8, 3]],
		"八方来贺": [[6, 1], [7, 1], [8, 1], [9, 1], [10, 1], [11, 1], [12, 1], [13, 1]],
		"顶峰相见": [[13, 0], [13, 1], [13, 2], [13, 3], [13, 0], [13, 1], [14, 2], [14, 3]],
		"心心相连": [[11, 0], [11, 1], [11, 2], [11, 3], [11, 0], [11, 1], [12, 2], [12, 3]],
		"十拿九稳": [[10, 0], [10, 1], [10, 2], [10, 3], [10, 0], [10, 1], [9, 2], [9, 3]],
		"六事兴旺": [[6, 0], [6, 1], [6, 2], [6, 3], [6, 0], [6, 1], [7, 2], [7, 3]],
		"比翼为邻": [[6, 0], [7, 0], [8, 0], [9, 0], [10, 0], [11, 0], [12, 1], [12, 2]],
		"六朝金粉": [[6, 1], [7, 1], [8, 1], [9, 1], [10, 1], [11, 1], [13, 3], [13, 3]],
		"六六大顺": [[6, 0], [7, 0], [8, 0], [9, 0], [10, 0], [11, 0], [14, 1], [14, 2]],
		"永恒相随": [[6, 0], [7, 0], [8, 0], [9, 0], [10, 0], [11, 1], [11, 2], [11, 3]],
		"五谷丰登": [[6, 1], [7, 1], [8, 1], [9, 1], [10, 1], [12, 3], [12, 3], [12, 3]],
		"二龙腾飞": [[6, 0], [7, 0], [8, 0], [9, 0], [10, 1], [11, 1], [12, 1], [13, 1]],
		"四季发财": [[6, 1], [7, 1], [8, 1], [9, 1], [10, 3], [11, 3], [12, 3], [13, 3]],
		"四季如春": [[6, 0], [7, 0], [8, 0], [9, 0], [10, 2], [11, 2], [12, 2], [13, 2]],
		"平胡": [[6, 1], [7, 1], [8, 1], [13, 0], [13, 2], [13, 3], [14, 1], [14, 2]],
	}
	const SUITS := [0, 1, 2, 3]

	func _ready() -> void:
		size = Vector2(1280, 720)
		_build()

	func _build() -> void:
		var dim = ColorRect.new()
		dim.color = Color(0, 0, 0, 0.6)
		dim.size = Vector2(1280, 720)
		add_child(dim)
		var panel = Panel.new()
		panel.size = Vector2(1000, 620)
		panel.position = Vector2(140, 50)
		var st = StyleBoxFlat.new()
		st.bg_color = Color(0.97, 0.97, 0.99, 0.98)
		st.corner_radius_top_left = 14
		st.corner_radius_top_right = 14
		st.corner_radius_bottom_left = 14
		st.corner_radius_bottom_right = 14
		st.border_color = Color(0.65, 0.6, 0.85)
		st.border_width_left = 2
		st.border_width_top = 2
		st.border_width_right = 2
		st.border_width_bottom = 2
		panel.add_theme_stylebox_override("panel", st)
		add_child(panel)

		var title = Label.new()
		title.text = "📚 番型图鉴 · 高赔率牌型追牌指南"
		title.size = Vector2(1000, 40)
		title.position = Vector2(0, 10)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 22)
		title.add_theme_color_override("font_color", Color(0.32, 0.28, 0.52))
		panel.add_child(title)

		var btn_close = Button.new()
		btn_close.text = "关闭"
		btn_close.size = Vector2(90, 34)
		btn_close.position = Vector2(890, 12)
		btn_close.pressed.connect(func(): visible = false)
		panel.add_child(btn_close)

		var scroll = ScrollContainer.new()
		scroll.size = Vector2(960, 550)
		scroll.position = Vector2(20, 56)
		panel.add_child(scroll)
		var vbox = VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(940, 0)
		vbox.size = Vector2(940, 0)
		vbox.add_theme_constant_override("separation", 10)
		scroll.add_child(vbox)

		var order = ["独一无二", "八方来贺", "顶峰相见", "比翼为邻", "六朝金粉", "六六大顺", "永恒相随", "五谷丰登", "二龙腾飞", "四季发财", "四季如春", "平胡"]
		for nm in order:
			var info = PatternDef.get_pattern_info(nm)
			vbox.add_child(_make_row(nm, int(info.multiplier), str(info.desc)))
		var gen = Label.new()
		gen.text = "💡 " + GENERAL_TIP
		gen.custom_minimum_size = Vector2(920, 44)
		gen.size = Vector2(920, 44)
		gen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gen.add_theme_font_size_override("font_size", 13)
		gen.add_theme_color_override("font_color", Color(0.7, 0.45, 0.1))
		vbox.add_child(gen)

	func _make_row(nm: String, mult: int, desc: String) -> Panel:
		var row = Panel.new()
		row.custom_minimum_size = Vector2(940, 96)
		row.size = Vector2(940, 96)
		var rs = StyleBoxFlat.new()
		rs.bg_color = Color(0.93, 0.93, 0.97, 0.9)
		rs.corner_radius_top_left = 10
		rs.corner_radius_top_right = 10
		rs.corner_radius_bottom_left = 10
		rs.corner_radius_bottom_right = 10
		row.add_theme_stylebox_override("panel", rs)
		var nm_l = Label.new()
		nm_l.text = nm
		nm_l.size = Vector2(110, 30)
		nm_l.position = Vector2(12, 10)
		nm_l.add_theme_font_size_override("font_size", 18)
		nm_l.add_theme_color_override("font_color", Color(0.25, 0.25, 0.38))
		row.add_child(nm_l)
		var mu_l = Label.new()
		mu_l.text = "x" + str(mult)
		mu_l.size = Vector2(70, 30)
		mu_l.position = Vector2(12, 42)
		mu_l.add_theme_font_size_override("font_size", 20)
		mu_l.add_theme_color_override("font_color", Color(0.85, 0.2, 0.12))
		row.add_child(mu_l)
		var ex: Array = EXAMPLES.get(nm, [])
		for i in range(mini(8, ex.size())):
			var suit_idx = int(ex[i][1])
			var suit = [Card.Suit.SPADE, Card.Suit.HEART, Card.Suit.CLUB, Card.Suit.DIAMOND][suit_idx]
			var cd = Card.new(-1, suit, int(ex[i][0]), Card.CardType.NORMAL)
			var cv = CardView.new(cd, false, Vector2(34, 48))
			cv.is_interactive = false
			cv.enable_hover = false
			cv.show_points = false
			cv.position = Vector2(130 + i * 38, 8)
			row.add_child(cv)
		var ds = Label.new()
		ds.text = desc
		ds.size = Vector2(480, 24)
		ds.position = Vector2(130, 60)
		ds.add_theme_font_size_override("font_size", 12)
		ds.add_theme_color_override("font_color", Color(0.45, 0.48, 0.58))
		row.add_child(ds)
		var tp = Label.new()
		tp.text = "追法：" + str(TIPS.get(nm, ""))
		tp.size = Vector2(790, 40)
		tp.position = Vector2(130, 60)
		tp.position = Vector2(450, 34)
		tp.size = Vector2(478, 56)
		tp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tp.add_theme_font_size_override("font_size", 12)
		tp.add_theme_color_override("font_color", Color(0.35, 0.5, 0.4))
		row.add_child(tp)
		return row
