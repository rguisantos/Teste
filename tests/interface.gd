extends SceneTree

var scene: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _touch(point: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _tap_at(point: Vector2) -> void:
	await _touch(point, true)
	await _touch(point, false)
	await process_frame

func _tap(button: Button) -> void:
	assert(button != null)
	await _tap_at(button.get_global_rect().get_center())

func _button(text: String) -> Button:
	for node in scene.find_children("*", "Button", true, false):
		if node.text == text:
			return node
	return null

func _run() -> void:
	root.size = Vector2i(1280, 720)
	scene = load("res://main.tscn").instantiate()
	scene.store.base_path = "user://interface_test_city.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.store.base_path + suffix))
	root.add_child(scene)
	await process_frame
	await process_frame
	await _tap(_button("Opções"))
	assert(scene.options_panel.visible)
	await _tap(_button("Sombras: sim"))
	assert(not scene.sun.shadow_enabled)
	await _tap(_button("Diagnóstico"))
	assert(scene.report_panel.visible)
	await _tap(_button("Fechar"))
	assert(not scene.report_panel.visible)
	await _touch(Vector2(400, 250), true, 0)
	await _touch(Vector2(600, 250), true, 1)
	for index in [0, 1]:
		var event := InputEventScreenDrag.new()
		event.index = index
		event.position = Vector2(400 + index * 200, 300)
		Input.parse_input_event(event)
		await process_frame
	assert(scene.city_camera.pitch_degrees > 65, "Movimento paralelo deve inclinar com os dedos")
	assert(is_equal_approx(scene.city_camera.distance, 105), "Movimento paralelo não deve alterar zoom final")
	await _touch(Vector2(400, 300), false, 0)
	await _touch(Vector2(600, 300), false, 1)
	await _tap(_button("Opções"))
	await _tap(_button("Centralizar"))
	assert(is_equal_approx(scene.city_camera.pitch_degrees, 55))
	await _tap(_button("Fechar opções"))
	await _tap(_button("Ruas"))
	await _touch(Vector2(400, 250), true, 0)
	await _touch(Vector2(600, 250), true, 1)
	await _touch(Vector2(400, 250), false, 0)
	await _touch(Vector2(600, 250), false, 1)
	assert(not scene.has_start, "Gesto com dois dedos não marca nem constrói rua")
	var camera: Camera3D = scene.city_camera.camera
	var a := Vector3(-80, scene.terrain.height_at(-80, 0), 0)
	var b := Vector3(-40, scene.terrain.height_at(-40, 0), 0)
	await _tap_at(camera.unproject_position(a))
	assert(scene.has_start, "Toque no mapa deve marcar início")
	await _tap_at(camera.unproject_position(b))
	assert(scene.has_end and not scene.confirm_button.disabled, "Toque marca prévia válida")
	assert(scene.model.cash == 100000, "Prévia não cobra obra")
	await _tap(_button("Cancelar"))
	assert(scene.model.cash == 100000 and scene.model.roads.is_empty())
	await _tap_at(camera.unproject_position(a))
	await _tap_at(camera.unproject_position(b))
	await _tap(_button("Confirmar"))
	assert(scene.model.roads.size() == 1 and scene.model.cash == 98400)
	assert(scene.store.load_city().roads.size() == 1)
	await _tap(_button("Traçado: reto"))
	assert(scene.curved)
	await _tap_at(camera.unproject_position(b))
	await _tap_at(camera.unproject_position(Vector3(0, scene.terrain.height_at(0, 24), 24)))
	assert(scene.confirm_button.disabled, "Curva aguarda o terceiro toque")
	await _tap_at(camera.unproject_position(Vector3(-32, scene.terrain.height_at(-32, 32), 32)))
	assert(not scene.confirm_button.disabled)
	assert(scene.model.cash == 98400)
	await _tap(_button("Confirmar"))
	assert(scene.model.roads.size() == 2 and scene.model.roads[1].control != null)
	assert(scene.store.load_city().roads.size() == 2)
	await _tap(_button("Navegar"))
	assert(not scene.city_camera.build_mode)
	assert(scene.city_camera.fingers.is_empty())
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.store.base_path + suffix))
	print("INTERFACE_OK: gestos, botões, prévia, cancelamento, construção e autosave")
	scene.queue_free()
	quit(0)
