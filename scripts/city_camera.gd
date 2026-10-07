extends Node3D
## Um dedo move; dois dedos aproximam e giram. Interface recebe entrada primeiro.

const MIN_DISTANCE := 25.0
const MAX_DISTANCE := 190.0
const MAP_LIMIT := 90.0
signal map_tapped(screen_position: Vector2)

var distance := 105.0
var yaw := 0.0
var pitch_degrees := 55.0
var blocked_regions: Array[Control] = []
var focus := Vector3(0, 0.5, 0)
var fingers: Dictionary = {}
var mouse_drag := false
var arm := Node3D.new()
var camera := Camera3D.new()
var build_mode := false
var touch_origins: Dictionary = {}
var had_multiple := false
var pair_baseline: Dictionary = {}


func _ready() -> void:
	add_child(arm)
	arm.rotation.x = deg_to_rad(-55)
	arm.add_child(camera)
	camera.current = true
	camera.near = 0.5
	camera.far = 600
	_apply()


func center_view() -> void:
	clear_gestures()
	focus = Vector3(0, 0.5, 0)
	distance = 105
	yaw = 0
	pitch_degrees = 55
	_apply()


func set_pitch(value: float) -> void:
	pitch_degrees = clampf(value, 25, 80)
	_apply()


func _over_interface(point: Vector2) -> bool:
	for region in blocked_regions:
		if is_instance_valid(region) and region.is_visible_in_tree():
			if region.get_global_rect().has_point(point):
				return true
	return false


func clear_gestures() -> void:
	fingers.clear()
	touch_origins.clear()
	pair_baseline.clear()
	had_multiple = false
	mouse_drag = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_gestures()


func _input(event: InputEvent) -> void:
	# Soltar sobre um botão também encerra o gesto iniciado no mapa.
	if event is InputEventScreenTouch and not event.pressed:
		if fingers.has(event.index) and touch_origins.has(event.index):
			var is_tap: bool = touch_origins[event.index].distance_to(event.position) < 16
			if is_tap and not had_multiple and not _over_interface(event.position):
				map_tapped.emit(event.position)
		fingers.erase(event.index)
		touch_origins.erase(event.index)
		pair_baseline.clear()
		if fingers.is_empty():
			had_multiple = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			mouse_drag = false


func _unhandled_input(event: InputEvent) -> void:
	# Os cliques emulados servem à GUI; o mapa usa os eventos reais de toque.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch and event.pressed:
		if _over_interface(event.position):
			return
		fingers[event.index] = event.position
		touch_origins[event.index] = event.position
		if fingers.size() >= 2:
			had_multiple = true
			_capture_pair()
	elif event is InputEventScreenDrag and fingers.has(event.index):
		if fingers.size() == 1:
			if not build_mode:
				_pan(event.position - fingers[event.index])
		elif fingers.size() == 2:
			if pair_baseline.is_empty():
				_capture_pair()
			fingers[event.index] = event.position
			_two_fingers(event)
		fingers[event.index] = event.position
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_drag = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance * 0.9, MIN_DISTANCE, MAX_DISTANCE)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance * 1.1, MIN_DISTANCE, MAX_DISTANCE)
	elif event is InputEventMouseMotion and mouse_drag:
		_pan(event.relative)
	_apply()


func _capture_pair() -> void:
	if fingers.size() != 2:
		pair_baseline.clear()
		return
	var keys := fingers.keys()
	var a: Vector2 = fingers[keys[0]]
	var b: Vector2 = fingers[keys[1]]
	pair_baseline = {"ids": keys, "vector": b - a, "center": (a + b) * 0.5,
		"distance": distance, "yaw": yaw, "pitch": pitch_degrees}


func _two_fingers(_event: InputEventScreenDrag) -> void:
	var ids: Array = pair_baseline.ids
	var a: Vector2 = fingers[ids[0]]
	var b: Vector2 = fingers[ids[1]]
	var before: Vector2 = pair_baseline.vector
	var after := b - a
	if before.length() < 12 or after.length() < 12:
		return
	distance = clampf(pair_baseline.distance * before.length() / after.length(), MIN_DISTANCE, MAX_DISTANCE)
	yaw = pair_baseline.yaw - before.angle_to(after)
	var center := (a + b) * 0.5
	pitch_degrees = clampf(pair_baseline.pitch + (center.y - pair_baseline.center.y) * 0.32, 25, 80)


func _pan(delta: Vector2) -> void:
	var move := Vector3(-delta.x, 0, -delta.y) * distance * 0.0017
	focus += move.rotated(Vector3.UP, yaw)
	focus.x = clampf(focus.x, -MAP_LIMIT, MAP_LIMIT)
	focus.z = clampf(focus.z, -MAP_LIMIT, MAP_LIMIT)


func _apply() -> void:
	position = focus
	rotation.y = yaw
	arm.rotation.x = deg_to_rad(-pitch_degrees)
	camera.position.z = distance
