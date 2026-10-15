import re

with open("src/ui/table_view.gd", "r", encoding="utf-8") as f:
    code = f.read()

var_setup = """var ting_label: Label
var room_title_label: Label"""

var_setup_new = """var ting_label: Label
var room_title_label: Label
var prompt_label: Label"""

code = code.replace(var_setup, var_setup_new)

label_creation = """	ting_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ting_label.add_theme_font_size_override("font_size", 13)
	ting_box.add_child(ting_label)"""

label_creation_new = """	ting_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ting_label.add_theme_font_size_override("font_size", 13)
	ting_box.add_child(ting_label)

	prompt_label = Label.new()
	prompt_label.size = Vector2(400, 30)
	prompt_label.position = Vector2(440, 395)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	add_child(prompt_label)"""

code = code.replace(label_creation, label_creation_new)

draw_sel_code = """	ting_label.text = "👉 请从牌堆或亮牌中选择一张牌"
	ting_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))"""

draw_sel_code_new = """	ting_label.text = ""
	prompt_label.text = "👉 请从牌堆或亮牌中选择一张牌"
	prompt_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))"""

code = code.replace(draw_sel_code, draw_sel_code_new)

# In _update_action_buttons we can clear it
action_buttons_code = """	btn_chi.visible = can_chi
	btn_draw.visible = can_draw"""

action_buttons_code_new = """	btn_chi.visible = can_chi
	btn_draw.visible = can_draw
	
	if can_discard:
		prompt_label.text = ""
	elif not can_chi and not can_draw and not can_discard:
		if sm and sm.state != GameStateMachine.State.AWAITING_DRAW_SELECTION:
			prompt_label.text = "" """

code = code.replace(action_buttons_code, action_buttons_code_new)

with open("src/ui/table_view.gd", "w", encoding="utf-8") as f:
    f.write(code)
