extends SceneTree

func _init() -> void:
	print("--- TEST CHI COMBINATIONS ---")
	var c7s = Card.new(1, Card.Suit.SPADE, 7, Card.CardType.NORMAL)
	var c9s = Card.new(2, Card.Suit.SPADE, 9, Card.CardType.NORMAL)
	var c8h = Card.new(3, Card.Suit.HEART, 8, Card.CardType.NORMAL)
	var c8d = Card.new(4, Card.Suit.DIAMOND, 8, Card.CardType.NORMAL)
	var wild = Card.new(5, Card.Suit.NONE, 0, Card.CardType.WILD)

	var target_8s = Card.new(6, Card.Suit.SPADE, 8, Card.CardType.NORMAL)

	var hand: Array[Card] = [c7s, c9s, c8h, c8d]

	var combos = HandEvaluator.get_chi_combinations(hand, target_8s)
	print("Found combos for 8s: ", combos.size())
	for cb in combos:
		print("  - ", cb["type"], ": ", cb["name"])
	assert(combos.size() == 2, "Expected 2 combos: set of 8s and spade flush run 7-8-9")
	assert(HandEvaluator.can_chi(hand, target_8s) == true)

	var target_6h = Card.new(7, Card.Suit.HEART, 6, Card.CardType.NORMAL)
	assert(HandEvaluator.can_chi([c8h, c8d], target_6h) == false)

	print("--- CHI TEST PASSED! ---")
	quit(0)
