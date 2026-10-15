import re

with open("src/ui/table_view.gd", "r", encoding="utf-8") as f:
    code = f.read()

code = code.replace("var room_title_label: Label", "var room_title_label: Label\nvar prompt_label: Label")

code = code.replace(
"""	ting_label.add_theme_font_size_override("font_size", 13)
	ting_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	ting_box.add_child(ting_label)""",
"""	ting_label.add_theme_font_size_override("font_size", 13)
	ting_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	ting_box.add_child(ting_label)

	prompt_label = Label.new()
	prompt_label.size = Vector2(400, 30)
	prompt_label.position = Vector2(440, 395)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	add_child(prompt_label)"""
)

code = re.sub(
    r'ting_label\.text = "[^"]+"\n\s*ting_label\.add_theme_color_override\("font_color", Color\(0\.2, 1\.0, 0\.4\)\)',
    'ting_label.text = ""\n\tprompt_label.text = "👉 请从牌堆或亮牌中选择一张牌"\n\tprompt_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))',
    code
)

code = code.replace(
"""	btn_draw.visible = can_draw""",
"""	btn_draw.visible = can_draw
	if can_discard:
		if prompt_label:
			prompt_label.text = ""
	elif not can_chi and not can_draw and not can_discard:
		if sm and sm.state != GameStateMachine.State.AWAITING_DRAW_SELECTION:
			if prompt_label:
				prompt_label.text = "" """
)

with open("src/ui/table_view.gd", "w", encoding="utf-8") as f:
    f.write(code)
