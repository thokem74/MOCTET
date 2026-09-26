extends Control

const BG := Color("#16161e")
const PANEL := Color("#1f2335")
const BORDER := Color("#414868")
const TEXT := Color("#c0caf5")
const MUTED := Color("#565f89")
const ACCENT := Color("#7aa2f7")
const PIECE_COLORS := {
	"I": Color("#7dcfff"), "J": Color("#7aa2f7"), "L": Color("#ff9e64"),
	"O": Color("#e0af68"), "S": Color("#9ece6a"), "T": Color("#bb9af7"),
	"Z": Color("#f7768e")
}

var game: MoctetGame
var music
var fall_timer := 0.0
var lock_timer := -1.0
var reset_count := 0
var paused := false
var soft_drop_held := false
var buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game = MoctetGame.new()
	music = load("res://music.gd").new()
	add_child(music)
	_build_controls()
	queue_redraw()
	set_process(true)

func _build_controls() -> void:
	for child in get_children():
		if child is Button:
			child.queue_free()
	_create_button("◀", "move_left", Vector2(20, 700))
	_create_button("▶", "move_right", Vector2(100, 700))
	_create_button("▼", "soft_drop", Vector2(60, 758))
	_create_button("⟲", "rotate_ccw", Vector2(270, 700))
	_create_button("⟳", "rotate_cw", Vector2(350, 700))
	_create_button("⤓", "hard_drop", Vector2(310, 758))
	_create_button("HOLD", "hold", Vector2(20, 816), Vector2(140, 48))
	_create_button("PAUSE", "pause", Vector2(180, 816), Vector2(140, 48))
	_create_button("RESTART", "restart", Vector2(340, 816), Vector2(140, 48))

func _create_button(label: String, action: String, base: Vector2, size := Vector2(60, 48)) -> void:
	var button := Button.new()
	button.text = label
	button.add_theme_font_size_override("font_size", 18 if label.length() < 5 else 13)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_box(PANEL))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#2d3450")))
	button.set_meta("action", action)
	if action == "soft_drop":
		button.button_down.connect(_on_soft_drop_down)
		button.button_up.connect(_on_soft_drop_up)
	else:
		button.pressed.connect(_on_action.bind(action))
	add_child(button)
	buttons.append(button)
	_layout_button(button, base, size)

func _button_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = BORDER
	box.set_border_width_all(1)
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 6
	box.corner_radius_bottom_left = 6
	box.corner_radius_bottom_right = 6
	return box

