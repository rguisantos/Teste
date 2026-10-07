extends Node3D
var batches := {}
var roof: SurfaceTool
var roof_vertices := 0
func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color=color
	result.roughness=0.95
	return result
func box(lot: Dictionary, local: Vector3, dimensions: Vector3, color: Color) -> void:
	var key:=color.to_html()
	if not batches.has(key): batches[key]={"color":color,"transforms":[]}
	var rotation:=Basis(Vector3.UP,-float(lot.angle))
	batches[key].transforms.append(Transform3D(rotation*Basis.from_scale(dimensions),Vector3(lot.x,lot.height,lot.z)+rotation*local))
static func zone_color(zone: String) -> Color:
	if zone=="water": return Color(0.1,0.75,0.95)
	if zone=="sewage": return Color(0.12,0.8,0.7)
	if zone=="power": return Color(0.98,0.48,0.08)
	return Color(0.15,0.8,0.4) if zone=="residential" else (Color(0.2,0.5,0.9) if zone=="commercial" else Color(0.9,0.7,0.15))
func rebuild(lots: Array[Dictionary], preview: Dictionary={}) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	batches.clear()
	roof=SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	roof_vertices=0
	for lot in lots: _building(lot)
	if not preview.is_empty(): box(preview,Vector3(0,0.11,0),Vector3(preview.width,0.12,preview.depth),zone_color(preview.zone))
	for group in batches.values():
		var mesh:=BoxMesh.new()
		mesh.size=Vector3.ONE
		var multi:=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=mesh
		multi.instance_count=group.transforms.size()
		for i in range(group.transforms.size()): multi.set_instance_transform(i,group.transforms[i])
		var node:=MultiMeshInstance3D.new()
		node.multimesh=multi
		node.material_override=material(group.color)
		add_child(node)
	if roof_vertices>0:
		roof.generate_normals()
		var node:=MeshInstance3D.new()
		node.mesh=roof.commit()
		node.material_override=material(Color(0.58,0.23,0.11))
		add_child(node)
func _building(lot: Dictionary) -> void:
	var w: float=lot.width
	var d: float=lot.depth
	if lot.get("demand_pending",false):
		var color:=zone_color(lot.zone)
		for x in [-w/2+0.08,w/2-0.08]: box(lot,Vector3(x,0.06,0),Vector3(0.12,0.12,d),color)
		for z in [-d/2+0.08,d/2-0.08]: box(lot,Vector3(0,0.06,z),Vector3(w,0.12,0.12),color)
		box(lot,Vector3(0,0.55,-d/2+0.3),Vector3(minf(1.4,w-0.5),0.65,0.12),color)
		return
	var concrete:=Color(0.57,0.56,0.49)
	box(lot,Vector3(0,-0.1,0),Vector3(w,0.2,d),concrete)
	box(lot,Vector3(0,0.02,0),Vector3(w-0.1,0.04,d-0.1),Color(0.32,0.44,0.22))
	box(lot,Vector3(0,0.06,-d/2+0.3),Vector3(w,0.1,0.6),concrete)
	box(lot,Vector3(0,-0.03,-d/2-0.75),Vector3(minf(w-0.4,2.5),0.1,1.5),concrete)
	if lot.stage==0:
		for x in [-w/2+0.1,w/2-0.1]:
			for z in [-d/2+0.1,d/2-0.1]: box(lot,Vector3(x,0.45,z),Vector3(0.12,0.9,0.12),zone_color(lot.zone))
		return
	if lot.stage==1:
		box(lot,Vector3(0,0.08,0.3),Vector3(w-0.7,0.16,d-1.6),concrete)
		box(lot,Vector3(-w/2+0.5,0.65,0.3),Vector3(0.2,1.2,d-1.6),Color(0.63,0.34,0.19))
		return
	if lot.zone in ["water","power","sewage"]: _service(lot)
	elif lot.zone=="residential": _house(lot)
	else: _business(lot,lot.zone=="industrial")
func _house(lot: Dictionary) -> void:
	var w: float=lot.width
	var d: float=lot.depth
	var bw:=w-1.0 if w<=6 else w-2.2
	var bd:=d-2.3 if d<=8 else d-4.0
	var z:=0.4
	var front:=z-bd/2
	var wall: Color=[Color(0.82,0.74,0.55),Color(0.63,0.77,0.77),Color(0.84,0.73,0.68)][lot.variant]
	var levels:=2 if w==6 and lot.variant==1 else 1
	var h:=2.7*levels
	box(lot,Vector3(0,h/2,z),Vector3(bw,h,bd),wall)
	box(lot,Vector3(-bw*0.23,1,front-0.04),Vector3(0.8,2,0.08),Color(0.24,0.18,0.13))
	for level in range(levels): box(lot,Vector3(bw*0.22,1.65+level*2.7,front-0.08),Vector3(minf(1.1,bw*0.34),0.85,0.1),Color(0.16,0.30,0.36))
	if lot.variant==2 and w<=6: box(lot,Vector3(0,h+0.12,z),Vector3(bw+0.2,0.24,bd+0.2),Color(0.57,0.56,0.49))
	else: _gable(lot,bw+0.5,bd+0.5,z,h,0.6 if w<=4 else 1.1)
	var fence_h:=0.9 if w<=4 else 1.3
	for x in [-w/2+0.08,w/2-0.08]: box(lot,Vector3(x,fence_h/2,0),Vector3(0.16,fence_h,d-0.2),wall)
	box(lot,Vector3(0,fence_h/2,d/2-0.08),Vector3(w-0.2,fence_h,0.16),wall)
	var gate:=minf(2.4,w*0.55)
	for side in [-1,1]: box(lot,Vector3(side*(w+gate)/4,fence_h/2,-d/2+0.6),Vector3((w-gate)/2,fence_h,0.14),wall)
	box(lot,Vector3(0,fence_h/2,-d/2+0.6),Vector3(gate,fence_h,0.1),Color(0.28,0.32,0.32))
	box(lot,Vector3(-bw*0.23,0.05,(front-d/2)/2),Vector3(0.9,0.1,front+d/2),Color(0.57,0.56,0.49))
