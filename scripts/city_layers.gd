extends MeshInstance3D
const Utilities=preload("res://scripts/city_utilities.gd")
const GREEN=Color(0.12,0.8,0.55)
const RED=Color(0.98,0.25,0.23)
const BLUE=Color(0.15,0.62,1.0)
const AMBER=Color(1.0,0.66,0.16)
const GREY=Color(0.4,0.45,0.51)
var surface:SurfaceTool
var count:=0
func triangle(a:Vector3,b:Vector3,c:Vector3,color:Color)->void:
	for point in [a,b,c]:
		surface.set_color(color)
		surface.add_vertex(point)
		count+=1
func line(a:Vector2,b:Vector2,y:float,width:float,color:Color)->void:
	var normal:Vector2=Vector2(-(b-a).y,(b-a).x).normalized()*width/2
	var points:Array[Vector3]=[]
	for p in [a+normal,b+normal,b-normal,a-normal]: points.append(Vector3(p.x,y,p.y))
	triangle(points[0],points[1],points[2],color)
	triangle(points[0],points[2],points[3],color)
func rebuild(model,terrain,kind:String,target_lot:int=0,target_road:Dictionary={})->void:
	mesh=null
	if kind=="" and target_lot==0 and target_road.is_empty(): return
	surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	count=0
	var supply:Dictionary=Utilities.budget(model.housing)
	if kind in ["sources","water"]: _aquifers(terrain,supply)
	if kind!="":
		for r in range(model.roads.size()):
			var group:int=model.housing.road_components.get(r,0)
			var net:Dictionary=supply.networks.get(group,Utilities.empty_budget())
			var color:Color=GREEN if group==0 else RED
			if kind in ["water","power","sewage"]:
				color=(BLUE if kind=="water" else (Color(0.12,0.8,0.7) if kind=="sewage" else AMBER)) if net[kind]>0 else GREY
				if net[kind]>0 and net[kind+"_used"]>net[kind]: color=RED
			elif kind=="zones": color=GREY
			var points:PackedVector2Array=model.roads[r].points
			for i in range(points.size()-1):
				var midpoint:Vector2=(points[i]+points[i+1])/2
				line(points[i],points[i+1],terrain.road_height_at(midpoint.x,midpoint.y)+0.25,0.7 if kind in ["water","power","sewage"] else 1.5,color)
	for lot in model.housing.lots:
		if kind=="" and int(lot.id)!=target_lot: continue
		var state:Dictionary=Utilities.state(lot,supply)
		var color:Color=GREEN
		if kind in ["water","power","sewage"]:
			color=GREEN if state[kind] else RED
			if (state.sewer_legacy if kind=="sewage" else state.legacy): color=Color(0.7,0.55,0.95)
			if Utilities.is_service(lot.zone): color=(BLUE if kind=="water" else (Color(0.12,0.8,0.7) if kind=="sewage" else AMBER)) if lot.zone==kind else GREY
		elif kind=="sources": color=BLUE if lot.zone=="water" else GREY
		elif kind=="access": color=GREEN if state.component==0 else (AMBER if lot.road>=0 else RED)
		elif kind=="zones": color=preload("res://scripts/buildings_view.gd").zone_color(lot.zone)
		if int(lot.id)==target_lot: color=RED
		var polygon:PackedVector2Array=model.housing.polygon(lot)
		var y:float=float(lot.height)+0.3
		if kind!="":
			for i in [1,2]: triangle(Vector3(polygon[0].x,y,polygon[0].y),Vector3(polygon[i].x,y,polygon[i].y),Vector3(polygon[i+1].x,y,polygon[i+1].y),color.darkened(0.27))
		for i in range(polygon.size()): line(polygon[i],polygon[(i+1)%polygon.size()],y+0.05,0.24,color)
		if kind in ["water","power","sewage"] and lot.road>=0:
			var gate:Vector2=preload("res://scripts/citizen_routes.gd").gate(lot)
			var frame:Dictionary=model.housing.frame(model.roads[lot.road],lot.distance)
			if not frame.is_empty(): line(gate,frame.point,y+0.1,0.35,color)
	if not target_road.is_empty():
		var points:PackedVector2Array=target_road.points
		for i in range(points.size()-1):
			var midpoint:Vector2=(points[i]+points[i+1])/2
			line(points[i],points[i+1],terrain.road_height_at(midpoint.x,midpoint.y)+0.3,7.0,RED)
	if count>0:
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo=true
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		material.no_depth_test=false
		surface.set_material(material)
		mesh=surface.commit()

func _aquifers(terrain,supply:Dictionary)->void:
	for index in range(Utilities.Resources.FIELDS.size()):
		var field:Dictionary=Utilities.Resources.FIELDS[index]
		var center:Vector2=field.center
		var color:=Color(0.08,0.29,0.40) if supply.resources.used[index]<field.yield else Color(0.42,0.25,0.16)
		var step:float=terrain.SIZE/terrain.SEGMENTS
		for ix in range(terrain.SEGMENTS):
			for iz in range(terrain.SEGMENTS):
				var x:float=ix*step-terrain.SIZE/2.0
				var z:float=iz*step-terrain.SIZE/2.0
				var point:=Vector2(x+step/2,z+step/2)
				if point.distance_to(center)>field.radius: continue
				var corners:Array[Vector3]=[]
				for delta in [Vector2(0,0),Vector2(step,0),Vector2(step,step),Vector2(0,step)]:
					var p:Vector2=Vector2(x,z)+delta
					corners.append(Vector3(p.x,terrain.height_at(p.x,p.y)+0.14,p.y))
				# Mesmo espaçamento e diagonal da malha do terreno, sem manchas de interseção.
				triangle(corners[0],corners[1],corners[3],color)
				triangle(corners[1],corners[2],corners[3],color)
		for i in range(64):
			var a:=center+Vector2.from_angle(TAU*i/64.0)*float(field.radius)
			var b:=center+Vector2.from_angle(TAU*(i+1)/64.0)*float(field.radius)
			line(a,b,terrain.height_at(a.x,a.y)+0.2,0.4,BLUE)
