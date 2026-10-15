import re

with open("src/ui/table_view.gd", "r", encoding="utf-8") as f:
    code = f.read()

# 1. Update _add_to_discard_river to keep 5 cards and add gui_input
pattern_add_discard = r"func _add_to_discard_river\(card: Card\) -> void:.*?discard_container\.add_child\(mini\)"
replacement_add_discard = """func _add_to_discard_river(card: Card) -> void:
	# Limit discard river to latest 5 cards
	if discard_container.get_child_count() >= 5:
		var oldest = discard_container.get_child(0)
		oldest.queue_free()

	var is_gold = sm and sm.gold_mgr and sm.gold_mgr.is_gold_card(card)
	var mini = Panel.new()
	mini.custom_minimum_size = Vector2(48, 64)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.85, 0.65, 0.15) if is_gold else Color(0.6, 0.6, 0.6)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	mini.add_theme_stylebox_override("panel", sb)

	var label = Label.new()
	label.size = Vector2(48, 64)
	label.text = card.to_display_string()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", card.get_color())
	mini.add_child(label)

	if is_gold:
		var g_tag = Label.new()
		g_tag.size = Vector2(48, 20)
		g_tag.position = Vector2(0, -6)
		g_tag.text = "金"
		g_tag.add_theme_font_size_override("font_size", 9)
		g_tag.add_theme_color_override("font_color", Color(0.85, 0.55, 0.05))
		mini.add_child(g_tag)

	mini.gui_input.connect(_on_river_card_gui_input.bind(card))
	# We also need a way to show if it's chi-able or hu-able
	var action_tag = Label.new()
	action_tag.name = "ActionTag"
	action_tag.size = Vector2(48, 20)
	action_tag.position = Vector2(0, 48)
	action_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_tag.add_theme_font_size_override("font_size", 11)
	action_tag.visible = false
	mini.add_child(action_tag)

	discard_container.add_child(mini)"""

code = re.sub(pattern_add_discard, replacement_add_discard, code, flags=re.DOTALL)

# 2. Add Deck gui_input and _on_deck_gui_input, _on_river_card_gui_input
pattern_ready = r"deck_stack_view\.add_child\(deck_badge\)"
replacement_ready = """deck_stack_view.add_child(deck_badge)
	deck_stack_view.gui_input.connect(_on_deck_gui_input)"""

code = code.replace(pattern_ready, replacement_ready)

# 3. Replace _on_draw_selection_requested and related button signals
pattern_draw_sel = r"func _on_draw_selection_requested\(seat: int\) -> void:.*?ting_label\.add_theme_color_override\(\"font_color\", Color\(0\.2, 1\.0, 0\.4\)\)"

replacement_draw_sel = """func _on_draw_selection_requested(seat: int) -> void:
	if is_trust_mode:
		var t = create_tween()
		t.tween_interval(0.5)
		t.tween_callback(func():
			sm.human_claim_chi(null) # Draw from deck in auto mode
		)
		return

	_update_action_buttons(false, false, false, false, false, false)
	ting_label.text = "👉 请从牌堆或亮牌中选择一张牌"
	ting_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	
	# Highlight river cards that can be used
	var p = sm.players[0]
	for i in range(discard_container.get_child_count()):
		var c = discard_container.get_child(i)
		var c_card = sm.discard_pile[i] if i < sm.discard_pile.size() else null
		var tag = c.get_node_or_null("ActionTag")
		if tag and c_card:
			var chi_c = HandEvaluator.get_chi_combinations(p.hand, c_card)
			if chi_c.size() > 0:
				tag.text = "吃"
				tag.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
				tag.visible = true
			else:
				tag.visible = false

func _on_deck_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if sm.state == GameStateMachine.State.AWAITING_DRAW_SELECTION:
			_hide_river_action_tags()
			sm.human_claim_chi(null) # Null means deck

func _on_river_card_gui_input(event: InputEvent, card: Card) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if sm.state == GameStateMachine.State.AWAITING_DRAW_SELECTION:
			_hide_river_action_tags()
			sm.human_claim_chi(card)

func _hide_river_action_tags() -> void:
	for c in discard_container.get_children():
		var tag = c.get_node_or_null("ActionTag")
		if tag:
			tag.visible = false"""

code = re.sub(pattern_draw_sel, replacement_draw_sel, code, flags=re.DOTALL)

with open("src/ui/table_view.gd", "w", encoding="utf-8") as f:
    f.write(code)
print("Updated table_view.gd")
