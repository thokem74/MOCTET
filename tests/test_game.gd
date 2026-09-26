extends RefCounted
const Game = preload("res://game.gd")

func test_seven_bag() -> void:
	var game := Game.new(42)
	var seen := [game.kind]
	seen.append_array(game.queue.slice(0, 6))
	assert(seen.size() == 7)
	assert(seen.duplicate().size() == 7)

func test_drop_and_score() -> void:
	var game := Game.new(3)
	game.spawn("O")
	assert(game.ghost_y() == 18)
	game.hard_drop()
	assert(game.score == 36)
	assert(_filled(game) == 4)

func test_hold_limit_and_reset() -> void:
	var game := Game.new(2)
	var first := game.kind
	assert(game.hold_piece())
	assert(not game.hold_piece())
	game.hard_drop()
	assert(game.hold_piece())
	assert(game.kind == first)

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
	assert(game.lines == 10)
	assert(game.get_level() == 2)
	assert(game.score == 800)

func test_spawn_collision() -> void:
	var game := Game.new(5)
	for col in Game.WIDTH:
		game.board[0][col] = "Z"
	game.spawn("O")
	assert(game.over)

func _filled(game: MoctetGame) -> int:
	var count := 0
	for row in game.board:
		for cell in row:
			if not cell.is_empty():
				count += 1
	return count
