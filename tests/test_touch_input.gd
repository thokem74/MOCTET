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
	_touch(0, "soft_drop", true)
	_check(main.soft_drop_held, "Soft drop starts on touch down")
	_check(main.game.y == start_y + 1, "Touch down performs exactly one drop")
	_touch(1, "move_left", true)
	_check(main.game.x == start_x - 1, "A second finger moves while drop is held")
	_check(main.soft_drop_held, "Second finger does not release drop")
	_touch(1, "move_left", false)
	_check(main.game.x == start_x - 1, "Touch release does not repeat the action")
	_check(main.soft_drop_held, "Releasing another finger preserves drop")
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
	for viewport_size in [Vector2i(500, 1100), Vector2i(720, 1280)]:
		root.size = viewport_size
		await process_frame
		main._on_action("restart")
		main.game.spawn("T")
		start_x = main.game.x
		for tap in range(3):
			_touch(0, "move_left", true)
			_touch(0, "move_left", false, Vector2(1, 1))
		_check(main.game.x == start_x - 3, "Quick taps survive slide-off at %s" % viewport_size)
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
