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
var keyboard_soft_drop_held := false
var mouse_soft_drop_held := false
var touch_buttons: Dictionary = {}
var music_enabled := true
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
	buttons.clear()
	for button: Button in $GameplayControls.get_children():
		_configure_button(button, button.get_meta("action"), button.position, button.size, true)
	_create_button("PAUSE", "pause", Vector2(400, 420), Vector2(90, 64), false)
	_create_button("RESTART", "restart", Vector2(400, 496), Vector2(90, 64), false)
	_create_button("MUSIC ON" if music_enabled else "MUSIC OFF", "music", Vector2(400, 572), Vector2(90, 64), false)

func _create_button(label: String, action: String, base: Vector2, size := Vector2(100, 80), gameplay_group := true) -> void:
	var button := Button.new()
	button.text = label
	add_child(button)
	_configure_button(button, action, base, size, gameplay_group)

func _configure_button(button: Button, action: String, base: Vector2, size: Vector2, gameplay_group: bool) -> void:
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 32 if gameplay_group else 15)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_box(PANEL))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#2d3450")))
	button.set_meta("action", action)
	button.set_meta("gameplay_group", gameplay_group)
	if action == "soft_drop":
		button.button_down.connect(_on_soft_drop_down)
		button.button_up.connect(_on_soft_drop_up)
	else:
		button.pressed.connect(_on_action.bind(action))
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
	var area := _layout_area()
	var scale := _layout_scale(area)
	var origin := _layout_origin(area, scale)
	if button.get_meta("gameplay_group"):
		# Keep row positions local to the scene-authored gameplay group.
		$GameplayControls.position = _gameplay_origin(area, scale)
		origin = Vector2.ZERO
	button.position = origin + base * scale
	button.scale = Vector2.ONE * scale
	button.size = button_size
	button.set_meta("base", base)
	button.set_meta("button_size", button_size)

func _layout_area() -> Rect2:
	var area := get_viewport_rect()
	if OS.get_name() == "Android":
		# Android exports draw edge to edge. Convert physical safe-area pixels
		# into the stretched viewport's coordinates before laying out content.
		var screen_size := Vector2(DisplayServer.screen_get_size())
		var safe_area := Rect2(DisplayServer.get_display_safe_area())
		if screen_size.x > 0 and screen_size.y > 0 and safe_area.has_area():
			var ratio := area.size / screen_size
			area = area.intersection(Rect2(safe_area.position * ratio, safe_area.size * ratio))
	return area

func _layout_scale(area: Rect2) -> float:
	return minf(area.size.x / 500.0, area.size.y / 900.0)

func _layout_origin(area: Rect2, scale: float) -> Vector2:
	return area.position + Vector2((area.size.x - 500.0 * scale) * 0.5, 0)

func _gameplay_origin(area: Rect2, scale: float) -> Vector2:
	var origin := _layout_origin(area, scale)
	# Reserve space for status text below the grid and a safe bottom margin.
	var top := origin.y + 700.0 * scale
	var bottom := area.end.y - 24.0 * scale
	return Vector2(origin.x, (top + bottom - 164.0 * scale) * 0.5)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_held_inputs()
	if what == NOTIFICATION_RESIZED:
		for button in buttons:
			_layout_button(button, button.get_meta("base"), button.get_meta("button_size"))

func _on_soft_drop_down() -> void:
	mouse_soft_drop_held = true
	_update_soft_drop()
	_on_action("soft_drop")

func _on_soft_drop_up() -> void:
	mouse_soft_drop_held = false
	_update_soft_drop()