func _layout_button(button: Button, base: Vector2, button_size: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var scale := minf(viewport_size.x / 500.0, viewport_size.y / 900.0)
	var origin := Vector2((viewport_size.x - 500.0 * scale) * 0.5, maxf(0.0, viewport_size.y - 900.0 * scale))
	button.position = origin + base * scale
	button.size = button_size * scale
	button.set_meta("base", base)
	button.set_meta("button_size", button_size)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		for button in buttons:
			_layout_button(button, button.get_meta("base"), button.get_meta("button_size"))

func _on_soft_drop_down() -> void:
	soft_drop_held = true
	_on_action("soft_drop")

func _on_soft_drop_up() -> void:
	soft_drop_held = false

func _on_action(action: String) -> void:
	if action == "restart":
		game.reset()
		paused = false
		fall_timer = 0.0
		lock_timer = -1.0
		reset_count = 0
		soft_drop_held = false
		queue_redraw()
		return
	if action == "pause":
		if not game.over:
			paused = not paused
		queue_redraw()
		return
	if paused or game.over:
		return
	match action:
		"move_left": _changed(game.move(-1, 0))
		"move_right": _changed(game.move(1, 0))
		"soft_drop":
			if game.move(0, 1):
				game.score += 1
			fall_timer = 0.0
		"hard_drop":
			game.hard_drop()
			fall_timer = 0.0
			lock_timer = -1.0
		"rotate_cw": _changed(game.rotate(true))
		"rotate_ccw": _changed(game.rotate(false))
		"hold":
			if game.hold_piece():
				fall_timer = 0.0
				lock_timer = -1.0
	queue_redraw()

func _changed(changed: bool) -> void:
	if changed and lock_timer >= 0.0 and reset_count < 15:
		lock_timer = 0.0
		reset_count += 1

func _unhandled_key_input(event: InputEvent) -> void:
	if event.keycode == KEY_DOWN:
		soft_drop_held = event.pressed
		if event.pressed and not event.echo:
			_on_action("soft_drop")
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_Q or event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event.keycode == KEY_R:
		_on_action("restart")
	elif event.keycode == KEY_P:
		_on_action("pause")
	elif event.keycode == KEY_C:
		_on_action("hold")
	elif event.keycode == KEY_SPACE:
		_on_action("hard_drop")
	elif event.keycode == KEY_LEFT:
		_on_action("move_left")
	elif event.keycode == KEY_RIGHT:
		_on_action("move_right")
	elif event.keycode == KEY_DOWN:
		_on_action("soft_drop")
	elif event.keycode == KEY_UP:
		_on_action("rotate_cw")
	elif event.keycode == KEY_Z:
		_on_action("rotate_ccw")

func _process(delta: float) -> void:
	if not paused and not game.over:
		fall_timer += delta
		var fall_interval = 0.045 if soft_drop_held else game.get_interval()
		if fall_timer >= fall_interval:
			if game.move(0, 1) and soft_drop_held:
				game.score += 1
			fall_timer = 0.0
		if game.fits(null, game.x, game.y + 1):
			lock_timer = -1.0
		elif lock_timer < 0.0:
			lock_timer = 0.0
		else:
			lock_timer += delta
			if lock_timer >= 0.5:
				game.lock_piece()
				lock_timer = -1.0
				reset_count = 0
	music.tick(delta, not paused and not game.over)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var scale := minf(size.x / 500.0, size.y / 900.0)
	var origin := Vector2((size.x - 500.0 * scale) * 0.5, maxf(0.0, size.y - 900.0 * scale))
	var font := ThemeDB.fallback_font
	_draw_text(font, origin + Vector2(20, 34) * scale, "M O C T E T", 24, ACCENT, scale)
	_draw_text(font, origin + Vector2(20, 56) * scale, "TOKYO NIGHT BLOCK SESSION", 11, MUTED, scale)
	var board_rect := Rect2(origin + Vector2(110, 76) * scale, Vector2(280, 560) * scale)
	draw_style_box(_button_box(PANEL), board_rect)
	for row in MoctetGame.HEIGHT:
		for col in MoctetGame.WIDTH:
			var cell_rect := Rect2(board_rect.position + Vector2(col * 28 + 3, row * 28 + 3) * scale, Vector2(25, 25) * scale)
			var value: String = game.board[row][col]
			if not value.is_empty():
				draw_rect(cell_rect, PIECE_COLORS[value])
			else:
				draw_rect(cell_rect, Color("#1a1b26"))
				draw_rect(cell_rect, BORDER, false, 1.0 * scale)
	var ghost_y := game.ghost_y()
	if not game.over:
		for cell in game.cells(null, game.x, ghost_y):
			if cell.y >= 0:
				var ghost_rect := Rect2(board_rect.position + Vector2(cell.x * 28 + 3, cell.y * 28 + 3) * scale, Vector2(25, 25) * scale)
				draw_rect(ghost_rect, PIECE_COLORS[game.kind], false, 2.0 * scale)
		for cell in game.cells():
			if cell.y >= 0:
				var piece_rect := Rect2(board_rect.position + Vector2(cell.x * 28 + 3, cell.y * 28 + 3) * scale, Vector2(25, 25) * scale)
				draw_rect(piece_rect, PIECE_COLORS[game.kind])
	_draw_panel(font, origin + Vector2(20, 76) * scale, "HOLD", game.held, scale)
	_draw_panel(font, origin + Vector2(405, 76) * scale, "NEXT", game.queue.slice(0, 3), scale)
	_draw_text(font, origin + Vector2(20, 300) * scale, "SCORE", 12, MUTED, scale)
	_draw_text(font, origin + Vector2(20, 326) * scale, "%08d" % game.score, 20, TEXT, scale)
	_draw_text(font, origin + Vector2(405, 300) * scale, "LEVEL", 12, MUTED, scale)
	_draw_text(font, origin + Vector2(405, 326) * scale, "%02d" % game.get_level(), 20, TEXT, scale)
	_draw_text(font, origin + Vector2(20, 365) * scale, "LINES  %03d" % game.lines, 13, MUTED, scale)
	_draw_text(font, origin + Vector2(20, 665) * scale, game.notice, 11, ACCENT, scale)
	_draw_text(font, origin + Vector2(20, 685) * scale, "[ PAUSED ]" if paused else "[ SESSION OVER ]" if game.over else "[ IN FLOW ]", 14, ACCENT, scale)
	if paused or game.over:
		var overlay := Rect2(board_rect.position + Vector2(12, 250) * scale, Vector2(256, 90) * scale)
		draw_rect(overlay, Color("#24283b"))
		_draw_text(font, overlay.position + Vector2(30, 30) * scale, "PAUSED" if paused else "SESSION OVER", 22, TEXT, scale)
		_draw_text(font, overlay.position + Vector2(42, 60) * scale, "TAP RESTART TO PLAY", 11, MUTED, scale)

func _draw_panel(font: Font, at: Vector2, title: String, value, scale: float) -> void:
	_draw_text(font, at, title, 12, MUTED, scale)
	if value is String:
		_draw_piece_preview(at + Vector2(0, 20) * scale, value, scale)
	else:
		for i in min(3, value.size()):
			_draw_piece_preview(at + Vector2(0, 20 + i * 54) * scale, value[i], scale)

func _draw_piece_preview(at: Vector2, piece: String, scale: float) -> void:
	if piece.is_empty():
		_draw_text(ThemeDB.fallback_font, at, "--", 16, MUTED, scale)
		return
	for cell in MoctetGame.SHAPES[piece]:
		draw_rect(Rect2(at + Vector2(cell.x * 12, cell.y * 12) * scale, Vector2(10, 10) * scale), PIECE_COLORS[piece])

func _draw_text(font: Font, at: Vector2, text: String, font_size: int, color: Color, scale: float) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * scale), color)
