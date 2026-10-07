extends Node3D
const Catalog=preload("res://scripts/vehicle_catalog.gd")
const Routes=preload("res://scripts/vehicle_routes.gd")
var batches:Dictionary={}
var models:Dictionary={}
var surface:SurfaceTool
var material:StandardMaterial3D
func _ready()->void:
	material=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.albedo_color=Color.WHITE
	material.roughness=0.78
	for kind in Catalog.TYPES:
		models[kind]=_model(kind)
		var multi:=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.use_colors=true
		multi.mesh=models[kind]
		var node:=MultiMeshInstance3D.new()
		node.multimesh=multi
		node.material_override=material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(node)
		batches[kind]=multi
func _part(mesh:Mesh,origin:Vector3,color:Color,rotation:Basis=Basis.IDENTITY)->void:
	var arrays:=mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		surface.set_color(color)
		surface.set_normal(rotation*normals[index])
		surface.add_vertex(origin+rotation*vertices[index])
func box(position:Vector3,size:Vector3,color:Color)->void:
	var mesh:=BoxMesh.new()
	mesh.size=size
	_part(mesh,position,color)
func wheel(x:float,z:float,radius:float,width:float)->void:
	var mesh:=CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=width
	mesh.radial_segments=10
	_part(mesh,Vector3(x,radius,z),Color(0.08,0.09,0.1,0),Basis(Vector3.FORWARD,PI/2))
	mesh.top_radius=radius*0.45
	mesh.bottom_radius=radius*0.45
	mesh.height=width+0.02
	_part(mesh,Vector3(x,radius,z),Color(0.55,0.57,0.60,0),Basis(Vector3.FORWARD,PI/2))
