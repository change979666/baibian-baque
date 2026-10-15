class_name BeanRefillDialog
extends Control

signal beans_refilled(new_balance: int)

var panel: Panel
var btn_relief: Button
var current_beans_label: Label

func _ready() -> void:
	size = Vector2(1280, 720)
	visible = false
	_setup_ui()

func _setup_ui() -> void:
	# Dim background
	var dim = ColorRect.new()
	dim.size = Vector2(1280, 720)
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)

	panel = Panel.new()
	panel.size = Vector2(460, 360)
	panel.position = Vector2((1280 - 460) * 0.5, (720 - 320) * 0.5)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.18, 0.98)
	style.border_color = Color(1.0, 0.8, 0.2, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var title = Label.new()
	title.size = Vector2(460, 40)
	title.position = Vector2(0, 20)
	title.text = "🪙 欢乐豆补给中心"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	panel.add_child(title)

	current_beans_label = Label.new()
	current_beans_label.size = Vector2(460, 30)
	current_beans_label.position = Vector2(0, 65)
	current_beans_label.text = "当前持有：200,000 豆"
	current_beans_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_beans_label.add_theme_font_size_override("font_size", 16)
	current_beans_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	panel.add_child(current_beans_label)

	var hint = Label.new()
	hint.size = Vector2(460, 24)
	hint.position = Vector2(0, 95)
	hint.text = "（单机测试福利：点击即可手动补充欢乐豆）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	panel.add_child(hint)

	# Buttons
	var btn_5w = _create_refill_button("+50,000 豆", 50000, Vector2(60, 135))
	panel.add_child(btn_5w)

	var btn_20w = _create_refill_button("+200,000 豆", 200000, Vector2(250, 135))
	panel.add_child(btn_20w)

	var btn_100w = _create_refill_button("+1,000,000 豆", 1000000, Vector2(155, 195))
	panel.add_child(btn_100w)

	btn_relief = Button.new()
	btn_relief.text = "💪 免费领取 200,000 救济豆"
	btn_relief.size = Vector2(250, 44)
	btn_relief.position = Vector2(105, 250)
	var rls = StyleBoxFlat.new()
	rls.bg_color = Color(0.85, 0.55, 0.08)
	rls.corner_radius_top_left = 10
	rls.corner_radius_top_right = 10
	rls.corner_radius_bottom_left = 10
	rls.corner_radius_bottom_right = 10
	btn_relief.add_theme_stylebox_override("normal", rls)
	btn_relief.add_theme_color_override("font_color", Color.WHITE)
	btn_relief.add_theme_font_size_override("font_size", 15)
	btn_relief.pressed.connect(func():
		SaveManager.refill_beans(200000)
		visible = false
	)
	btn_relief.visible = false
	panel.add_child(btn_relief)

	# Close button
	var btn_close = Button.new()
	btn_close.text = "关 闭"
	btn_close.size = Vector2(120, 38)
	btn_close.position = Vector2(170, 306)
	btn_close.pressed.connect(func(): visible = false)
	panel.add_child(btn_close)

func open() -> void:
	var b = SaveManager.get_beans()
	current_beans_label.text = "当前持有：" + _format_beans(b) + " 豆"
	btn_relief.visible = b <= 0
	visible = true

func _create_refill_button(text: String, amount: int, pos: Vector2) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.size = Vector2(150, 46)
	btn.position = pos
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(func():
		var new_b = SaveManager.refill_beans(amount)
		current_beans_label.text = "当前持有：" + _format_beans(new_b) + " 豆"
		emit_signal("beans_refilled", new_b)
	)
	return btn

func _format_beans(val: int) -> String:
	var s = str(val)
	var res = ""
	var cnt = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "," + res
	return res
