class_name PatternDef
extends RefCounted

const DU_YI_WU_ER = "独一无二"       # 8张A (x100)
const JUN_LIN_TIAN_XIA = "君临天下"   # 8张K (x100)
const SHI_QUAN_SHI_MEI = "十全十美"   # 8张10 (x100)
const BA_FANG_LAI_CAI = "八方来财"    # 8张8 (x100)
const BA_FANG_LAI_HE = "八方来贺"     # 其余8同点或8同花顺 (x50)

const DING_FENG_XIANG_JIAN = "顶峰相见" # K*6 + A*2 (x32)
const XIN_XIN_XIANG_LIAN = "心心相连"   # J*6 + Q*2 (x32)
const SHI_NA_JIU_WEN = "十拿九稳"       # 10*6 + 9*2 (x32)
const LIU_SHI_XING_WANG = "六事兴旺"   # 6*6 + 7*2 (x32)

const BI_YI_WEI_LIN = "比翼为邻"       # 6+2 相邻 (x16)
const LIU_CHAO_JIN_FEN = "六朝金粉"    # 6+2 同色 (x16)
const LIU_LIU_DA_SHUN = "六六大顺"     # 6+2 基础 (x8)

const YONG_HENG_XIANG_SUI = "永恒相随" # 5+3 相邻 (x8)
const WU_GU_FENG_DENG = "五谷丰登"     # 5+3 同色 (x8)

const ER_LONG_TENG_FEI = "二龙腾飞"    # 4+4 相邻 (x4)
const SI_JI_FA_CAI = "四季发财"        # 4+4 同色 (x4)
const SI_JI_RU_CHUN = "四季如春"       # 4+4 基础 (x2)

const PING_HU = "平胡"                 # 3+3+2 基础 (x1, 癞子禁止)

static func get_pattern_info(pattern_name: String) -> Dictionary:
	match pattern_name:
		DU_YI_WU_ER, JUN_LIN_TIAN_XIA, SHI_QUAN_SHI_MEI, BA_FANG_LAI_CAI:
			return {"name": pattern_name, "multiplier": 100, "desc": "八张同点专属顶级大番"}
		BA_FANG_LAI_HE:
			return {"name": pattern_name, "multiplier": 50, "desc": "八炸或八连同花顺"}
		DING_FENG_XIANG_JIAN, XIN_XIN_XIANG_LIAN, SHI_NA_JIU_WEN, LIU_SHI_XING_WANG:
			return {"name": pattern_name, "multiplier": 32, "desc": "特定六张与对子绝妙组合"}
		BI_YI_WEI_LIN:
			return {"name": pattern_name, "multiplier": 16, "desc": "六张组与对子点数相邻"}
		LIU_CHAO_JIN_FEN:
			return {"name": pattern_name, "multiplier": 16, "desc": "六加二全同色（全红或全黑）"}
		LIU_LIU_DA_SHUN:
			return {"name": pattern_name, "multiplier": 8, "desc": "六张组配对子"}
		YONG_HENG_XIANG_SUI:
			return {"name": pattern_name, "multiplier": 8, "desc": "五张组与三张组点数相邻"}
		WU_GU_FENG_DENG:
			return {"name": pattern_name, "multiplier": 8, "desc": "五加三全同色（全红或全黑）"}
		ER_LONG_TENG_FEI:
			return {"name": pattern_name, "multiplier": 4, "desc": "两组四张点数相邻"}
		SI_JI_FA_CAI:
			return {"name": pattern_name, "multiplier": 4, "desc": "四加四全同色（全红或全黑）"}
		SI_JI_RU_CHUN:
			return {"name": pattern_name, "multiplier": 2, "desc": "两组四张合法牌型"}
		PING_HU:
			return {"name": pattern_name, "multiplier": 1, "desc": "三加三加二基础牌型（持癞子不能胡）"}
		_:
			return {"name": "未知牌型", "multiplier": 1, "desc": ""}
