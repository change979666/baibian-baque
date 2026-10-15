class_name OpportunityDialog
extends Control

signal card_chosen(card: Card)

var panel: Panel
var title_label: Label
var cards_box: HBoxContainer
var gold_ranks: Array[int] = []

func _ready() -> void:
	size = Vector2(1280, 720)
	visible = false
	_setup_ui()

func _setup_ui() -> void:
	# Dim background
	var dim = ColorRect.new()
	dim.size = Vector2(1280, 720)
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)

	panel = Panel.new()
	panel.size = Vector2(620, 280)
	panel.position = Vector2((1280 - 620) * 0.5, 150)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.97, 0.99, 0.98)
	style.border_color = Color(0.75, 0.80, 0.88, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	title_label = Label.new()
	title_label.size = Vector2(620, 36)
	title_label.position = Vector2(0, 16)
	title_label.text = "请选择想要的牌"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.25, 0.30, 0.42))
	panel.add_child(title_label)

	var sub_label = Label.new()
	sub_label.size = Vector2(620, 24)
	sub_label.position = Vector2(0, 50)
	sub_label.text = "选中的牌直接加入手牌，其余牌按原序放回牌堆顶"
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 13)
	sub_label.add_theme_color_override("font_color", Color(0.45, 0.50, 0.58))
	panel.add_child(sub_label)

	cards_box = HBoxContainer.new()
	cards_box.position = Vector2(30, 88)
	cards_box.size = Vector2(560, 170)
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_box.add_theme_constant_override("separation", 24)
	panel.add_child(cards_box)

func show_options(options: Array[Card], p_gold_ranks: Array[int]) -> void:
	gold_ranks = p_gold_ranks
	for child in cards_box.get_children():
		child.queue_free()

	var gold_mgr = GoldManager.new(gold_ranks)
	for c in options:
		var cv = CardView.new(c, false, Vector2(110, 158))
		cv.is_gold = gold_mgr.is_gold_card(c)
		cv.card_clicked.connect(func(view: CardView):
			visible = false
			emit_signal("card_chosen", view.card)
		)
		cards_box.add_child(cv)

	visible = true
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
