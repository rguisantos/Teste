extends RefCounted
## Diagnóstico derivado: não muda demanda, reservas, finanças ou moradores.
const Utilities=preload("res://scripts/city_utilities.gd")
const Demand=preload("res://scripts/city_demand.gd")
static func issue(code:String,title:String,action:String,layer:String,category:String,severity:int=2)->Dictionary:
	return {"code":code,"title":title,"action":action,"layer":layer,"category":category,"severity":severity}
static func for_lot(lot:Dictionary,supply:Dictionary,demand:Dictionary,workers:Dictionary)->Array[Dictionary]:
	var out:Array[Dictionary]=[]
	if lot.road<0:
		out.append(issue("access","Sem acesso à rua","Reconstrua uma rua junto à frente do lote. A ligação será recalculada.","access","access"))
		return out
	var group:=Utilities.component(lot,supply)
	if group>0 and not Utilities.is_service(lot.zone):
		out.append(issue("isolated","Rede isolada da entrada","Conecte esta rede à entrada da cidade. Obras e importação/exportação precisam dessa ligação.","access","access"))
	if Utilities.is_service(lot.zone):
		if lot.zone=="water" and lot.stage==2:
			var offered:int=supply.resources.sources[int(lot.id)].amount
			var capacity:int=Utilities.Catalog.for_lot(lot).capacity
			if offered<capacity:
				out.append(issue("source","Vazão limitada: %d/%d" % [offered,capacity],"O aquífero tem vazão compartilhada. Use outra área de fontes ou retire um poço concorrente.","sources","services",2 if offered==0 else 1))
		return out
	var state:=Utilities.state(lot,supply)
	for kind in Utilities.KINDS:
		if not state[kind]:
			var title:String={"water":"Falta água","power":"Falta energia","sewage":"Falta coleta/tratamento"}[kind]
			var action:String={"water":"Conecte um poço com vazão disponível a esta rede ou amplie a oferta de água.","power":"Conecte uma unidade de energia a esta rede ou amplie sua capacidade.","sewage":"Conecte uma ETE a esta rede ou amplie sua capacidade de coleta/tratamento."}[kind]
			out.append(issue(kind,title,action,kind,"services"))
	if lot.get("demand_pending",false) and Demand.remaining(demand,lot.zone)<=0:
		out.append(issue("demand","Aguardando demanda",Demand.reason(demand,lot.zone),"zones","demand",0))
	if lot.stage==2 and lot.zone in ["commercial","industrial"] and state.operational and int(workers.get(int(lot.id),0))==0:
		out.append(issue("workers","Sem trabalhadores","Atraia moradores em idade de trabalhar com moradias, demanda e serviços. Os empregos são preenchidos automaticamente.","zones","demand",1))
	return out
static func capture(model)->Dictionary:
	var supply:=Utilities.budget(model.housing)
	var demand:=Demand.capture(model.housing)
	var workers:Dictionary={}
	for person in model.housing.residents:
		if person.job>0: workers[int(person.job)]=int(workers.get(int(person.job),0))+1
	var entries:Array[Dictionary]=[]
	var counts:={"all":0,"services":0,"access":0,"demand":0}
	var causes:=0
	for lot in model.housing.lots:
		var issues:=for_lot(lot,supply,demand,workers)
		if issues.is_empty(): continue
		var severity:=0
		var categories:Dictionary={}
		for value in issues:
			severity=maxi(severity,int(value.severity))
			categories[value.category]=true
		for category in categories: counts[category]+=1
		counts.all+=1
		causes+=issues.size()
		entries.append({"id":int(lot.id),"x":float(lot.x),"z":float(lot.z),"height":float(lot.height),"zone":str(lot.zone),"issues":issues,"severity":severity})
	entries.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.severity>b.severity if a.severity!=b.severity else a.id<b.id)
	return {"entries":entries,"counts":counts,"causes":causes}
static func filtered(snapshot:Dictionary,category:String)->Array[Dictionary]:
	var out:Array[Dictionary]=[]
	for entry in snapshot.entries:
		for value in entry.issues:
			if category=="all" or value.category==category:
				out.append(entry)
				break
	return out
static func find_target(model,target:Dictionary)->Dictionary:
	# Renumerar após demolição não deve enviar um botão antigo para outro endereço.
	for lot in model.housing.lots:
		if absf(float(lot.x)-float(target.x))<0.01 and absf(float(lot.z)-float(target.z))<0.01 and lot.zone==target.zone: return lot
	return {}
