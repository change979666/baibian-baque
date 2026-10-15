class_name Card
extends RefCounted

enum Suit { SPADE = 0, HEART = 1, CLUB = 2, DIAMOND = 3, NONE = 4 }
enum CardType { NORMAL = 0, EXTRA_EIGHT = 1, WILD = 2, OPPORTUNITY = 3 }

var id: int = -1
var suit: int = Suit.NONE
var rank: int = 0  # 6..14 for ranks 6..A; 0 for wild/opportunity
var card_type: int = CardType.NORMAL

func _init(p_id: int = -1, p_suit: int = Suit.NONE, p_rank: int = 0, p_type: int = CardType.NORMAL) -> void:
	id = p_id
	suit = p_suit
	rank = p_rank
	card_type = p_type

func is_wild() -> bool:
	return card_type == CardType.WILD

func is_opportunity() -> bool:
	return card_type == CardType.OPPORTUNITY

func is_red() -> bool:
	return suit == Suit.HEART or suit == Suit.DIAMOND

func is_black() -> bool:
	return suit == Suit.SPADE or suit == Suit.CLUB

func get_base_score() -> int:
	if is_wild():
		return 10
	if is_opportunity():
		return 0
	return rank  # 6..14 for 6..A

## 【仅展示用】牌面点：A=30 / JQK=20 / 6~10=10，对应官方牌面角标视觉。
## 不参与任何结算！结算分请使用 get_base_score() / Scoring.card_score()（rank 原值）。
func get_point_value() -> int:
	if is_wild():
		return 10
	if is_opportunity():
		return 0
	if rank == 14: # A
		return 30
	elif rank in [11, 12, 13]: # J, Q, K
		return 20
	elif rank >= 6 and rank <= 10:
		return 10
	return 0

static func get_rank_name(r: int) -> String:
	match r:
		11: return "J"
		12: return "Q"
		13: return "K"
		14: return "A"
		_: return str(r)

func get_rank_str() -> String:
	if is_wild():
		return "🃏"
	if is_opportunity():
		return "🎁"
	match rank:
		11: return "J"
		12: return "Q"
		13: return "K"
		14: return "A"
		_: return str(rank)

func get_suit_symbol() -> String:
	match suit:
		Suit.SPADE: return "♠"
		Suit.HEART: return "♥"
		Suit.CLUB: return "♣"
		Suit.DIAMOND: return "♦"
		_: return ""

func get_suit_color() -> Color:
	if is_wild():
		return Color(0.7, 0.3, 0.9) # Purple
	if is_opportunity():
		return Color(1.0, 0.6, 0.1) # Orange/Gold
	if is_red():
		return Color(0.85, 0.15, 0.15) # Red
	return Color(0.12, 0.12, 0.14) # Black

func to_display_string() -> String:
	if is_wild():
		return "🃏癞子"
	if is_opportunity():
		return "🎁机会"
	return get_suit_symbol() + get_rank_str()

func clone() -> Card:
	return Card.new(id, suit, rank, card_type)

func _to_string() -> String:
	return to_display_string()
