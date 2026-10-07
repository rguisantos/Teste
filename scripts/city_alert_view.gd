extends Control
const Icons=preload("res://scripts/problem_icons.gd")
var entries:Array[Dictionary]=[]
var camera_rig
var bounds:Array[Dictionary]=[]
var styles:Array[StyleBoxFlat]=[]
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for color in [Color(0.76,0.63,0.92),Color(1.0,0.72,0.33),Color(0.87,0.36,0.30)]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color(0.04,0.07,0.10,0.96)
		style.set_corner_radius_all(8)
		style.set_border_width_all(1)
		style.border_color=color
		styles.append(style)
func update_entries(values:Array[Dictionary])->void:
	entries=values
	queue_redraw()
func _process(_delta:float)->void:
	if visible and not entries.is_empty(): queue_redraw()
func project()->void:
	bounds.clear()
	if not is_instance_valid(camera_rig): return
	for entry in entries:
		var world:=Vector3(entry.x,entry.height+5.6,entry.z)
		if camera_rig.camera.is_position_behind(world): continue
		var point:Vector2=camera_rig.camera.unproject_position(world)
		if not get_viewport_rect().grow(-18).has_point(point) or camera_rig._over_interface(point): continue
		var count_value:=mini(3,entry.issues.size())
		var width_value:float=count_value*30+8+(18 if entry.issues.size()>3 else 0)
		var rect:=Rect2(point-Vector2(width_value/2,18),Vector2(width_value,36))
		bounds.append({"rect":rect,"target":entry})
func _draw()->void:
	project()
	for value in bounds:
		var rect:Rect2=value.rect
		var entry:Dictionary=value.target
		draw_style_box(styles[int(entry.severity)],rect)
		for i in range(mini(3,entry.issues.size())):
			draw_texture_rect(Icons.texture(entry.issues[i].code),Rect2(rect.position+Vector2(4+i*30,4),Vector2(28,28)),false)
		if entry.issues.size()>3:
			draw_string(get_theme_default_font(),rect.position+Vector2(rect.size.x-17,24),"+",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
func pick(point:Vector2)->Dictionary:
	if not visible: return {}
	project()
	var selected:Dictionary={}
	var distance_value:=INF
	for value in bounds:
		var rect:Rect2=value.rect
		if rect.grow(6).has_point(point):
			var candidate:float=point.distance_to(rect.get_center())
			if candidate<distance_value:
				selected=value.target
				distance_value=candidate
	return selected
