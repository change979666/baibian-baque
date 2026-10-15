import re

with open("src/ui/table_view.gd", "r", encoding="utf-8") as f:
    code = f.read()

old_ui_setup = """	# Discard River (Right side of stadium)
	discard_panel = Panel.new()
	discard_panel.size = Vector2(440, 140)
	discard_panel.position = Vector2(480, 240)
	var disc_style = StyleBoxFlat.new()
	disc_style.bg_color = Color(0, 0, 0, 0.0)
	discard_panel.add_theme_stylebox_override("panel", disc_style)
	add_child(discard_panel)

	discard_container = GridContainer.new()
	discard_container.columns = 8
	discard_container.position = Vector2(10, 10)
	discard_container.size = Vector2(420, 120)
	discard_container.add_theme_constant_override("h_separation", 6)
	discard_container.add_theme_constant_override("v_separation", 6)
	discard_panel.add_child(discard_container)

	dead_pile_container = GridContainer.new()
	dead_pile_container.columns = 10
	dead_pile_container.position = Vector2(250, 10)
	dead_pile_container.size = Vector2(180, 120)
	dead_pile_container.add_theme_constant_override("h_separation", -32)
	dead_pile_container.add_theme_constant_override("v_separation", 6)
	discard_panel.add_child(dead_pile_container)

	# Physical Deck Stack (Left side of stadium)
	deck_stack_view = Control.new()
	deck_stack_view.position = Vector2(360, 245)
	deck_stack_view.size = Vector2(92, 132)
	add_child(deck_stack_view)"""

new_ui_setup = """	# Main River Capsule
	var river_bg = Panel.new()
	river_bg.size = Vector2(510, 150)
	river_bg.position = Vector2(350, 235)
	var r_style = StyleBoxFlat.new()
	r_style.bg_color = Color(0.15, 0.38, 0.28, 0.7)
	r_style.border_color = Color(0.8, 0.9, 0.5, 0.4)
	r_style.border_width_left = 3
	r_style.border_width_top = 3
	r_style.border_width_right = 3
	r_style.border_width_bottom = 3
	r_style.corner_radius_top_left = 75
	r_style.corner_radius_top_right = 75
	r_style.corner_radius_bottom_left = 75
	r_style.corner_radius_bottom_right = 75
	river_bg.add_theme_stylebox_override("panel", r_style)
	add_child(river_bg)

	# Draw 4 empty slots
	for i in range(4):
		var slot = Panel.new()
		slot.size = Vector2(92, 132)
		slot.position = Vector2(110 + i * 98, 9)
		var s_style = StyleBoxFlat.new()
		s_style.bg_color = Color(0.1, 0.3, 0.2, 0.5)
		s_style.corner_radius_top_left = 6
		s_style.corner_radius_top_right = 6
		s_style.corner_radius_bottom_left = 6
		s_style.corner_radius_bottom_right = 6
		slot.add_theme_stylebox_override("panel", s_style)
		river_bg.add_child(slot)

	# Opportunity Capsule
	var opp_bg = Panel.new()
	opp_bg.size = Vector2(110, 150)
	opp_bg.position = Vector2(870, 235)
	opp_bg.add_theme_stylebox_override("panel", r_style)
	add_child(opp_bg)

	# Keep old container variables but position them differently
	discard_panel = Panel.new()
	discard_panel.size = Vector2(1280, 720)
	discard_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(discard_panel)

	discard_container = HBoxContainer.new()
	discard_container.position = Vector2(460, 244)
	discard_container.size = Vector2(400, 132)
	discard_container.add_theme_constant_override("separation", 6)
	discard_panel.add_child(discard_container)

	dead_pile_container = GridContainer.new()
	dead_pile_container.columns = 10
	dead_pile_container.position = Vector2(879, 244)
	dead_pile_container.size = Vector2(92, 132)
	dead_pile_container.add_theme_constant_override("h_separation", -80)
	dead_pile_container.add_theme_constant_override("v_separation", 6)
	discard_panel.add_child(dead_pile_container)

	# Physical Deck Stack (Left side of stadium)
	deck_stack_view = Control.new()
	deck_stack_view.position = Vector2(366, 244)
	deck_stack_view.size = Vector2(92, 132)
	add_child(deck_stack_view)"""

code = code.replace(old_ui_setup, new_ui_setup)

code = code.replace(
"""	var river_idx = discard_container.get_child_count()
	var col = river_idx % 8
	var row = river_idx / 8
	var river_target_gpos = discard_panel.global_position + Vector2(10 + col * 54, 10 + row * 70)""",
"""	var river_idx = discard_container.get_child_count()
	var river_target_gpos = Vector2(460 + river_idx * 98, 244)"""
)

code = code.replace(
"""	var river_idx = dead_pile_container.get_child_count()
	var col = river_idx % 10
	var row = river_idx / 10
	var river_target_gpos = discard_panel.global_position + Vector2(250 + col * 16, 10 + row * 70)""",
"""	var river_idx = dead_pile_container.get_child_count()
	var river_target_gpos = Vector2(879 + (river_idx * 5), 244)"""
)

tag_setup_old = """	var action_tag = Label.new()
	action_tag.name = "ActionTag"
	action_tag.size = Vector2(48, 20)
	action_tag.position = Vector2(0, 48)
	action_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_tag.add_theme_font_size_override("font_size", 11)"""

tag_setup_new = """	var action_tag = Label.new()
	action_tag.name = "ActionTag"
	action_tag.size = Vector2(36, 36)
	action_tag.position = Vector2(50, 90)
	action_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tag_style = StyleBoxFlat.new()
	tag_style.bg_color = Color(1.0, 0.6, 0.2, 0.95)
	tag_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
	tag_style.border_width_left = 2
	tag_style.border_width_top = 2
	tag_style.border_width_right = 2
	tag_style.border_width_bottom = 2
	tag_style.corner_radius_top_left = 6
	tag_style.corner_radius_top_right = 6
	tag_style.corner_radius_bottom_left = 6
	tag_style.corner_radius_bottom_right = 6
	action_tag.add_theme_stylebox_override("normal", tag_style)
	action_tag.add_theme_font_size_override("font_size", 18)
	action_tag.add_theme_color_override("font_color", Color(1, 1, 1))
	action_tag.rotation = -0.2"""

code = code.replace(tag_setup_old, tag_setup_new)

code = code.replace(
"""	var mini = Panel.new()
	mini.custom_minimum_size = Vector2(48, 64)""",
"""	var mini = Panel.new()
	mini.custom_minimum_size = Vector2(92, 132)"""
)

code = code.replace(
"""	var label = Label.new()
	label.size = Vector2(48, 64)""",
"""	var label = Label.new()
	label.size = Vector2(92, 132)"""
)

code = code.replace(
"""	label.add_theme_font_size_override("font_size", 20)""",
"""	label.add_theme_font_size_override("font_size", 42)"""
)

with open("src/ui/table_view.gd", "w", encoding="utf-8") as f:
    f.write(code)

print("Patch complete")
