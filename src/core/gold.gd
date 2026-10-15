class_name GoldManager
extends RefCounted

var gold_ranks: Array[int] = []

func _init(p_ranks: Array[int] = []) -> void:
	if p_ranks.size() == 3:
		gold_ranks = p_ranks.duplicate()

func roll_gold_ranks(rng: RandomNumberGenerator = null) -> Array[int]:
	var available: Array[int] = [6, 7, 8, 9, 10, 11, 12, 13, 14]
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	# Shuffle available ranks and pick first 3
	for i in range(available.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = available[i]
		available[i] = available[j]
		available[j] = tmp

	gold_ranks = [available[0], available[1], available[2]]
	gold_ranks.sort()
	return gold_ranks

func is_gold_rank(rank: int) -> bool:
	return gold_ranks.has(rank)

func is_gold_card(card: Card) -> bool:
	if card == null:
		return false
	if card.is_wild():
		return true
	return is_gold_rank(card.rank)

func count_gold_cards(cards: Array[Card]) -> int:
	var count: int = 0
	for card in cards:
		if is_gold_card(card):
			count += 1
	return count

func get_gold_multiplier(cards: Array[Card]) -> int:
	var count = count_gold_cards(cards)
	return max(1, count)

func get_gold_ranks_display() -> String:
	var names: Array[String] = []
	for r in gold_ranks:
		match r:
			11: names.append("J")
			12: names.append("Q")
			13: names.append("K")
			14: names.append("A")
			_: names.append(str(r))
	return " / ".join(names)
