extends RefCounted
## Demanda inicial do bairro; reserva capacidade das obras para não crescer tudo de uma vez.
const STARTER_RESIDENTS := 8
const RESIDENTS_PER_JOB := 1.25
const CUSTOMERS_PER_SHOP := 8.0
const JOBS_PER_RESIDENT := 0.7

static func capture(housing) -> Dictionary:
	var result: Dictionary={"population":housing.residents.size(),"customers":0,"homes":0,"jobs":0,"planned_jobs":0,"shops":0,"waiting":0}
	for person in housing.residents:
		if person.balance>=20: result.customers+=1
	for lot in housing.lots:
		if lot.zone in ["water","power","sewage"]: continue
		if lot.get("demand_pending",false):
			result.waiting+=1
			continue
		if lot.zone=="residential": result.homes+=int(lot.capacity)
		else:
			var capacity: int=housing.economy.job_capacity(lot)
			result.planned_jobs+=capacity
			if lot.stage==2: result.jobs+=capacity
			if lot.zone=="commercial": result.shops+=1
	return result

static func reserve(stats: Dictionary, lot: Dictionary, economy) -> void:
	stats.waiting=maxi(0,stats.waiting-1)
	if lot.zone=="residential": stats.homes+=int(lot.capacity)
	else:
		stats.planned_jobs+=economy.job_capacity(lot)
		if lot.zone=="commercial": stats.shops+=1

static func remaining(stats: Dictionary, zone: String) -> int:
	match zone:
		"residential": return maxi(0,STARTER_RESIDENTS+floori(stats.jobs*RESIDENTS_PER_JOB)-int(stats.homes))
		"commercial": return maxi(0,(ceili(stats.customers/CUSTOMERS_PER_SHOP) if stats.customers>=2 else 0)-int(stats.shops))
		"industrial": return maxi(0,maxi(2,ceili(stats.population*JOBS_PER_RESIDENT))-int(stats.planned_jobs))
	return 0

static func level(value: int, zone: String) -> String:
	if value<=0: return "Sem"
	var high: int={"residential":6,"commercial":2,"industrial":4}.get(zone,4)
	if value>=high: return "Alta"
	return "Baixa" if value==1 else "Média"

static func reason(stats: Dictionary, zone: String) -> String:
	if remaining(stats,zone)>0: return "Há demanda para este uso."
	match zone:
		"residential": return "As casas prontas e em obra atendem a procura. Mais vagas de emprego abrem espaço para moradores."
		"commercial": return "As lojas prontas e em obra já atendem os compradores com saldo. Mais moradores e renda aumentam a procura." if stats.customers>=2 else "Aguarda ao menos dois moradores com saldo para comprar (R$ 20)."
		"industrial": return "As vagas prontas e em obra atendem a procura. Mais moradores geram necessidade de empregos."
	return "Aguardando demanda."

static func snapshot(housing) -> Dictionary:
	var stats:=capture(housing)
	var result: Dictionary={"waiting":stats.waiting,"jobs":stats.jobs,"planned_jobs":stats.planned_jobs,"homes":stats.homes,"customers":stats.customers}
	for zone in ["residential","commercial","industrial"]:
		var value:=remaining(stats,zone)
		result[zone]={"remaining":value,"level":level(value,zone),"reason":reason(stats,zone)}
	return result