func _model(kind:String)->ArrayMesh:
	surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint:Color={"hatch":Color(0.18,0.46,0.9),"sedan":Color(0.90,0.28,0.18),"motorcycle":Color(0.95,0.68,0.10),"light_truck":Color(0.24,0.67,0.43),"heavy_truck":Color(0.94,0.82,0.30)}[kind]
	var glass:=Color(0.1,0.23,0.29,0)
	var dark:=Color(0.13,0.15,0.17,0)
	var white:=Color(0.92,0.91,0.83,0)
	var red:=Color(0.9,0.1,0.06,0)
	var spec:=Catalog.spec(kind)
	var l:float=spec.length
	var w:float=spec.width
	if kind in ["hatch","sedan"]:
		box(Vector3(0,0.68,0),Vector3(w-0.12,0.62,l-0.15),paint)
		box(Vector3(0,1.12,-0.18),Vector3(w-0.26,0.52,l*0.5),glass)
		box(Vector3(0,1.40,-0.18),Vector3(w-0.22,0.08,l*0.47),paint)
		for x in [-1,1]:
			box(Vector3(x*(w/2-0.12),1.15,-0.08),Vector3(0.08,0.55,0.12),paint)
			for z in [-l*0.31,l*0.31]:wheel(x*(w/2-0.12),z,0.32,0.22)
			box(Vector3(x*w*0.32,0.75,l/2-0.03),Vector3(0.37,0.20,0.06),white)
			box(Vector3(x*w*0.32,0.75,-l/2+0.03),Vector3(0.32,0.18,0.06),red)
		box(Vector3(0,0.4,l/2-0.02),Vector3(w-0.15,0.16,0.09),dark)
	elif kind=="motorcycle":
		wheel(0,-0.64,0.32,0.19)
		wheel(0,0.66,0.32,0.19)
		box(Vector3(0,0.60,0),Vector3(0.33,0.42,1.2),dark)
		box(Vector3(0,0.82,0.15),Vector3(0.48,0.30,0.50),paint)
		box(Vector3(0,0.87,-0.34),Vector3(0.38,0.12,0.55),dark)
		box(Vector3(0,1.05,0.53),Vector3(0.73,0.09,0.14),dark)
		box(Vector3(0,0.90,0.80),Vector3(0.27,0.22,0.10),white)
		# Piloto com capacete, tronco, braços e pernas.
		box(Vector3(0,1.24,-0.20),Vector3(0.43,0.60,0.30),paint)
		for side in [-1,1]:
			box(Vector3(side*0.25,0.74,-0.18),Vector3(0.15,0.48,0.42),dark)
			box(Vector3(side*0.28,1.2,0.17),Vector3(0.14,0.15,0.62),dark)
		var helmet:=SphereMesh.new()
		helmet.radius=0.24;helmet.height=0.48;helmet.radial_segments=10;helmet.rings=5
		_part(helmet,Vector3(0,1.7,-0.12),white)
		box(Vector3(0,1.71,0.1),Vector3(0.34,0.15,0.06),glass)
	else:
		var heavy:=kind=="heavy_truck"
		var radius:=0.48 if heavy else 0.38
		box(Vector3(0,0.70,0),Vector3(w-0.4,0.30,l-0.15),dark)
		box(Vector3(0,1.24,l/2-0.85),Vector3(w-0.12,1.15,1.55),paint)
		box(Vector3(0,1.95,l/2-0.8),Vector3(w-0.12,0.55,1.45),glass)
		box(Vector3(0,2.26,l/2-0.8),Vector3(w-0.08,0.10,1.53),paint)
		box(Vector3(0,1.72,-0.82),Vector3(w-0.1,1.95 if heavy else 1.75,l-1.92),Color(0.78,0.8,0.79,0))
		box(Vector3(0,0.94,l/2-0.02),Vector3(w*0.52,0.38,0.08),dark)
		for side in [-1,1]:
			wheel(side*(w/2-0.12),l/2-1.0,radius,0.28)
			wheel(side*(w/2-0.12),-l/2+1.0,radius,0.28)
			if heavy:wheel(side*(w/2-0.12),-l/2+2.12,radius,0.28)
			box(Vector3(side*w*0.36,1.02,l/2+0.01),Vector3(0.34,0.22,0.08),white)
			box(Vector3(side*w*0.36,0.82,-l/2+0.05),Vector3(0.28,0.18,0.08),red)
			box(Vector3(side*(w/2+0.03),1.82,l/2-0.30),Vector3(0.12,0.23,0.23),dark)
		for z in [-l/2+0.6,-l/2+1.5,-l/2+2.4]:
			box(Vector3(w/2-0.04,1.65,z),Vector3(0.03,1.65,0.05),Color(0.59,0.63,0.64,0))
	surface.index()
	return surface.commit()
func refresh(network,terrain)->void:
	var grouped:Dictionary={}
	for kind in Catalog.TYPES:grouped[kind]=[]
	for vehicle in network.traffic.vehicles:grouped[vehicle.kind].append(vehicle)
	for kind in Catalog.TYPES:
		var multi:MultiMesh=batches[kind]
		var items:Array=grouped[kind]
		if multi.instance_count!=items.size():multi.instance_count=items.size()
		for i in range(items.size()):
			var vehicle:Dictionary=items[i]
			var progress:=lerpf(float(vehicle.previous_distance),float(vehicle.distance),clampf(network.traffic.accumulator/network.traffic.TICK,0,1))
			var frame:=Routes.pose(vehicle.route,progress)
			var p:Vector2=frame.point
			var d:Vector2=frame.direction
			var ahead:Vector2=p+d*1.5
			var behind:Vector2=p-d*1.5
			var forward:=Vector3(d.x,(terrain.road_height_at(ahead.x,ahead.y)-terrain.road_height_at(behind.x,behind.y))/3.0,d.y).normalized()
			var right:=Vector3.UP.cross(forward).normalized()
			var up:=forward.cross(right).normalized()
			multi.set_instance_transform(i,Transform3D(Basis(right,up,forward),Vector3(p.x,terrain.road_height_at(p.x,p.y)+0.21,p.y)))
			multi.set_instance_color(i,Color.WHITE)
