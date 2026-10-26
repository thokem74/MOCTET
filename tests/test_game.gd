extends SceneTree
const Game = preload("res://game.gd")

var failures := 0

func _initialize() -> void:
	test_seven_bag()
	test_drop_and_score()
	test_queue_advances_after_lock()
	test_reset()
	test_lines_and_level()
	test_spawn_collision()
	print("Game checks finished: %d failures" % failures)
	quit(1 if failures else 0)

func _check(condition: bool) -> void:
	if not condition:
		failures += 1
		push_error("Game check failed: " + str(get_stack()))

func test_seven_bag() -> void:
	var game := Game.new(42)
	var seen := [game.kind]
	seen.append_array(game.queue.slice(0, 6))
	_check(seen.size() == 7)
	var unique := {}
	for piece in seen:
		unique[piece] = true
	_check(unique.size() == 7)

func test_drop_and_score() -> void:
	var game := Game.new(3)
	game.spawn("O")
	_check(game.ghost_y() == 18)
	game.hard_drop()
	_check(game.score == 36)
	_check(_filled(game) == 4)

func test_queue_advances_after_lock() -> void:
	var game := Game.new(2)
	var next: String = game.queue[0]
	game.hard_drop()
	_check(game.kind == next)
	_check(game.y == 0)
	_check(_filled(game) == 4)

func test_reset() -> void:
	var game := Game.new(2)
	game.hard_drop()
	game.lines = 12
	game.over = true
	game.notice = "SESSION OVER"
	game.reset()
	_check(_filled(game) == 0)
	_check(game.score == 0 and game.lines == 0)
	_check(not game.over and game.fits())
	_check(game.x == 3 and game.y == 0)
	_check(game.queue.size() >= 7)
	_check(game.notice == "MAKE ROOM FOR WHAT'S NEXT.")

func test_lines_and_level() -> void:
	var game := Game.new(4)
	game.lines = 6
	for row_index in range(Game.HEIGHT - 4, Game.HEIGHT):
		for col in Game.WIDTH:
			game.board[row_index][col] = "T"
		game.board[row_index][5] = ""
	game.spawn("I")
	game.rotate()
	game.y = 16
	game.lock_piece()
	_check(game.lines == 10)
	_check(game.get_level() == 2)
	_check(game.score == 800)

func test_spawn_collision() -> void:
	var game := Game.new(5)
	for col in Game.WIDTH:
		game.board[0][col] = "Z"
	game.spawn("O")
	_check(game.over)

func _filled(game: MoctetGame) -> int:
	var count := 0
	for row in game.board:
		for cell in row:
			if not cell.is_empty():
				count += 1
	return count
