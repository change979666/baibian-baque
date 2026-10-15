import re

with open("src/ui/table_view.gd", "r", encoding="utf-8") as f:
    code = f.read()

# Let's find btn_discard setup and make it beautiful
discard_setup_old = """	btn_discard = Button.new()
	btn_discard.text = "出牌"
	btn_discard.custom_minimum_size = Vector2(90, 40)
	btn_discard.pressed.connect(_on_discard_pressed)
	actions_bar.add_child(btn_discard)"""

discard_setup_new = """	btn_discard = Button.new()
	btn_discard.text = "出牌"
	btn_discard.custom_minimum_size = Vector2(140, 50)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.98, 0.65, 0.15)
	btn_style.corner_radius_top_left = 25
	btn_style.corner_radius_top_right = 25
	btn_style.corner_radius_bottom_left = 25
	btn_style.corner_radius_bottom_right = 25
	btn_style.border_width_bottom = 4
	btn_style.border_color = Color(0.8, 0.45, 0.05)
	btn_discard.add_theme_stylebox_override("normal", btn_style)
	btn_discard.add_theme_stylebox_override("hover", btn_style)
	var btn_pressed_style = btn_style.duplicate()
	btn_pressed_style.border_width_bottom = 0
	btn_pressed_style.bg_color = Color(0.85, 0.55, 0.1)
	btn_discard.add_theme_stylebox_override("pressed", btn_pressed_style)
	btn_discard.add_theme_color_override("font_color", Color(1, 1, 1))
	btn_discard.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn_discard.add_theme_font_size_override("font_size", 24)
	btn_discard.pressed.connect(_on_discard_pressed)
	actions_bar.add_child(btn_discard)"""

if "btn_discard.text =" in code:
    # Need to regex search because of encoding diffs in the string literal
    code = re.sub(r'btn_discard = Button\.new\(\)\s+btn_discard\.text = "[^"]+"\s+btn_discard\.custom_minimum_size = Vector2\(90, 40\)\s+btn_discard\.pressed\.connect\(_on_discard_pressed\)\s+actions_bar\.add_child\(btn_discard\)', discard_setup_new, code)

with open("src/ui/table_view.gd", "w", encoding="utf-8") as f:
    f.write(code)
