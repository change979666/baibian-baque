extends SceneTree

func _init() -> void:
	print("--- TEST CARD VIEW RENDER START ---")
	var root_ctrl = Control.new()
	root_ctrl.size = Vector2(1280, 720)
	root.add_child(root_ctrl)
	
	var c1 = Card.new(1, Card.Suit.HEART, 14, Card.CardType.NORMAL) # Heart A (30分)
	var c2 = Card.new(2, Card.Suit.SPADE, 13, Card.CardType.NORMAL) # Spade K (20分)
	var c3 = Card.new(3, Card.Suit.CLUB, 8, Card.CardType.NORMAL)   # Club 8 (10分)
	var c4 = Card.new(4, Card.Suit.NONE, 0, Card.CardType.WILD)     # Wildcard
	
	var cv1 = CardView.new(c1, false)
	cv1.position = Vector2(100, 100)
	root_ctrl.add_child(cv1)
	
	var cv2 = CardView.new(c2, false)
	cv2.position = Vector2(220, 100)
	cv2.is_gold = true
	root_ctrl.add_child(cv2)
	
	var cv3 = CardView.new(c3, false)
	cv3.position = Vector2(340, 100)
	root_ctrl.add_child(cv3)
	
	var cv4 = CardView.new(c4, false)
	cv4.position = Vector2(460, 100)
	root_ctrl.add_child(cv4)
	
	await process_frame
	await process_frame
	
	print("cv1 points: ", cv1.card_points)
	print("cv2 points: ", cv2.card_points)
	print("cv3 points: ", cv3.card_points)
	print("cv4 points: ", cv4.card_points)
	
	assert(cv1.card_points == 30, "A must be 30")
	assert(cv2.card_points == 20, "K must be 20")
	assert(cv3.card_points == 10, "8 must be 10")
	assert(cv4.card_points == 10, "Wild must be 10")
	
	print("--- TEST CARD VIEW RENDER PASSED ---")
	quit(0)
