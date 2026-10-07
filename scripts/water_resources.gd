extends RefCounted
## Áreas subterrâneas fixas: vazão renovável abstrata, compartilhada entre redes.
const FIELDS := [
 {"name":"Aquífero Oeste","center":Vector2(-42,16),"radius":36.0,"yield":180},
 {"name":"Aquífero Leste","center":Vector2(42,16),"radius":34.0,"yield":240},
 {"name":"Aquífero Sul","center":Vector2(0,-55),"radius":26.0,"yield":180}
]
static func field_at(point:Vector2)->int:
 for i in range(FIELDS.size()):
  if point.distance_to(FIELDS[i].center)<=FIELDS[i].radius: return i
 return -1
static func production(lots:Array[Dictionary])->Dictionary:
 var used:=[0,0,0]
 var output:Dictionary={}
 var catalog=preload("res://scripts/city_catalog.gd")
 for lot in lots:
  if lot.zone!="water": continue
  var amount:=0
  var field:=field_at(Vector2(lot.x,lot.z))
  if lot.stage==2 and lot.road>=0:
   var capacity:int=catalog.for_lot(lot).capacity
   if lot.get("source_legacy",false): amount=capacity
   elif field>=0:
    amount=mini(capacity,maxi(0,int(FIELDS[field].yield)-int(used[field])))
    used[field]+=amount
  output[int(lot.id)]={"amount":amount,"field":field}
 return {"sources":output,"used":used}
