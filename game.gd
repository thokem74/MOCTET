class_name MoctetGame
extends RefCounted

const WIDTH := 10
const HEIGHT := 20
const KINDS := ["I", "J", "L", "O", "S", "T", "Z"]
const SHAPES := {
	"I": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
	"J": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	"L": [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	"O": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
	"S": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"T": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	"Z": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]
}

var rng := RandomNumberGenerator.new()
var board: Array = []
var queue: Array[String] = []
var kind := "T"
var shape: Array = []
var x := 3
var y := 0
var held := ""
var hold_used := false
var score := 0
var lines := 0
var over := false
var notice := "MAKE ROOM FOR WHAT'S NEXT."

func _init(seed_value := -1):
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for row in HEIGHT:
		board.append([])
		for col in WIDTH:
			board[row].append("")
	refill()
	spawn()

func get_level() -> int:
	return lines / 10 + 1

func get_interval() -> float:
	return maxf(0.065, 0.8 * pow(0.8, get_level() - 1))

func refill() -> void:
	while queue.size() < 7:
		var bag := KINDS.duplicate()
		bag.shuffle()
		queue.append_array(bag)

func spawn(next_kind := "") -> void:
	if next_kind.is_empty():
		kind = queue.pop_front()
	else:
		kind = next_kind
	refill()
	shape = SHAPES[kind].duplicate()
	x = 3
	y = 0
	if not fits():
		over = true

func cells(test_shape = null, test_x := -999, test_y := -999) -> Array:
	var use_shape = shape if test_shape == null else test_shape
	var use_x = x if test_x == -999 else test_x
	var use_y = y if test_y == -999 else test_y
	var result := []
	for cell in use_shape:
		result.append(Vector2i(use_x + cell.x, use_y + cell.y))
	return result

func fits(test_shape = null, test_x := -999, test_y := -999) -> bool:
	for cell in cells(test_shape, test_x, test_y):
		if cell.x < 0 or cell.x >= WIDTH or cell.y >= HEIGHT:
			return false
		if cell.y >= 0 and not board[cell.y][cell.x].is_empty():
			return false
	return true

func move(dx: int, dy: int) -> bool:
	if over or not fits(null, x + dx, y + dy):
		return false
	x += dx
	y += dy
	return true

func rotate(clockwise := true) -> bool:
	if over or kind == "O":
		return false
	var size := 4 if kind == "I" else 3
	var rotated := []
	for cell in shape:
		rotated.append(Vector2i(size - 1 - cell.y, cell.x) if clockwise else Vector2i(cell.y, size - 1 - cell.x))
	var kicks = [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -1), Vector2i(0, -2)]
	for kick in kicks:
		if fits(rotated, x + kick.x, y + kick.y):
			shape = rotated
			x += kick.x
			y += kick.y
			return true
	return false

func ghost_y() -> int:
	var target := y
	while fits(null, x, target + 1):
		target += 1
	return target

func hard_drop() -> void:
	if over:
		return
	var target := ghost_y()
	score += (target - y) * 2
	y = target
	lock_piece()

func lock_piece() -> void:
	if over:
		return
	for cell in cells():
		if cell.y < 0:
			over = true
			return
	for cell in cells():
		board[cell.y][cell.x] = kind
	var remaining := []
	for row in board:
		if not _row_full(row):
			remaining.append(row)
	var cleared := HEIGHT - remaining.size()
	for i in cleared:
		remaining.push_front(_empty_row())
	board = remaining
	score += [0, 100, 300, 500, 800][cleared] * get_level()
	lines += cleared
	if cleared > 0:
		notice = ["", "SINGLE / CLEAN", "DOUBLE / FLOW", "TRIPLE / SYNC", "TETRIS / PERFECT"][cleared]
	hold_used = false
	spawn()

func _row_full(row: Array) -> bool:
	for value in row:
		if value.is_empty():
			return false
	return true

func _empty_row() -> Array:
	var row := []
	for col in WIDTH:
		row.append("")
	return row

func hold_piece() -> bool:
	if over or hold_used:
		return false
	var old := held
	held = kind
	spawn(old)
	hold_used = true
	return true

func reset() -> void:
	board.clear()
	queue.clear()
	held = ""
	hold_used = false
	score = 0
	lines = 0
	over = false
	notice = "MAKE ROOM FOR WHAT'S NEXT."
	for row in HEIGHT:
		board.append(_empty_row())
	refill()
	spawn()
