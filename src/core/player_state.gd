class_name PlayerState
extends RefCounted

var seat_idx: int = 0
var name: String = ""
var is_human: bool = false
var beans: int = 200000
var starting_beans: int = 200000
var hand: Array[Card] = []
var has_hu: bool = false
var hu_count: int = 0
var auto_hu: bool = false
var swap_selected: Array[Card] = []
var round_net_beans: int = 0
var avatar_index: int = 0
var is_bankrupt: bool = false

func _init(p_seat: int, p_name: String, p_is_human: bool, p_beans: int, p_avatar: int = 0) -> void:
	seat_idx = p_seat
	name = p_name
	is_human = p_is_human
	beans = p_beans
	starting_beans = p_beans
	avatar_index = p_avatar
	hand = []
	has_hu = false
	hu_count = 0
	auto_hu = false
	swap_selected = []
	round_net_beans = 0
	is_bankrupt = (beans <= 0)

func reset_for_round() -> void:
	hand.clear()
	has_hu = false
	hu_count = 0
	auto_hu = false
	swap_selected.clear()
	round_net_beans = 0
	starting_beans = beans
	is_bankrupt = (beans <= 0)

func add_card(card: Card) -> void:
	if card != null:
		hand.append(card)

func remove_card(card: Card) -> bool:
	for i in range(hand.size()):
		if hand[i].id == card.id:
			hand.remove_at(i)
			return true
	return false

func remove_card_by_id(card_id: int) -> Card:
	for i in range(hand.size()):
		if hand[i].id == card_id:
			var c = hand[i]
			hand.remove_at(i)
			return c
	return null

func sort_hand() -> void:
	hand.sort_custom(func(a: Card, b: Card):
		# Priority: Wildcard -> Normal/Extra (sorted by rank, then suit) -> Opportunity
		if a.is_wild() and not b.is_wild():
			return true
		if not a.is_wild() and b.is_wild():
			return false
		if a.is_opportunity() and not b.is_opportunity():
			return false
		if not a.is_opportunity() and b.is_opportunity():
			return true
		if a.rank != b.rank:
			return a.rank < b.rank
		return a.suit < b.suit
	)

func count_wilds() -> int:
	var count = 0
	for c in hand:
		if c.is_wild():
			count += 1
	return count

func has_opportunity() -> bool:
	for c in hand:
		if c.is_opportunity():
			return true
	return false