# Handle each finger separately before GUI input. Mouse emulation can only
# represent one finger, and a release outside a Button can discard a quick tap.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_release_touch(event.index)
			for button in buttons:
				if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
					touch_buttons[event.index] = button
					button.add_theme_stylebox_override("normal", _button_box(Color("#2d3450")))
					_update_soft_drop()
					_on_action(button.get_meta("action"))
					break
		else:
			_release_touch(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if touch_buttons.has(event.index):
			var button: Button = touch_buttons[event.index]
			if not button.get_global_rect().has_point(event.position):
				_release_touch(event.index)
		get_viewport().set_input_as_handled()

func _release_touch(index: int) -> void:
	if not touch_buttons.has(index):
		return
	var button: Button = touch_buttons[index]
	touch_buttons.erase(index)
	if not touch_buttons.values().has(button):
		button.add_theme_stylebox_override("normal", _button_box(PANEL))
	_update_soft_drop()

func _update_soft_drop() -> void:
	soft_drop_held = keyboard_soft_drop_held or mouse_soft_drop_held
	for button in touch_buttons.values():
		if button.get_meta("action") == "soft_drop":
			soft_drop_held = true

func _clear_held_inputs() -> void:
	keyboard_soft_drop_held = false
	mouse_soft_drop_held = false
	for index in touch_buttons.keys():
		_release_touch(index)
	_update_soft_drop()

func _on_action(action: String) -> void:
	if action == "restart":
		game.reset()
		paused = false
		fall_timer = 0.0
		lock_timer = -1.0
		reset_count = 0
		_clear_held_inputs()
		queue_redraw()
		return
	if action == "music":
		music_enabled = not music_enabled
		music.set_enabled(music_enabled)
		for button in buttons:
			if button.get_meta("action") == "music":
				button.text = "MUSIC ON" if music_enabled else "MUSIC OFF"
		queue_redraw()
		return
	if action == "pause":
		if not game.over:
			paused = not paused
			_clear_held_inputs()
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
		"rotate_cw": _changed(game.rotate(true))
		"rotate_ccw": _changed(game.rotate(false))
	queue_redraw()

func _changed(changed: bool) -> void:
	if changed and lock_timer >= 0.0 and reset_count < 15:
		lock_timer = 0.0
		reset_count += 1

func _unhandled_key_input(event: InputEvent) -> void:
	if event.keycode == KEY_DOWN:
		keyboard_soft_drop_held = event.pressed
		_update_soft_drop()
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
	elif event.keycode == KEY_LEFT:
		_on_action("move_left")
	elif event.keycode == KEY_RIGHT:
		_on_action("move_right")
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
	var area := _layout_area()
	var scale := _layout_scale(area)
	var origin := _layout_origin(area, scale)
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
	_draw_next(font, origin + Vector2(405, 140) * scale, scale)
	_draw_counter(font, origin + Vector2(10, 76) * scale, "SCORE", game.score, scale)
	_draw_counter(font, origin + Vector2(10, 140) * scale, "LINES", game.lines, scale)
	_draw_text(font, origin + Vector2(405, 76) * scale, "LEVEL", 12, MUTED, scale)
	_draw_text(font, origin + Vector2(405, 102) * scale, "%02d" % game.get_level(), 20, TEXT, scale)
	_draw_text(font, origin + Vector2(20, 665) * scale, game.notice, 11, ACCENT, scale)
	_draw_text(font, origin + Vector2(20, 685) * scale, "[ PAUSED ]" if paused else "[ SESSION OVER ]" if game.over else "[ IN FLOW ]", 14, ACCENT, scale)
	if paused or game.over:
		var overlay := Rect2(board_rect.position + Vector2(12, 250) * scale, Vector2(256, 90) * scale)
		draw_rect(overlay, Color("#24283b"))
		_draw_text(font, overlay.position + Vector2(30, 30) * scale, "PAUSED" if paused else "SESSION OVER", 22, TEXT, scale)
		_draw_text(font, overlay.position + Vector2(42, 60) * scale, "TAP RESTART TO PLAY", 11, MUTED, scale)

func _draw_counter(font: Font, at: Vector2, label: String, value: int, scale: float) -> void:
	_draw_text(font, at, label, 12, MUTED, scale)
	_draw_text(font, at + Vector2(0, 26) * scale, "%08d" % value, 20, TEXT, scale)

func _draw_next(font: Font, at: Vector2, scale: float) -> void:
	_draw_text(font, at, "NEXT", 12, MUTED, scale)
	for i in min(3, game.queue.size()):
		_draw_piece_preview(at + Vector2(0, 20 + i * 54) * scale, game.queue[i], scale)

func _draw_piece_preview(at: Vector2, piece: String, scale: float) -> void:
	for cell in MoctetGame.SHAPES[piece]:
		draw_rect(Rect2(at + Vector2(cell.x * 12, cell.y * 12) * scale, Vector2(10, 10) * scale), PIECE_COLORS[piece])

func _draw_text(font: Font, at: Vector2, text: String, font_size: int, color: Color, scale: float) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * scale), color)
