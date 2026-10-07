extends Node3D

var terrain: Node3D
var built := Node3D.new()
var preview: MeshInstance3D
var marker: MeshInstance3D
var last_build_ms := 0.0
var last_triangle_count := 0


func _ready() -> void:
	add_child(built)


func _mesh(roads: Array[Dictionary], preview_grade = null, width: float = 7.0, elevation: float = 0.15) -> ArrayMesh:
	var points := preload("res://scripts/road_surface.gd").triangles(preload("res://scripts/road_surface.gd").polygons(roads,width))
	if points.is_empty():
		return null
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in points:
		surface.set_normal(Vector3.UP)
		var height: float = terrain.road_height_at(point.x, point.y) if preview_grade == null else preview_grade.road_height(point, terrain.natural_height_at(point.x, point.y))
		surface.add_vertex(Vector3(point.x, height + elevation, point.y))
	surface.index()
	return surface.commit()


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if color.a < 1:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func rebuild(roads: Array[Dictionary]) -> void:
	var started := Time.get_ticks_usec()
	last_triangle_count = 0
	terrain.clear_roads(roads)
	for child in built.get_children():
		built.remove_child(child)
		child.queue_free()
	var paved:Array[Dictionary]=[]
	for road in roads:
		if road.get("surface","dirt")=="asphalt": paved.append(road)
	# Calçadas cabem no recuo de 4,6 m já reservado pelos lotes.
	# A pista de todas as ruas cobre a base nas junções, mantendo as travessias livres.
	_add_surface(paved,9.0,0.12,Color(0.65,0.65,0.61))
	_add_surface(roads,7.0,0.15,Color(0.50,0.32,0.18))
	_add_surface(paved,7.0,0.18,Color(0.16,0.19,0.21))
	_paint_crossings(roads)
	last_build_ms = (Time.get_ticks_usec() - started) / 1000.0


func clear_preview() -> void:
	if is_instance_valid(preview):
		remove_child(preview)
		preview.queue_free()
	if is_instance_valid(marker):
		remove_child(marker)
		marker.queue_free()
	preview = null
	marker = null


func show_start(point: Vector2) -> void:
	clear_preview()
	marker = MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 1.8
	shape.height = 3.6
	marker.mesh = shape
	marker.material_override = _material(Color(1, 0.8, 0.15, 0.9))
	marker.position = Vector3(point.x, terrain.height_at(point.x, point.y) + 1, point.y)
	add_child(marker)


func show_preview(a: Vector2, b: Vector2, valid: bool, control = null, width: float = 7.0) -> void:
	show_start(a)
	if a == b:
		return
	preview = MeshInstance3D.new()
	var candidate := {"points": preload("res://scripts/streets_model.gd").path(a, b, control), "a": a, "b": b, "control": control}
	var proposed: Array[Dictionary] = terrain.road_clearings.duplicate()
	proposed.append(candidate)
	var preview_grade = preload("res://scripts/road_grade.gd").new()
	preview_grade.build(proposed, terrain.natural_height_at)
	preview.mesh = _mesh([candidate], preview_grade,width)
	preview.material_override = _material(Color(0.25, 0.90, 0.50, 0.7) if valid else Color(1, 0.2, 0.2, 0.7))
	preview.position.y = 0.10
	add_child(preview)


func _add_surface(roads:Array[Dictionary], width:float, elevation:float, color:Color)->void:
	if roads.is_empty(): return
	var node:=MeshInstance3D.new()
	node.mesh=_mesh(roads,null,width,elevation)
	if node.mesh==null: node.free();return
	last_triangle_count+=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
	node.material_override=_material(color)
	built.add_child(node)

func show_upgrade(target:Dictionary,valid:bool)->void:
	clear_preview()
	if target.is_empty(): return
	preview=MeshInstance3D.new()
	preview.mesh=_mesh([target],null,9.0,0.30)
	preview.material_override=_material(Color(0.2,0.8,0.65,0.6) if valid else Color(1,0.2,0.2,0.65))
	add_child(preview)


func _paint_crossings(roads:Array[Dictionary])->void:
	var network=preload("res://scripts/streets_model.gd").new()
	network.roads=roads
	network.rebuild_graph()
	var routes=preload("res://scripts/citizen_routes.gd").new()
	routes.rebuild(network)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=0
	for crossing in routes.crossings:
		var center:Vector2=(crossing[0]+crossing[1])*0.5
		var paved:=false
		for road in roads:
			if road.get("surface","dirt")!="asphalt": continue
			for i in range(road.points.size()-1):
				if center.distance_to(Geometry2D.get_closest_point_to_segment(center,road.points[i],road.points[i+1]))<0.1: paved=true
		if not paved: continue
		var direction:Vector2=(crossing[1]-crossing[0]).normalized()
		var normal:=Vector2(-direction.y,direction.x)*0.85
		for i in range(1,8):
			var p:Vector2=crossing[0]+direction*float(i)
			var q:=p+direction*0.42
			for point in [p-normal,p+normal,q-normal,q-normal,p+normal,q+normal]:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(Vector3(point.x,terrain.road_height_at(point.x,point.y)+0.22,point.y))
				count+=1
	if count==0:return
	surface.index()
	var node:=MeshInstance3D.new()
	node.mesh=surface.commit()
	node.material_override=_material(Color(0.9,0.88,0.76))
	# Marcação visível dos dois lados do plano, sem depender da orientação do braço.
	node.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	built.add_child(node)
	last_triangle_count+=count/3
