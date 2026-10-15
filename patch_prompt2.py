import re

with open("src/ui/table_view.gd", "r", encoding="utf-8") as f:
    code = f.read()

code = re.sub(r'var room_title_label: Label', 'var room_title_label: Label\nvar prompt_label: Label', code)

code = re.sub(
    r'ting_label\.add_theme_font_size_override\("font_size", 13\)\n\s*ting_box\.add_child\(ting_label\)',
    'ting_label.add_theme_font_size_override("font_size", 13)\n\tting_box.add_child(ting_label)\n\n\tprompt_label = Label.new()\n\tprompt_label.size = Vector2(400, 30)\n\tprompt_label.position = Vector2(440, 395)\n\tprompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\tprompt_label.add_theme_font_size_override("font_size", 18)\n\tprompt_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))\n\tadd_child(prompt_label)',
    code
)

code = re.sub(
    r'ting_label\.text = "[^"]+"\n\s*ting_label\.add_theme_color_override\("font_color", Color\(0\.2, 1\.0, 0\.4\)\)',
    'ting_label.text = ""\n\tprompt_label.text = "👉 请从牌堆或亮牌中选择一张牌"\n\tprompt_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))',
    code
)

code = re.sub(
    r'btn_draw\.visible = can_draw',
    'btn_draw.visible = can_draw\n\n\tif can_discard:\n\t\tprompt_label.text = ""\n\telif not can_chi and not can_draw and not can_discard:\n\t\tif sm and sm.state != GameStateMachine.State.AWAITING_DRAW_SELECTION:\n\t\t\tprompt_label.text = ""',
    code
)

with open("src/ui/table_view.gd", "w", encoding="utf-8") as f:
    f.write(code)
