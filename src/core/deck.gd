class_name Deck
extends RefCounted

var cards: Array[Card] = []

func _init(seed_val: int = -1) -> void:
	reset(seed_val)

func reset(seed_val: int = -1) -> void:
	cards.clear()
	var current_id: int = 0

	# 1. 72 core cards: 2 decks of ranks 6..14 across 4 suits
	for deck_idx in range(2):
		for s in [Card.Suit.SPADE, Card.Suit.HEART, Card.Suit.CLUB, Card.Suit.DIAMOND]:
			for r in range(6, 15):
				cards.append(Card.new(current_id, s, r, Card.CardType.NORMAL))
				current_id += 1

	# 2. 4 extra 8s: 1 for each suit
	for s in [Card.Suit.SPADE, Card.Suit.HEART, Card.Suit.CLUB, Card.Suit.DIAMOND]:
		cards.append(Card.new(current_id, s, 8, Card.CardType.EXTRA_EIGHT))
		current_id += 1

	# 3. 4 Wildcards
	for i in range(4):
		cards.append(Card.new(current_id, Card.Suit.NONE, 0, Card.CardType.WILD))
		current_id += 1

	# 4. 4 Opportunity cards
	for i in range(4):
		cards.append(Card.new(current_id, Card.Suit.NONE, 0, Card.CardType.OPPORTUNITY))
		current_id += 1

	# Total should be exactly 84 cards
	assert(cards.size() == 84, "Deck size must be 84 cards")

	shuffle(seed_val)

func shuffle(seed_val: int = -1) -> void:
	var rng = RandomNumberGenerator.new()
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()

	for i in range(cards.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = cards[i]
		cards[i] = cards[j]
		cards[j] = temp

func draw() -> Card:
	if cards.is_empty():
		return null
	return cards.pop_back()

func peek(count: int) -> Array[Card]:
	var result: Array[Card] = []
	var start_idx = max(0, cards.size() - count)
	for i in range(cards.size() - 1, start_idx - 1, -1):
		result.append(cards[i])
	return result

func pick_top_cards(count: int) -> Array[Card]:
	var result: Array[Card] = []
	var actual_count = min(count, cards.size())
	for i in range(actual_count):
		result.append(cards.pop_back())
	return result

func put_back_on_top(cards_to_return: Array[Card]) -> void:
	# If cards were drawn in order [C0, C1, C2], to put them back in original order:
	# the last drawn should be pushed first or in reverse.
	for i in range(cards_to_return.size() - 1, -1, -1):
		cards.append(cards_to_return[i])

func remaining_count() -> int:
	return cards.size()

func is_empty() -> bool:
	return cards.is_empty()
