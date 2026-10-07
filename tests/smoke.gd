extends SceneTree

const TerrainScript = preload("res://scripts/landscape.gd")
const CameraScript = preload("res://scripts/city_camera.gd")
const DiagnosticsScript = preload("res://scripts/diagnostics.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var terrain = TerrainScript.new()
	root.add_child(terrain)
	terrain.generate(42)
	var original: float = terrain.height_at(75, 65)
	terrain.generate(42)
	assert(is_equal_approx(original, terrain.height_at(75, 65)), "Mapa deve preservar a semente")
	assert(is_equal_approx(terrain.height_at(0, 0), 0.5), "Fundação deve ter área quase plana")
	terrain.generate(43)
	assert(not is_equal_approx(original, terrain.height_at(75, 65)), "Sementes diferentes devem variar relevo")
	var camera = CameraScript.new()
	root.add_child(camera)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(100, 100)
	touch.pressed = true
	camera._unhandled_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(180, 120)
	camera._unhandled_input(drag)
	assert(camera.focus.x < 0, "Arrastar deve mover o foco da câmera")
	touch.pressed = false
	camera._input(touch)
	assert(camera.fingers.is_empty(), "Soltar fora do mapa deve encerrar o gesto")
	camera.fingers = {0: Vector2(100, 100), 1: Vector2(200, 100)}
	drag.index = 1
	drag.position = Vector2(300, 100)
	camera._unhandled_input(drag)
	assert(camera.distance < 105, "Afastar dedos deve aproximar a câmera")
	assert(is_zero_approx(camera.yaw), "Pinça reta não deve girar a câmera")
	drag.position = Vector2(300, 200)
	camera._unhandled_input(drag)
	assert(not is_zero_approx(camera.yaw), "Girar os dedos deve alterar a orientação")
	camera.clear_gestures()
	camera.set_pitch(120)
	assert(is_equal_approx(camera.pitch_degrees, 80), "Inclinação respeita limite superior")
	camera.set_pitch(-10)
	assert(is_equal_approx(camera.pitch_degrees, 25), "Inclinação respeita limite inferior")
	var fake_mouse := InputEventMouseButton.new()
	fake_mouse.device = InputEvent.DEVICE_ID_EMULATION
	fake_mouse.button_index = MOUSE_BUTTON_LEFT
	fake_mouse.pressed = true
	camera._unhandled_input(fake_mouse)
	assert(not camera.mouse_drag, "Mouse emulado não deve iniciar gesto duplicado")
	camera.center_view()
	assert(is_equal_approx(camera.distance, 105), "Centralizar restaura o zoom")
	var diagnostics = DiagnosticsScript.new()
	for index in range(60):
		diagnostics.record(1.0 / 30)
	var data: Dictionary = diagnostics.snapshot(42, true, Vector2i(1280, 720))
	assert(is_equal_approx(data.fps_sample_mean, 30), "A média deve refletir quadros registrados")
	diagnostics.reset()
	assert(diagnostics.frame_ms.is_empty(), "Reiniciar não mistura sessões")
	print("SMOKE_OK: terreno, câmera e diagnóstico")
	terrain.queue_free()
	camera.queue_free()
	quit(0)