func _business(lot: Dictionary, industry: bool) -> void:
	var bw: float=lot.width-0.6
	var bd: float=lot.depth-1.4
	var h:=4.2 if industry and lot.width>=8 else 3.2
	var wall: Color=Color(0.64,0.65,0.63) if industry else [Color(0.91,0.78,0.45),Color(0.7,0.8,0.85),Color(0.87,0.65,0.52)][lot.variant]
	box(lot,Vector3(0,h/2,0.2),Vector3(bw,h,bd),wall)
	box(lot,Vector3(0,1.3,0.2-bd/2-0.06),Vector3(bw-0.5,2.4,0.1),Color(0.29,0.4,0.48) if industry else Color(0.13,0.25,0.3))
	box(lot,Vector3(0,h+0.1,0.2),Vector3(bw+0.3,0.2,bd+0.3),Color(0.3,0.36,0.4))
	if industry:
		for i in range(4): box(lot,Vector3(0,0.5+i*0.45,0.2-bd/2-0.12),Vector3(bw-0.6,0.04,0.03),Color(0.6,0.64,0.66))
		box(lot,Vector3(bw/2-0.4,h+0.7,bd/2-0.3),Vector3(0.35,1.4,0.35),Color(0.38,0.38,0.38))
	else:
		var accent: Color=[Color(0.15,0.38,0.26),Color(0.65,0.17,0.1),Color(0.2,0.35,0.6)][lot.variant]
		box(lot,Vector3(0,2.8,0.2-bd/2-0.4),Vector3(bw+0.15,0.18,0.8),accent)
		box(lot,Vector3(0,3.3,0.2-bd/2-0.12),Vector3(bw,0.5,0.2),accent)
	box(lot,Vector3(-bw/2+0.5,0.3,-lot.depth/2+0.4),Vector3(0.6,0.6,0.4),Color(0.66,0.44,0.22))
func _gable(lot: Dictionary,w: float,d: float,z: float,h: float,rise: float) -> void:
	var points: Array[Vector3]=[Vector3(-w/2,h,z-d/2),Vector3(w/2,h,z-d/2),Vector3(0,h+rise,z-d/2),Vector3(-w/2,h,z+d/2),Vector3(w/2,h,z+d/2),Vector3(0,h+rise,z+d/2)]
	var basis:=Basis(Vector3.UP,-float(lot.angle))
	for index in [0,2,3,3,2,5,2,1,5,5,1,4,0,1,2,3,5,4]:
		roof.add_vertex(Vector3(lot.x,lot.height,lot.z)+basis*points[index])
		roof_vertices+=1

func _service(lot: Dictionary)->void:
	if lot.zone=="sewage":
		for z in [-1.6,1.2]:
			_service_box(lot,Vector3(0,0.4,z),Vector3(4.6,0.8,2.0),Color(0.6,0.64,0.62))
			_service_box(lot,Vector3(0,0.83,z),Vector3(4.1,0.08,1.5),Color(0.21,0.39,0.28) if z<0 else Color(0.12,0.57,0.65))
			_service_box(lot,Vector3(0,0.94,z),Vector3(0.2,0.14,2.1),Color(0.72,0.75,0.70))
		_service_box(lot,Vector3(0,0.2,3),Vector3(3.8,0.4,1),Color(0.35,0.42,0.3))
	elif lot.zone=="water":
		for x in [-1.5,1.5]:
			for z in [-1.8,1.8]: _service_box(lot,Vector3(x,1.8,z),Vector3(0.3,3.6,0.3),Color(0.6,0.65,0.68))
		_service_box(lot,Vector3(0,3.5,0),Vector3(3.6,1.5,4.4),Color(0.1,0.58,0.82))
		_service_box(lot,Vector3(0,4.3,0),Vector3(3.8,0.2,4.6),Color(0.7,0.82,0.86))
	else:
		_service_box(lot,Vector3(0,0.7,0),Vector3(3.8,1.4,4.5),Color(0.85,0.7,0.35))
		for x in [-1.0,1.0]:
			_service_box(lot,Vector3(x,1.8,0),Vector3(1.1,1.0,2.0),Color(0.25,0.32,0.38))
			_service_box(lot,Vector3(x,2.5,0),Vector3(0.2,0.7,0.2),Color(0.92,0.5,0.1))
		_service_box(lot,Vector3(2.0,2.5,2.5),Vector3(0.25,5.0,0.25),Color(0.3,0.3,0.32))

func _service_box(lot:Dictionary,local:Vector3,dimensions:Vector3,color:Color)->void:
	var scale_value:=Vector3(float(lot.width)/6.0,0.8 if lot.width==4 else (1.2 if lot.width==10 else 1.0),float(lot.depth)/8.0)
	box(lot,local*scale_value,dimensions*scale_value,color)
