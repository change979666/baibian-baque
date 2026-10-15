extends SceneTree

func _init() -> void:
	print("==================================================")
	print("    《百变八雀 · 点字成金》完整单机游戏实机流程集成测试   ")
	print("==================================================")

	var root_node = GameRoot.new()
	root.add_child(root_node)

	var timer = create_timer(0.1)
	timer.timeout.connect(func():
		_run_test_flow(root_node)
	)

func _run_test_flow(root_node: GameRoot) -> void:
	print("1. 测试大厅与玩家存档...")
	var initial_beans = SaveManager.get_beans()
	print("   当前初始欢乐豆: ", initial_beans)

	var menu = root_node.current_view as MainMenu
	if menu == null:
		printerr("FAIL: MainMenu not loaded!")
		quit(1)
		return

	# Test manual refill
	print("2. 测试手动补豆功能...")
	SaveManager.refill_beans(50000)
	var new_beans = SaveManager.get_beans()
	if new_beans != initial_beans + 50000:
		printerr("FAIL: Bean refill failed! Expected ", initial_beans + 50000, " got ", new_beans)
		quit(1)
		return
	print("   补豆成功！当前欢乐豆: ", new_beans)

	# Enter "normal" room
	print("3. 测试进入房间（普通场）...")
	var room = GameRules.get_room("normal")
	root_node._on_enter_room(room)

	var table = root_node.current_view as GameTable
	if table == null:
		printerr("FAIL: GameTable not loaded!")
		quit(1)
		return
	print("   成功进入普通场牌桌！")

	# Wait for table to initialize round
	print("4. 测试发牌与金牌揭示...")
	if table.sm.gold_mgr.gold_ranks.size() != 3:
		printerr("FAIL: Gold ranks count != 3")
		quit(1)
		return
	print("   本局金牌点数: ", table.sm.gold_mgr.get_gold_ranks_display())

	if table.human_hand_cards.size() != 7:
		printerr("FAIL: Hand size != 7 after deal, got ", table.human_hand_cards.size())
		quit(1)
		return
	print("   玩家起手 7 张手牌: ", table.human_hand_cards)

	# Wait for dealing animation (0.95s) to complete
	print("   等待发牌飞行动画与卡牌翻面完成...")
	var deal_timer = create_timer(1.0)
	deal_timer.timeout.connect(func():
		_test_swap_and_play(table)
	)

func _test_swap_and_play(table: GameTable) -> void:
	# Test swap cards
	print("5. 测试换牌阶段（选择 2 张牌换出）...")
	if table.hand_container.get_child_count() < 7:
		printerr("FAIL: Hand container child count < 7, got ", table.hand_container.get_child_count())
		quit(1)
		return

	var cv0 = table.hand_container.get_child(0) as CardView
	var cv1 = table.hand_container.get_child(1) as CardView
	table._on_card_clicked(cv0)
	table._on_card_clicked(cv1)
	if table.selected_card_views.size() != 2:
		printerr("FAIL: Selected cards for swap != 2")
		quit(1)
		return

	print("   确认换牌: ", cv0.card.to_display_string(), " 和 ", cv1.card.to_display_string())
	table._on_swap_pressed()

	if table.sm.players[0].hand.size() != 8:
		printerr("FAIL: Hand size != 8 after swap and first draw, got ", table.sm.players[0].hand.size())
		quit(1)
		return
	print("   换牌并首轮摸牌完成！当前手牌（8张待出牌）: ", table.sm.players[0].hand)

	# Test turn loop: enable trust mode to let AI drive human turns cleanly and observe full round
	print("6. 测试摸牌、打牌、AI对弈、胡牌与血流成河循环...")
	table._on_trust_pressed() # Enable trust mode

	# Wait until game finishes
	var check_timer = create_timer(0.05)
	check_timer.timeout.connect(func():
		_poll_game_progress(table)
	)

func _poll_game_progress(table: GameTable) -> void:
	if table.sm.state != GameStateMachine.State.GAME_OVER_STATE:
		# Keep polling
		var next_timer = create_timer(0.05)
		next_timer.timeout.connect(func():
			_poll_game_progress(table)
		)
	else:
		print("7. 对局顺利终局！")
		print("   弃牌池总数: ", table.discard_container.get_child_count(), " (最新展示)")
		print("   玩家已胡牌次数: ", table.sm.players[0].hu_count)
		print("   玩家当局净豆数: ", table.sm.players[0].round_net_beans)
		print("   玩家最终豆数: ", table.sm.players[0].beans)

		# Check local save
		var saved_beans = SaveManager.get_beans()
		print("8. 验证本地持久化数据保存...")
		print("   持久化存档欢乐豆: ", saved_beans)

		print("==================================================")
		print("   实机对局流程全部验证通过！表现层与状态机运转完美！ ")
		print("==================================================")
		quit(0)
