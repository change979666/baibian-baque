class_name GameTiming
extends RefCounted
## 全剧表现层节奏配置（秒）。所有摸牌/出牌/AI 思考/回合切换/胡牌停顿集中于此，
## 禁止在 UI 代码里散落硬编码 timing。原则：宁可稍慢，不要过快。

const AI_BIAS := [0.0, 0.18, 0.32, 0.1] # 每个 AI 座位的固定思考偏好差（避免整齐划一）

const T := {
	"draw_duration": 0.6,      # 玩家摸牌飞入动画
	"draw_pause": 0.3,         # 摸牌完成后的停顿
	"ai_draw_duration": 0.5,   # AI 摸牌飞入动画
	"ai_think_min": 0.9,       # AI 思考最短
	"ai_think_max": 1.6,       # AI 思考最长（另加 AI_BIAS）
	"discard_duration": 0.6,   # 出牌抛掷动画（升起+落槽）
	"discard_pause": 0.45,     # 牌落桌后停顿
	"turn_pause": 0.35,        # 回合切换间隔
	"hu_pause": 0.5,           # 胡牌动作 → 特效 之间的停顿
	"flip_duration": 0.18,     # 翻牌动画
	"deal_interval": 0.22,     # 发牌每张间隔
	"deal_flight": 0.3,        # 发牌单张飞入
}
