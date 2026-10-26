extends SceneTree

var main
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(500, 900)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	_check(not Input.emulate_mouse_from_touch, "Touches must not also generate mouse clicks")

	# Exercise the real viewport input path, including two concurrent fingers.
	main.game.spawn("T")
	var start_x: int = main.game.x
	var start_y: int = main.game.y
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space, true)
	_check(main.game.y == start_y, "Space does not move the piece")
	var start_score: int = main.game.score
	_touch(0, "soft_drop", true)
	_check(main.soft_drop_held, "Soft drop starts on touch down")
	_check(main.game.y == start_y + 1, "Touch down performs exactly one drop")
	_check(main.game.score == start_score + 1, "Soft drop awards one point per cell")
	_touch(1, "move_left", true)
	_check(main.game.x == start_x - 1, "A second finger moves while drop is held")
	_check(main.soft_drop_held, "Second finger does not release drop")
	_touch(1, "move_left", false)
	_check(main.game.x == start_x - 1, "Touch release does not repeat the action")
	_check(main.soft_drop_held, "Releasing another finger preserves drop")
	var original_shape: Array = main.game.shape.duplicate()
	_touch(1, "rotate_cw", true)
	_touch(1, "rotate_cw", false)
	_check(main.game.shape != original_shape, "Clockwise rotation works while soft drop is held")
	_touch(1, "rotate_ccw", true)
	_touch(1, "rotate_ccw", false)
	_check(main.game.shape == original_shape, "Counterclockwise rotation reverses clockwise rotation")
	_check(main.soft_drop_held, "Rotating does not release the other finger's drop")
	_touch(0, "soft_drop", false, Vector2(1, 1))
	_check(not main.soft_drop_held, "Release outside the button stops drop")

	_touch(2, "soft_drop", true)
	_touch(3, "soft_drop", true)
	_touch(2, "soft_drop", false)
	_check(main.soft_drop_held, "Two fingers on drop retain independent ownership")
	_touch(3, "soft_drop", false, Vector2.INF, true)
	_check(not main.soft_drop_held, "Canceled touch stops drop")

	_touch(4, "soft_drop", true)
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = Vector2(1, 1)
	root.push_input(drag, true)
	_check(not main.soft_drop_held, "Sliding off stops a held drop")
	_touch(4, "soft_drop", false)

	_touch(5, "soft_drop", true)
	main.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not main.soft_drop_held and main.touch_buttons.is_empty(), "Focus loss clears held touches")
	_touch(5, "soft_drop", false)

	_touch(6, "soft_drop", true)
	_touch(7, "pause", true)
	_check(main.paused and not main.soft_drop_held, "Pause clears held input")
	_touch(6, "soft_drop", false)
	_touch(7, "pause", false)
	_touch(7, "pause", true)
	_touch(7, "pause", false)
	_check(not main.paused, "Pause toggles once per tap")

	# Keyboard release must not cancel a finger that still holds soft drop.
	_touch(8, "soft_drop", true)
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	main._unhandled_key_input(key)
	_check(main.soft_drop_held, "Keyboard release preserves touch hold")
	_touch(8, "soft_drop", false)

	# Desktop buttons act immediately and do not consume keyboard focus.
	var left := _button("move_left")
	start_x = main.game.x
	var mouse := InputEventMouseButton.new()
	mouse.position = left.get_global_rect().get_center()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	root.push_input(mouse, true)
	_check(main.game.x == start_x - 1, "Desktop mouse press still works")
	mouse = mouse.duplicate()
	mouse.pressed = false
	root.push_input(mouse, true)
	_check(main.game.x == start_x - 1, "Mouse release does not repeat")
	_check(root.gui_get_focus_owner() == null, "Buttons do not steal gameplay keys")

	# Hit testing follows the same viewport coordinates as the drawn controls.
	for viewport_size in [Vector2i(500, 900), Vector2i(360, 640), Vector2i(500, 1100), Vector2i(720, 1280), Vector2i(1080, 2340)]:
		root.size = viewport_size
		await process_frame
		main._on_action("restart")
		main.game.spawn("T")
		var area: Rect2 = main._layout_area()
		for button in main.buttons:
			_check(area.encloses(button.get_global_rect()), "Button stays inside viewport at %s" % viewport_size)
			for other in main.buttons:
				if button != other:
					_check(not button.get_global_rect().intersects(other.get_global_rect()), "Buttons do not overlap")
		var scale: float = main._layout_scale(area)
		var origin: Vector2 = main._layout_origin(area, scale)
		var grid := Rect2(origin + Vector2(110, 76) * scale, Vector2(280, 560) * scale)
		var first := _button("rotate_ccw").get_global_rect()
		var previous_right := first.position.x - 12.0 * scale
		for action in ["rotate_ccw", "move_left", "move_right", "rotate_cw"]:
			var button := _button(action)
			var rect := button.get_global_rect()
			_check(rect.size.is_equal_approx(Vector2(100, 80) * scale), "Top row buttons have larger touch targets")
			_check(is_equal_approx(rect.position.x - previous_right, 12.0 * scale), "Top row has 12-unit gaps in the requested order")
			_check(is_equal_approx(rect.position.y, first.position.y), "Top row buttons align")
			_check(button.get_theme_font_size("font_size") == 32, "Gameplay symbols use larger text")
			previous_right = rect.end.x
		var row_center := (first.position.x + previous_right) * 0.5
		var drop := _button("soft_drop").get_global_rect()
		_check(is_equal_approx(row_center, area.get_center().x), "Top row is horizontally centered")
		_check(is_equal_approx(drop.get_center().x, row_center), "Soft drop is centered under the row")
		_check(drop.size.is_equal_approx(Vector2(112, 72) * scale), "Soft drop has a larger touch target")
		_check(is_equal_approx(drop.position.y - first.end.y, 12.0 * scale), "Soft drop has a 12-unit gap")
		var controls_top := origin.y + 700.0 * scale
		var controls_bottom := area.end.y - 24.0 * scale
		_check(first.position.y >= controls_top, "Gameplay controls clear the grid and status text")
		_check(drop.end.y <= controls_bottom, "Gameplay controls respect the bottom safety margin")
		_check(is_equal_approx(first.position.y - controls_top, controls_bottom - drop.end.y), "Gameplay group is vertically centered in available space")
		var previous_bottom := grid.position.y
		for action in ["pause", "restart", "music"]:
			var rect := _button(action).get_global_rect()
			_check(rect.size.is_equal_approx(Vector2(90, 64) * scale), "Side buttons have larger touch targets")
			_check(_button(action).get_theme_font_size("font_size") == 15, "Side labels use larger text")
			_check(rect.position.x > grid.end.x, "Side controls stay to the right of the grid")
			_check(rect.position.y > previous_bottom, "Side controls form a stack without overlapping")
			previous_bottom = rect.end.y
		_check(is_equal_approx(previous_bottom, grid.end.y), "Side controls align with grid bottom")
		_touch(1, "music", true)
		_touch(1, "music", false)
		_check(not main.music_enabled and _button("music").text == "MUSIC OFF", "Music toggle works after resizing")
		_touch(1, "music", true)
		_touch(1, "music", false)
		_check(main.music_enabled and _button("music").text == "MUSIC ON", "Music label follows playback setting")
		start_x = main.game.x
		for tap in range(3):
			_touch(0, "move_left", true)
			_touch(0, "move_left", false, Vector2(1, 1))
		_check(main.game.x == start_x - 3, "Quick taps survive slide-off at %s" % viewport_size)
		main.game.score = 42
		main.paused = true
		_touch(2, "restart", true)
		_touch(2, "restart", false)
		_check(main.game.score == 0 and main.game.x == 3 and not main.paused, "Restart works at its resized location")
	print("Touch input checks finished: %d failures" % failures)
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _button(action: String) -> Button:
	for button in main.buttons:
		if button.get_meta("action") == action:
			return button
	return null

func _touch(index: int, action: String, pressed: bool, at := Vector2.INF, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	event.position = _button(action).get_global_rect().get_center() if at == Vector2.INF else at
	root.push_input(event, true)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
