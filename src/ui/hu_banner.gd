class_name HuBanner
extends Control

var panel: Panel
var pattern_label: Label
var details_label: Label
var formula_label: Label

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	visible = false
	_setup_ui()

func _setup_ui() -> void:
	panel = Panel.new()
	panel.size = Vector2(680, 160)
	panel.position = Vector2((1280 - 680) * 0.5, 230)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	style.border_color = Color(1.0, 0.82, 0.2, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	pattern_label = Label.new()
	pattern_label.size = Vector2(680, 56)
	pattern_label.position = Vector2(0, 16)
	pattern_label.text = "君临天下"
	pattern_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pattern_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pattern_label.add_theme_font_size_override("font_size", 42)
	pattern_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	panel.add_child(pattern_label)

	details_label = Label.new()
	details_label.size = Vector2(680, 30)
	details_label.position = Vector2(0, 78)
	details_label.text = "自摸 · 地胡 · 硬气"
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	details_label.add_theme_font_size_override("font_size", 18)
	details_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	panel.add_child(details_label)

	formula_label = Label.new()
	formula_label.size = Vector2(680, 30)
	formula_label.position = Vector2(0, 112)
	formula_label.text = "基础 100 倍 × 自摸 3 倍 × 金牌 2 张 = 600 倍"
	formula_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	formula_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	formula_label.add_theme_font_size_override("font_size", 16)
	formula_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	panel.add_child(formula_label)

func show_hu(winner_name: String, eval_res: HandEvaluator.HandEvalResult) -> void:
	pattern_label.text = "★ " + eval_res.pattern_name + " ★"

	var ev_text = winner_name + " 胡牌"
	if not eval_res.events.is_empty():
		ev_text += " （" + " · ".join(eval_res.events) + "）"
	details_label.text = ev_text

	var f_str = "基础 " + str(eval_res.base_multiplier) + " 倍"
	if eval_res.self_draw_multiplier > 1:
		f_str += " × 自摸 " + str(eval_res.self_draw_multiplier) + " 倍"
	if eval_res.event_multiplier > 1:
		f_str += " × 特殊 " + str(eval_res.event_multiplier) + " 倍"
	if eval_res.gold_multiplier > 1:
		f_str += " × 金牌 " + str(eval_res.gold_multiplier) + " 张"
	f_str += " = " + str(eval_res.final_multiplier) + " 倍"
	formula_label.text = f_str

	visible = true
	modulate.a = 0.0
	panel.scale = Vector2(0.8, 0.8)
	panel.pivot_offset = panel.size * 0.5

	var tween = create_tween()
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): visible = false)
