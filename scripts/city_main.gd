extends Node3D

const TerrainScript = preload("res://scripts/landscape.gd")
const CameraScript = preload("res://scripts/city_camera.gd")
const DiagnosticsScript = preload("res://scripts/diagnostics.gd")
const Network = preload("res://scripts/streets_model.gd")
const RoadView = preload("res://scripts/road_view.gd")
const Utilities = preload("res://scripts/city_utilities.gd")
const Problems=preload("res://scripts/city_problems.gd")
const ProblemIcons=preload("res://scripts/problem_icons.gd")
const Store = preload("res://scripts/city_store.gd")

var terrain: Node3D
var city_camera: Node3D
var road_view: Node3D
var model = Network.new()
var store = Store.new()
var sun := DirectionalLight3D.new()
var diagnostics = DiagnosticsScript.new()
var status_label: Label
var report_label: Label
var report_panel: PanelContainer
var options_panel: PanelContainer
var shadow_button: Button
var confirm_button: Button
var road_surface_button: Button
var upgrade_button: Button
var selected_road_surface := "dirt"
var upgrade_mode := false
var upgrade_target: Dictionary = {}
var road_button: Button
var message_label: Label
var reset_dialog: ConfirmationDialog
var clock := 0.0
var save_clock := 0.0
var selected_citizen := 0
var vehicle_view = preload("res://scripts/vehicle_view.gd").new()
var traffic_panel:PanelContainer
var traffic_label:Label
var selected_vehicle:=0
var traffic_buttons:Dictionary={}
var citizen_view = preload("res://scripts/citizen_view.gd").new()
var current_seed := 1042026
var has_start := false
var has_end := false
var start_point := Vector2.ZERO
var end_point := Vector2.ZERO
var residential_mode := false
var selected_lot: Dictionary = {}
var housing_view = preload("res://scripts/buildings_view.gd").new()
var residential_button: Button
var zone_panel: PanelContainer
var zone_label: Label
var economy_panel: PanelContainer
var economy_label: Label
var economy_status: Label
var demand_status: Label
var lot_panel: PanelContainer
var lot_label: Label
var lot_usage_row: HBoxContainer
var lot_usage_buttons: Array[Button]=[]
var lot_cancel_button: Button
var lot_cancel_dialog: ConfirmationDialog
var inspected_lot_id := 0
var cancel_lot_id := 0
var paused := false
var time_button: Button
var selected_zone := "residential"
const Catalog=preload("res://scripts/city_catalog.gd")
var catalog_tier:="medium"
var catalog_kind:="water"
var catalog_build:Button
var catalog_map:Button
var catalog_categories:Dictionary={}
var catalog_buttons:Dictionary={}
var selected_size := "auto"
var curved := false
var control_point = null
var shape_button: Button
var bottom_bar: VBoxContainer
var build_actions: HBoxContainer
var infrastructure_panel: PanelContainer
var infrastructure_label: Label
var utility_status: Label
var coverage_kind := ""
var bulldozer_mode := false
var overlay = preload("res://scripts/city_layers.gd").new()
var service_view = preload("res://scripts/buildings_view.gd").new()
var map_panel: PanelContainer
var map_label: Label
var demolition_dialog: ConfirmationDialog
var keep_zone_check: CheckBox
var demolition_target: Dictionary={}
var road_target: Dictionary={}
var toolbar_buttons: Dictionary={}
var demand_bars: Array[ProgressBar]=[]
var quick_time: Button
var ground_material: Material
var layer_ground: StandardMaterial3D
var active_tool := "Navegar"
var overlay_target := 0
var alert_view=preload("res://scripts/city_alert_view.gd").new()
var problem_snapshot:Dictionary={"entries":[],"counts":{"all":0,"services":0,"access":0,"demand":0},"causes":0}
var problems_button:Button
var problems_panel:PanelContainer
var problems_title:Label
var problems_rows:VBoxContainer
var problem_rows:Array[Button]=[]
var problems_filter:="all"
var problem_filters:Dictionary={}
var problem_list_signature:=""
var lot_problem_label:Label
var lot_problem_map:Button
var budget_mode:="last"
var budget_tabs:Dictionary={}
var budget_grid:GridContainer
var budget_summary:Label


func _ready() -> void:
	Engine.max_fps = 30
	_create_environment()
	current_seed = int(Time.get_unix_time_from_system()) % 2147483000
	terrain = TerrainScript.new()
	add_child(terrain)
	terrain.generate(current_seed)
	city_camera = CameraScript.new()
	add_child(city_camera)
	city_camera.map_tapped.connect(_map_tapped)
	road_view = RoadView.new()
	road_view.terrain = terrain
	add_child(road_view)
	add_child(housing_view)
	add_child(citizen_view)
	add_child(vehicle_view)
	add_child(overlay)
	add_child(service_view)
	_create_interface()
	var saved: Dictionary = store.load_city()
	if not saved.is_empty():
		_apply_saved(saved)
	else:
		message_label.text = "Comece pela entrada de terra à esquerda. Abra Ruas para construir."
	_refresh_status()


func _process(delta: float) -> void:
	diagnostics.record(delta)
	var step:=minf(delta,0.25)
	clock+=step
	if not paused and not demolition_dialog.visible:
		var result: Dictionary=model.simulate(step)
		if result.visual: _refresh_housing()
		save_clock+=step
		if result.visual or result.day_changed or save_clock>=5.0:
			save_clock=0.0
			store.save_city(current_seed,model)
	citizen_view.refresh(model,terrain,step if not paused and not demolition_dialog.visible else 0.0)
	vehicle_view.refresh(model,terrain)
	if clock>1.0:
		clock=0.0
		if economy_panel.visible: _refresh_economy()
		if traffic_panel.visible:_refresh_traffic()
		_refresh_status()
		if zone_panel.visible: _refresh_zone_label()
		if infrastructure_panel.visible: _refresh_infrastructure()
		if residential_mode and not selected_lot.is_empty():
			var quote:Dictionary=model.budget_forecast(selected_lot)
			confirm_button.disabled=quote.price>0 and quote.cash_after<0
		if map_panel.visible: _refresh_map_panel()
		if lot_panel.visible: _refresh_lot_panel()
		if selected_citizen>0 and not city_camera.build_mode: _refresh_citizen()
		if report_panel.visible: _refresh_report()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		diagnostics.reset()
	if what == NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(terrain):
		store.save_city(current_seed, model)


func _refresh_status() -> void:
	_refresh_problems()
	if is_instance_valid(quick_time): quick_time.text="Retomar" if paused else "Pausar"
	status_label.text="R$ %d   •   %d moradores   •   Dia %d" % [model.cash,model.housing.residents.size(),model.housing.economy.day]
	if is_instance_valid(economy_status):
		economy_status.text="Saldo diário R$ %d  •  %d empregados  •  %s" % [model.housing.economy.last.net,model.housing.economy.employment_count(model.housing),"PAUSADO" if paused else "3 min / dia"]
	if is_instance_valid(demand_status):
		var demand:Dictionary=model.housing.Demand.snapshot(model.housing)
		demand_status.text="Demanda: R %s • C %s • I %s" % [demand.residential.level,demand.commercial.level,demand.industrial.level]
		for i in range(demand_bars.size()):
			var value:Dictionary=demand[["residential","commercial","industrial"][i]]
			demand_bars[i].value={"Sem":0,"Baixa":25,"Média":60,"Alta":100}.get(value.level,0)
	if is_instance_valid(utility_status): _refresh_utility_status()


func _refresh_utility_status() -> void:
	var supply: Dictionary=Utilities.budget(model.housing)
	utility_status.text="Água %d/%d • Energia %d/%d • Esgoto %d/%d • %d avisos" % [supply.water_used,supply.water,supply.power_used,supply.power,supply.sewage_used,supply.sewage,supply.alerts]


func _create_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.29, 0.50, 0.71)
	sky_material.sky_horizon_color = Color(0.75, 0.83, 0.85)
	sky_material.ground_bottom_color = Color(0.18, 0.22, 0.14)
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180
	add_child(sun)


func _style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100, 48)
	button.add_theme_font_size_override("font_size",16)
	button.pressed.connect(action)
	button.add_theme_stylebox_override("normal", _style(Color(0.12,0.17,0.24,1)))
	button.add_theme_stylebox_override("hover", _style(Color(0.19,0.27,0.37,1)))
	button.add_theme_stylebox_override("pressed", _style(Color(0.1,0.38,0.57,1)))
	return button


func _create_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 20
	root.theme = theme
	alert_view.camera_rig=city_camera
	root.add_child(alert_view)
	var top:=PanelContainer.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left=24
	top.offset_right=-24
	top.offset_top=16
	top.add_theme_stylebox_override("panel",_style(Color(0.055,0.085,0.13,0.97)))
	var top_row:=HBoxContainer.new()
	top_row.add_theme_constant_override("separation",24)
	top.add_child(top_row)
	var stats:=VBoxContainer.new()
	stats.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top_row.add_child(stats)
	status_label=Label.new()
	status_label.add_theme_font_size_override("font_size",22)
	stats.add_child(status_label)
	economy_status=Label.new()
	economy_status.add_theme_font_size_override("font_size",15)
	economy_status.modulate=Color(0.65,0.75,0.85)
	stats.add_child(economy_status)
	var demand_stack:=VBoxContainer.new()
	top_row.add_child(demand_stack)
	demand_status=Label.new()
	demand_status.add_theme_font_size_override("font_size",14)
	demand_stack.add_child(demand_status)
	var bars:=HBoxContainer.new()
	demand_stack.add_child(bars)
	for color in [Color(0.18,0.8,0.5),Color(0.2,0.58,1),Color(1,0.7,0.2)]:
		var bar:=ProgressBar.new()
		bar.custom_minimum_size=Vector2(72,9)
		bar.show_percentage=false
		var fill:=StyleBoxFlat.new()
		fill.bg_color=color
		bar.add_theme_stylebox_override("fill",fill)
		bars.add_child(bar)
		demand_bars.append(bar)
	problems_button=_button("Avisos 0",_toggle_problems)
	problems_button.icon=ProblemIcons.texture("alert")
	problems_button.add_theme_constant_override("icon_max_width",20)
	top_row.add_child(problems_button)
	quick_time=_button("Pausar",_toggle_time)
	top_row.add_child(quick_time)
	utility_status=Label.new()
	utility_status.visible=false
	stats.add_child(utility_status)
	var bottom:=VBoxContainer.new()
	bottom_bar=bottom
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left=24
	bottom.offset_right=-24
	bottom.offset_top=-112
	bottom.offset_bottom=-16
	bottom.add_theme_constant_override("separation",8)
	message_label=Label.new()
	message_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size",16)
	message_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	message_label.add_theme_constant_override("shadow_offset_x",1)
	message_label.add_theme_constant_override("shadow_offset_y",1)
	message_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bottom.add_child(message_label)
	build_actions=HBoxContainer.new()
	build_actions.add_theme_constant_override("separation",8)
	bottom.add_child(build_actions)
	build_actions.visible=false
	shape_button=_button("Traçado: reto",_toggle_shape)
	build_actions.add_child(shape_button)
	road_surface_button=_button("Piso: terra",_toggle_road_surface)
	build_actions.add_child(road_surface_button)
	upgrade_button=_button("Asfaltar trecho",_toggle_upgrade)
	build_actions.add_child(upgrade_button)
	confirm_button=_button("Confirmar",_confirm_road)
	confirm_button.disabled=true
	confirm_button.add_theme_stylebox_override("normal",_style(Color(0.08,0.38,0.30)))
	build_actions.add_child(confirm_button)
	build_actions.add_child(_button("Cancelar",_cancel_preview))
	var dock:=PanelContainer.new()
	dock.add_theme_stylebox_override("panel",_style(Color(0.055,0.085,0.13,0.98)))
	bottom.add_child(dock)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	dock.add_child(row)
	var names:=["Navegar","Rua de terra","Zonear","Infraestrutura","Mapas","Bulldozer","Opções"]
	var actions_list:Array[Callable]=[_navigate,_build_mode,_toggle_zoning,_toggle_infrastructure,_toggle_maps,_bulldozer,_toggle_options]
	for i in range(names.size()):
		var button:=_button(names[i],actions_list[i])
		button.icon=_tool_icon(i)
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",24)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(button)
		toolbar_buttons[names[i]]=button
	road_button=toolbar_buttons["Rua de terra"]
	road_button.text="Ruas"
	residential_button=toolbar_buttons["Zonear"]
	options_panel = _panel(root)
	var options := VBoxContainer.new()
	options_panel.add_child(options)
	var option_title := Label.new()
	option_title.text = "CIDADES DO BRASIL • 0.0.19"
	options.add_child(option_title)
	var option_row := HBoxContainer.new()
	options.add_child(option_row)
	option_row.add_child(_button("Novo terreno", _ask_new_city))
	option_row.add_child(_button("Centralizar", city_camera.center_view))
	shadow_button = _button("Sombras: sim", _toggle_shadows)
	option_row.add_child(shadow_button)
	var save_row := HBoxContainer.new()
	options.add_child(save_row)
	save_row.add_child(_button("Salvar", _save_city))
	save_row.add_child(_button("Continuar", _load_city))
	save_row.add_child(_button("Diagnóstico", _toggle_report))
	var econ_row := HBoxContainer.new()
	options.add_child(econ_row)
	econ_row.add_child(_button("Economia",_toggle_economy))
	time_button = _button("Pausar tempo",_toggle_time)
	econ_row.add_child(time_button)
	econ_row.add_child(_button("Trânsito",_toggle_traffic))
	options.add_child(_button("Fechar opções", _toggle_options))
	options_panel.visible = false
	report_panel = _panel(root)
	var stack := VBoxContainer.new()
	report_panel.add_child(stack)
	report_label = Label.new()
	report_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_label.add_theme_font_size_override("font_size", 18)
	stack.add_child(report_label)
	var actions := HBoxContainer.new()
	stack.add_child(actions)
	actions.add_child(_button("Copiar dados", _copy_report))
	actions.add_child(_button("Reiniciar teste", _reset_report))
	actions.add_child(_button("Fechar", _toggle_report))
	report_panel.visible = false
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "Começar outra cidade"
	reset_dialog.dialog_text = "Substituir a cidade salva por um terreno vazio?"
	reset_dialog.ok_button_text = "Nova cidade"
	reset_dialog.cancel_button_text = "Voltar"
	reset_dialog.confirmed.connect(_new_terrain)
	root.add_child(reset_dialog)
	zone_panel = _panel(root)
	var zone_stack := VBoxContainer.new()
	zone_panel.add_child(zone_stack)
	zone_label = Label.new()
	zone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	zone_label.add_theme_font_size_override("font_size",18)
	zone_stack.add_child(zone_label)
	var zone_row := HBoxContainer.new()
	zone_stack.add_child(zone_row)
	for zone in ["residential","commercial","industrial"]:
		zone_row.add_child(_button(_zone_name(zone),_choose_zone.bind(zone)))
	var size_title := Label.new()
	size_title.text = "TAMANHO • pequeno aproveita espaços estreitos"
	zone_stack.add_child(size_title)
	var size_row := GridContainer.new()
	size_row.columns=2
	zone_stack.add_child(size_row)
	for mode in ["auto","small","medium","large"]:
		size_row.add_child(_button(_size_name(mode),_choose_size.bind(mode)))
	var zone_actions:=HBoxContainer.new()
	zone_stack.add_child(zone_actions)
	zone_actions.add_child(_button("Zonear no mapa",_residential_mode))
	zone_actions.add_child(_button("Fechar zoneamento",_toggle_zoning))
	zone_panel.visible = false
	_refresh_zone_label()
	economy_panel = _panel(root)
	var econ_stack := VBoxContainer.new()
	economy_panel.add_child(econ_stack)
	economy_label = Label.new()
	economy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	economy_label.add_theme_font_size_override("font_size",18)
	econ_stack.add_child(economy_label)
	var tabs:=HBoxContainer.new()
	econ_stack.add_child(tabs)
	for mode in ["last","active","authorized"]:
		var button:=_button({"last":"Último dia","active":"Operação atual","authorized":"Obras autorizadas"}[mode],_choose_budget.bind(mode))
		button.toggle_mode=true
		budget_tabs[mode]=button
		tabs.add_child(button)
	var budget_scroll:=ScrollContainer.new()
	budget_scroll.custom_minimum_size=Vector2(0,224)
	budget_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	budget_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	econ_stack.add_child(budget_scroll)
	var budget_body:=VBoxContainer.new()
	budget_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	budget_scroll.add_child(budget_body)
	budget_grid=GridContainer.new()
	budget_grid.columns=2
	budget_grid.add_theme_constant_override("h_separation",28)
	budget_grid.add_theme_constant_override("v_separation",6)
	budget_body.add_child(budget_grid)
	budget_summary=Label.new()
	budget_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	budget_summary.add_theme_font_size_override("font_size",16)
	budget_body.add_child(budget_summary)
	var footer:=HBoxContainer.new()
	econ_stack.add_child(footer)
	footer.add_child(_button("Fechar economia",_toggle_economy))
	footer.add_child(_button("Problemas",_toggle_problems))
	economy_panel.visible = false
	city_camera.blocked_regions.append(zone_panel)
	city_camera.blocked_regions.append(economy_panel)
	city_camera.blocked_regions.append(top)
	city_camera.blocked_regions.append(bottom)
	city_camera.blocked_regions.append(report_panel)
	city_camera.blocked_regions.append(options_panel)
	_create_lot_panel(root)
	_create_infrastructure_panel(root)
	_create_maps(root)
	_create_demolition_dialog(root)
	_create_problems_panel(root)
	_create_traffic_panel(root)
	_set_active("Navegar")


func _panel(root: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 24
	panel.offset_right = 574
	panel.offset_top = 104
	panel.offset_bottom = 510
	panel.add_theme_stylebox_override("panel", _style(Color(0.055,0.085,0.13,0.98)))
	return panel


func _navigate() -> void:
	options_panel.visible=false
	economy_panel.visible=false
	report_panel.visible=false
	_set_active("Navegar")
	bulldozer_mode=false
	overlay_target=0
	infrastructure_panel.visible=false
	build_actions.visible=false
	bottom_bar.offset_top=-112
	shape_button.visible=false
	_refresh_overlay()
	_close_lot_panel()
	selected_citizen=0
	zone_panel.visible = false
	residential_mode = false
	_cancel_preview()
	city_camera.build_mode = false
	road_button.text = "Ruas"
	message_label.text = "Navegação: toque em imóvel, pedestre ou veículo para consultar; um dedo move, dois ajustam a câmera."


func _build_mode() -> void:
	options_panel.visible=false
	economy_panel.visible=false
	report_panel.visible=false
	_set_active("Rua de terra")
	bulldozer_mode=false
	overlay_target=0
	infrastructure_panel.visible=false
	build_actions.visible=true
	bottom_bar.offset_top=-200
	shape_button.visible=true
	_refresh_overlay()
	_close_lot_panel()
	zone_panel.visible = false
	residential_mode = false
	city_camera.clear_gestures()
	city_camera.build_mode = true
	road_button.text = "Ruas"
	_cancel_preview()
	message_label.text = "Toque no início e no fim; em curva, toque depois no ponto de ajuste."


func _cancel_preview() -> void:
	upgrade_target={}
	overlay_target=0
	selected_lot = {}
	_refresh_overlay()
	housing_view.rebuild(model.housing.lots)
	has_start = false
	has_end = false
	control_point = null
	road_view.clear_preview()
	confirm_button.disabled = true
	message_label.text = "Prévia cancelada. Nenhum custo cobrado."


func _pick_ground(screen_point: Vector2):
	var camera: Camera3D = city_camera.camera
	var origin := camera.project_ray_origin(screen_point)
	var direction := camera.project_ray_normal(screen_point)
	if direction.y >= -0.001:
		return null
	var distance_value := (0.5 - origin.y) / direction.y
	var hit := origin + direction * distance_value
	for iteration in range(6):
		distance_value = (terrain.height_at(hit.x, hit.z) - origin.y) / direction.y
		hit = origin + direction * distance_value
	if distance_value < 0 or absf(hit.x) > 94 or absf(hit.z) > 94:
		return null
	return Vector2(hit.x, hit.z)


func _map_tapped(screen_point: Vector2) -> void:
	if not city_camera.build_mode and coverage_kind=="" and not demolition_dialog.visible:
		var marker:Dictionary=alert_view.pick(screen_point)
		if not marker.is_empty():
			_show_problem(marker)
			return
	if bulldozer_mode:
		var ground=_pick_ground(screen_point)
		if ground==null: return
		for lot in model.housing.lots:
			if Geometry2D.is_point_in_polygon(ground,model.housing.polygon(lot)):
				_request_demolition({"kind":"lot","id":int(lot.id)})
				return
		var selected:Dictionary=model.pick_demolition_road(ground)
		if not selected.is_empty():
			_request_demolition({"kind":"road","road":selected})
		else: message_label.text="BULLDOZER • Toque em uma rua, prédio ou instalação."
		return
	if not city_camera.build_mode:
		if coverage_kind=="" and _pick_vehicle(screen_point):return
		if coverage_kind=="": _pick_citizen(screen_point)
		else: selected_citizen=0
		if selected_citizen>0: _close_lot_panel()
		if selected_citizen==0:
			var ground=_pick_ground(screen_point)
			if ground!=null:
				for lot in model.housing.lots:
					if Geometry2D.is_point_in_polygon(ground,model.housing.polygon(lot)):
						_inspect_lot(lot)
						return
		return
	var point = _pick_ground(screen_point)
	if point == null:
		message_label.text = "Toque dentro do terreno."
		return
	if residential_mode:
		for lot in model.housing.lots:
			if Geometry2D.is_point_in_polygon(point, model.housing.polygon(lot)):
				_cancel_preview()
				_inspect_lot(lot)
				return
		selected_lot = model.housing.candidate(point,model.roads,terrain.height_at,selected_zone,selected_size,selected_zone+"_"+catalog_tier if Utilities.is_service(selected_zone) else "")
		housing_view.rebuild(model.housing.lots, selected_lot)
		_refresh_overlay()
		confirm_button.disabled = selected_lot.is_empty() or (model.budget_forecast(selected_lot).price>0 and model.budget_forecast(selected_lot).cash_after<0)
		if selected_lot.is_empty(): message_label.text="Poço exige aquífero e espaço junto à rua. Consulte Fontes ou escolha Pequeno." if selected_zone=="water" else "Não cabe aqui. Escolha Pequeno ou toque mais perto da rua."
		else:
			var quote:Dictionary=model.budget_forecast(selected_lot)
			message_label.text="%.0f × %.0f m • R$ %d • Manutenção R$ %d/dia • Caixa após R$ %d%s" % [selected_lot.width,selected_lot.depth,quote.price,quote.candidate,quote.cash_after," • Caixa insuficiente" if quote.cash_after<0 else " • Confirme"]
			if selected_zone=="water":
				var field:int=Utilities.Resources.field_at(Vector2(selected_lot.x,selected_lot.z))
				var resource:Dictionary=Utilities.Resources.FIELDS[field]
				var used:int=Utilities.budget(model.housing).resources.used[field]
				message_label.text+="\n%s • Vazão livre agora %d/%d; outras obras podem ocupá-la." % [resource.name,maxi(0,int(resource.yield)-used),resource.yield]
		return
	if upgrade_mode:
		_select_upgrade(point)
		return
	_select_point(point)


func _toggle_shape() -> void:
	residential_mode = false
	curved = not curved
	shape_button.text = "Traçado: curva" if curved else "Traçado: reto"
	_cancel_preview()
	if not city_camera.build_mode:
		_build_mode()
	message_label.text = "Curva: toque no início, no fim e no ponto de ajuste." if curved else "Reta: toque no início e no fim, em qualquer direção."


func _select_point(point: Vector2) -> void:
	if not city_camera.build_mode:
		return
	if not has_start:
		start_point = model.pick_start(point)
		has_start = true
		road_view.show_start(start_point)
		message_label.text = "Início marcado. Toque no fim; aproxime de outra rua para conectar."
		return
	if curved and has_end:
		control_point = model.snap_point(point)
	else:
		end_point = model.pick_start(point)
		has_end = true
	if curved and control_point == null:
		road_view.show_preview(start_point, end_point, false)
		confirm_button.disabled = true
		message_label.text = "Fim marcado. Toque ao lado do traçado para ajustar a curva."
		return
	var result: Dictionary = model.evaluate(start_point, end_point, control_point, selected_road_surface)
	road_view.show_preview(start_point, end_point, result.valid, control_point,9.0 if selected_road_surface=="asphalt" else 7.0)
	confirm_button.disabled = not result.valid
	if result.valid:
		message_label.text = "%s • %.0f m • R$ %d • Caixa após R$ %d\nManutenção total de ruas após: R$ %d/dia • Confirme ou ajuste." % ["Asfalto com calçadas" if selected_road_surface=="asphalt" else "Rua de terra",result.length,result.cost,model.cash-result.cost,int(ceil((model.maintenance_length()+result.length*(2.4 if selected_road_surface=="asphalt" else 1.0))*0.05))]
	else:
		message_label.text = result.reason + " Ajuste ou cancele."


func _confirm_road() -> void:
	if upgrade_mode:
		_confirm_upgrade()
		return
	if residential_mode:
		if selected_lot.is_empty():
			return
		var result:Dictionary=model.place_lot(selected_lot)
		if not result.ok:
			message_label.text=result.message
			return
		_cancel_preview()
		_refresh_housing()
		_refresh_status()
		message_label.text = "Instalação autorizada: pronta em 24 segundos ativos." if Utilities.is_service(selected_zone) else "Lote marcado. A obra aguarda demanda, água, energia e esgoto; depois leva 24 segundos ativos."
		if not store.save_city(current_seed, model):
			message_label.text = "Lote autorizado, mas houve falha ao salvar. Tente Opções → Salvar."
		return
	if not has_start or not has_end or (curved and control_point == null):
		return
	if not model.commit(start_point, end_point, control_point, selected_road_surface):
		message_label.text = "Não foi possível construir este trecho."
		return
	road_view.rebuild(model.roads)
	_refresh_housing()
	_cancel_preview()
	_refresh_status()
	if store.save_city(current_seed, model):
		message_label.text = "Rua construída e cidade salva. Toque no início do próximo trecho."
	else:
		message_label.text = "Rua construída. Falha ao salvar; tente Opções → Salvar."


func _toggle_options() -> void:
	_set_active("Opções")
	infrastructure_panel.visible=false
	_close_lot_panel()
	zone_panel.visible = false
	economy_panel.visible = false
	city_camera.clear_gestures()
	options_panel.visible = not options_panel.visible


func _ask_new_city() -> void:
	city_camera.clear_gestures()
	reset_dialog.popup_centered(Vector2i(600, 220))


func _new_terrain() -> void:
	_cancel_preview()
	current_seed = int(Time.get_ticks_usec()) % 2147483000
	model = Network.new()
	terrain.generate(current_seed)
	road_view.rebuild(model.roads)
	_refresh_housing()
	city_camera.center_view()
	options_panel.visible = false
	_navigate()
	diagnostics.reset()
	_refresh_status()
	_save_city()


func _toggle_shadows() -> void:
	city_camera.clear_gestures()
	sun.shadow_enabled = not sun.shadow_enabled
	shadow_button.text = "Sombras: sim" if sun.shadow_enabled else "Sombras: não"
	diagnostics.reset()


func _save_city() -> void:
	message_label.text = "Cidade salva." if store.save_city(current_seed, model) else "Falha ao salvar a cidade."


func _load_city() -> void:
	var saved: Dictionary = store.load_city()
	if saved.is_empty():
		message_label.text = "Ainda não há uma cidade salva válida."
		return
	_apply_saved(saved)


func _apply_saved(saved: Dictionary) -> void:
	_close_lot_panel()
	_cancel_preview()
	current_seed = int(saved.seed)
	model = Network.restore(saved)
	terrain.generate(current_seed)
	road_view.rebuild(model.roads)
	_refresh_housing()
	city_camera.center_view()
	options_panel.visible = false
	_navigate()
	diagnostics.reset()
	_refresh_status()
	message_label.text = "Cidade retomada: %d ruas e caixa R$ %d." % [model.roads.size(), model.cash]


func _toggle_report() -> void:
	zone_panel.visible = false
	economy_panel.visible = false
	city_camera.clear_gestures()
	options_panel.visible = false
	report_panel.visible = not report_panel.visible
	_refresh_report()


func _snapshot() -> Dictionary:
	var data: Dictionary = diagnostics.snapshot(current_seed, sun.shadow_enabled, Vector2i(get_viewport().get_visible_rect().size))
	data["road_count"] = model.roads.size()
	data["cash"] = model.cash
	data["population"] = model.housing.residents.size()
	data["zoned_lots"] = model.housing.lots.size()
	data["demand"]=model.housing.Demand.snapshot(model.housing)
	data["utilities"]=Utilities.budget(model.housing)
	data["traffic"]=model.traffic.stats()
	data["walking_citizens"]=model.travel.moving_count()
	data["completed_trips"]=model.travel.completed_trips
	data["economic_day"] = model.housing.economy.day
	data["employed"] = model.housing.economy.employment_count(model.housing)
	data["daily_net"] = model.housing.economy.last.net
	data["network_nodes"] = model.nodes.size()
	data["network_edges"] = model.edges.size()
	data["road_surface_triangles"] = road_view.last_triangle_count
	data["last_road_rebuild_ms"] = road_view.last_build_ms
	return data


func _refresh_report() -> void:
	var data := _snapshot()
	report_label.text = (
		"DIAGNÓSTICO • %s\n%s • GPU: %s\nRenderizador: %s • Sombras: %s\n"
		+ "Teste: %.1f s • Amostras: %d • Ruas: %d\nFPS atual: %d • Média: %.1f\n"
		+ "Quadro médio: %.2f ms • Percentil 95: %.2f ms\n"
		+ "Memória estática: %.1f MB (não representa toda a RAM)\n"
		+ "Copie os dados e cole na conversa após testar."
	) % [data.device_model, data.os, data.gpu, data.renderer,
		"sim" if data.shadows else "não", data.duration_seconds, data.sample_count,
		data.road_count, data.fps_current, data.fps_sample_mean, data.frame_ms_mean,
		data.frame_ms_p95, data.static_memory_mb]


func _copy_report() -> void:
	var text := JSON.stringify(_snapshot(), "\t")
	var file := FileAccess.open("user://diagnostico.json", FileAccess.WRITE)
	if file != null:
		file.store_string(text)
	DisplayServer.clipboard_set(text)
	message_label.text = "Diagnóstico copiado. Cole os dados na conversa."


func _reset_report() -> void:
	diagnostics.reset()
	_refresh_report()


func _residential_mode() -> void:
	_set_active("Zonear")
	bulldozer_mode=false
	overlay_target=0
	infrastructure_panel.visible=false
	build_actions.visible=true
	bottom_bar.offset_top=-200
	shape_button.visible=false
	_refresh_overlay()
	zone_panel.visible = false
	_cancel_preview()
	residential_mode = true
	city_camera.clear_gestures()
	city_camera.build_mode = true
	road_button.text = "Ruas"
	message_label.text = "%s • %s. Toque ao lado da rua e confirme; toque no imóvel para consultar." % [_zone_name(selected_zone),_size_name(selected_size)]


func _refresh_housing() -> void:
	housing_view.rebuild(model.housing.lots)
	var active_lots: Array[Dictionary]=[]
	for lot in model.housing.lots:
		if not lot.get("demand_pending",false): active_lots.append(lot)
	terrain.set_lots(active_lots)
	_refresh_problems()
	_refresh_overlay()

func _zone_name(zone: String) -> String:
	return {"residential":"Residencial","commercial":"Comércio","industrial":"Indústria","water":"Estação de água","power":"Unidade de energia","sewage":"Estação de esgoto"}.get(zone,zone)

func _size_name(mode: String) -> String:
	return {"auto":"Automático","small":"Pequeno 4×6","medium":"Médio 6×8","large":"Grande 10×12"}.get(mode,mode)

func _toggle_zoning() -> void:
	_set_active("Zonear")
	infrastructure_panel.visible=false
	if Utilities.is_service(selected_zone): selected_zone="residential"
	_close_lot_panel()
	city_camera.clear_gestures()
	zone_panel.visible = not zone_panel.visible
	options_panel.visible = false
	economy_panel.visible = false
	report_panel.visible = false
	_refresh_zone_label()

func _choose_zone(zone: String) -> void:
	_close_lot_panel()
	_cancel_preview()
	selected_zone = zone
	_refresh_zone_label()

func _choose_size(mode: String) -> void:
	_cancel_preview()
	selected_size = mode
	_refresh_zone_label()

func _refresh_zone_label() -> void:
	var demand: Dictionary=model.housing.Demand.snapshot(model.housing)
	var selected: Dictionary=demand.get(selected_zone,demand.residential)
	zone_label.text="ZONEAMENTO • %s • %s\nMoradia %s • Comércio %s • Indústria %s\n%d moradores • %d compradores • %d vagas • %d aguardando\n%s" % [_zone_name(selected_zone),_size_name(selected_size),demand.residential.level,demand.commercial.level,demand.industrial.level,model.housing.residents.size(),demand.customers,demand.jobs,demand.waiting,selected.reason]


func _toggle_time() -> void:
	paused = not paused
	clock = 0
	time_button.text = "Retomar tempo" if paused else "Pausar tempo"
	quick_time.text="Retomar" if paused else "Pausar"
	_refresh_status()

func _toggle_economy() -> void:
	var opening:=not economy_panel.visible
	_navigate()
	if is_instance_valid(problems_panel): problems_panel.visible=false
	economy_panel.visible=opening
	_refresh_economy()

func _choose_budget(mode:String)->void:
	budget_mode=mode
	_refresh_economy()

func _budget_row(label:String,value:String,emphasis:bool=false)->void:
	var texts:=[label,value]
	for i in range(2):
		var cell:=Label.new()
		cell.text=texts[i]
		cell.add_theme_font_size_override("font_size",16)
		if i==0: cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		else: cell.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		if emphasis: cell.modulate=Color(0.43,0.85,0.75)
		budget_grid.add_child(cell)

func _refresh_economy() -> void:
	var eco=model.housing.economy
	var detail:Dictionary=model.budget_details()
	for mode in budget_tabs: budget_tabs[mode].set_pressed_no_signal(mode==budget_mode)
	economy_label.text="ORÇAMENTO • DIA %d • Caixa R$ %d" % [eco.day,model.cash]
	for child in budget_grid.get_children():
		budget_grid.remove_child(child)
		child.queue_free()
	var values:Dictionary=detail.last_breakdown if budget_mode=="last" else detail["active" if budget_mode=="active" else "authorized"]
	var tax:int=detail.last.taxes
	_budget_row("Impostos do último dia","+ R$ %d" % tax,true)
	for category in ["roads","water","power","sewage"]:
		var label:String={"roads":"Manutenção de ruas","water":"Água","power":"Energia","sewage":"Esgoto"}[category]
		if category!="roads" and budget_mode!="last":
			label+=" (%d prontas%s)" % [detail.counts[category].ready," + %d obras" % detail.counts[category].works if budget_mode=="authorized" else ""]
		var value:String="não informado" if budget_mode=="last" and not detail.known else "− R$ %d" % values[category]
		_budget_row(label,value)
	if values.unclassified>0: _budget_row("Não discriminado (save antigo)","− R$ %d" % values.unclassified)
	var total:int=eco.breakdown_total(values)
	_budget_row("Despesa total","R$ %d / dia" % total,true)
	_budget_row("Saldo realizado" if budget_mode=="last" else "Saldo estimado","R$ %d / dia" % (tax-total),true)
	var note:String={"last":"Último fechamento: valores efetivamente cobrados.","active":"Estimativa com instalações concluídas, inclusive isoladas.","authorized":"Estimativa inclui todas as instalações ainda em obra."}[budget_mode]
	if budget_mode=="last" and not detail.known: note="Save antigo: a despesa histórica não foi discriminada."
	budget_summary.text="%s\nImpostos hoje R$ %d • Fechamento em %.0f s ativos\nCompras acumuladas: ruas R$ %d • serviços R$ %d\nEstimativas usam os impostos do último dia; compras são gastos pontuais." % [note,detail.taxes_today,detail.seconds_left,detail.roads_spent,detail.facilities_spent]
	budget_summary.text+="\nEconomia privada: salários R$ %d • compras R$ %d\nExportações R$ %d • importações R$ %d (último dia)" % [eco.last.wages,eco.last.sales,eco.last.exports,eco.last.imports]

func _inspect_lot(lot: Dictionary) -> void:
	_open_lot_panel(int(lot.id))
	if lot.get("demand_pending",false):
		var stats: Dictionary=model.housing.Demand.capture(model.housing)
		message_label.text="%s %d • Aguardando demanda/serviços. %s" % [_zone_name(lot.zone),lot.id,model.housing.Demand.reason(stats,lot.zone)]
	elif lot.stage < 2:
		message_label.text = "%s %d • %.0f × %.0f m • Em construção." % [_zone_name(lot.zone),lot.id,lot.width,lot.depth]
	elif Utilities.is_service(lot.zone):
		message_label.text="%s %d • Capacidade %d unidades" % [_zone_name(lot.zone),lot.id,Catalog.for_lot(lot).capacity]
	elif lot.zone != "residential":
		message_label.text = "%s %d • %d/%d empregados • Caixa R$ %d • Estoque %d" % [_zone_name(lot.zone),lot.id,model.housing.economy.workers(model.housing,lot.id),model.housing.economy.job_capacity(lot),lot.business.cash,lot.business.stock]
	else:
		var names := PackedStringArray()
		for citizen in model.housing.residents:
			if citizen.home == lot.id:
				names.append("%s: %s, R$ %d" % [citizen.name,"emprego %d" % citizen.job if citizen.job > 0 else "sem emprego",citizen.balance])
		message_label.text = "Casa %d • %s" % [lot.id,", ".join(names)]


func _pick_citizen(screen_point: Vector2) -> void:
	var closest:=25.0
	selected_citizen=0
	for agent in model.travel.agents:
		if agent.phase!="walking": continue
		var p: Vector2=model.travel.position(agent,model.housing)
		var world:=Vector3(p.x,terrain.height_at(p.x,p.y)+1.0,p.y)
		if city_camera.camera.is_position_behind(world): continue
		var distance_value: float=city_camera.camera.unproject_position(world).distance_to(screen_point)
		if distance_value<closest:
			closest=distance_value
			selected_citizen=agent.id
	if selected_citizen>0: _refresh_citizen()
	else: message_label.text="Aproxime a câmera e toque em um imóvel ou pedestre. As viagens param em Opções → Pausar tempo."

func _refresh_citizen() -> void:
	if selected_citizen<1 or selected_citizen>model.travel.agents.size():
		selected_citizen=0
		return
	var agent: Dictionary=model.travel.agents[selected_citizen-1]
	var person: Dictionary=model.housing.residents[selected_citizen-1]
	var activity: String={"walking":"Caminhando","working":"No trabalho","shopping":"Na loja","idle":"No imóvel","blocked":"Sem rota"}.get(agent.phase,agent.phase)
	var destination: String={"work":"trabalho","shop":"compras","home":"casa"}.get(agent.purpose,agent.purpose)
	message_label.text="%s • %d anos • %s: %s %d • Faltam %.0f m • R$ %d" % [person.name,person.age,activity,destination,agent.target,maxf(0,agent.length-agent.distance),person.balance]


func _create_lot_panel(root: Control) -> void:
	lot_panel=_panel(root)
	var stack:=VBoxContainer.new()
	lot_panel.add_child(stack)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(0,190)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	lot_label=Label.new()
	lot_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	lot_label.add_theme_font_size_override("font_size",17)
	body.add_child(lot_label)
	lot_problem_label=Label.new()
	lot_problem_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	lot_problem_label.add_theme_font_size_override("font_size",16)
	lot_problem_label.modulate=Color(1,0.79,0.48)
	body.add_child(lot_problem_label)
	lot_usage_row=HBoxContainer.new()
	stack.add_child(lot_usage_row)
	for zone in ["residential","commercial","industrial"]:
		var button:=_button("Uso: "+_zone_name(zone),_change_inspected_zone.bind(zone))
		lot_usage_row.add_child(button)
		lot_usage_buttons.append(button)
	var problem_actions:=HBoxContainer.new()
	stack.add_child(problem_actions)
	lot_problem_map=_button("Ver causa no mapa",_show_lot_problem_map)
	problem_actions.add_child(lot_problem_map)
	problem_actions.add_child(_button("Lista de problemas",_toggle_problems))
	var actions:=HBoxContainer.new()
	stack.add_child(actions)
	lot_cancel_button=_button("Cancelar zoneamento",_request_cancel_lot)
	actions.add_child(lot_cancel_button)
	actions.add_child(_button("Demolir / liberar",func(): _request_demolition({"kind":"lot","id":inspected_lot_id})))
	actions.add_child(_button("Fechar lote",_close_lot_panel))
	lot_panel.visible=false
	city_camera.blocked_regions.append(lot_panel)
	lot_cancel_dialog=ConfirmationDialog.new()
	lot_cancel_dialog.title="Liberar espaço do lote"
	lot_cancel_dialog.ok_button_text="Liberar lote"
	lot_cancel_dialog.cancel_button_text="Manter lote"
	lot_cancel_dialog.confirmed.connect(_confirm_cancel_lot)
	lot_cancel_dialog.canceled.connect(func(): cancel_lot_id=0)
	root.add_child(lot_cancel_dialog)

func _open_lot_panel(lot_id: int) -> void:
	if lot_id<1 or lot_id>model.housing.lots.size(): return
	inspected_lot_id=lot_id
	if is_instance_valid(problems_panel): problems_panel.visible=false
	selected_citizen=0
	zone_panel.visible=false
	infrastructure_panel.visible=false
	options_panel.visible=false
	economy_panel.visible=false
	report_panel.visible=false
	city_camera.clear_gestures()
	lot_panel.visible=true
	_refresh_lot_panel()

func _close_lot_panel() -> void:
	overlay_target=0
	_refresh_overlay()
	inspected_lot_id=0
	if is_instance_valid(lot_panel): lot_panel.visible=false

func _refresh_lot_panel() -> void:
	if inspected_lot_id<1 or inspected_lot_id>model.housing.lots.size():
		_close_lot_panel()
		return
	var lot: Dictionary=model.housing.lots[inspected_lot_id-1]
	var waiting: bool=lot.get("demand_pending",false)
	var status: String="Aguardando demanda/serviços" if waiting else ("Concluído" if lot.stage==2 else "Em construção • %.0f/24 s" % lot.age)
	var details:="%s %d • %.0f × %.0f m\n%s\n" % [_zone_name(lot.zone),lot.id,lot.width,lot.depth,status]
	if waiting:
		details+=model.housing.Demand.reason(model.housing.Demand.capture(model.housing),lot.zone)+"\nTroque o uso ou cancele para liberar este espaço."
	elif lot.stage<2:
		details+="A obra já começou. Você pode cancelá-la antes da conclusão."
	elif lot.zone=="residential":
		for person in model.housing.residents:
			if person.home==lot.id:
				details+="%s • %d anos • %s • R$ %d\n" % [person.name,person.age,"emprego %d" % person.job if person.job>0 else "sem emprego",person.balance]
		details+="Bulldozer permite demolir esta moradia."
	elif Utilities.is_service(lot.zone):
		details+="Capacidade: %d unidades. Manutenção R$ %d/dia ao concluir. Pago R$ %d. Use Bulldozer para demolir." % [Catalog.for_lot(lot).capacity,Catalog.for_lot(lot).maintenance,lot.get("build_paid",0)]
	else:
		details+="%d/%d empregados • Caixa R$ %d • Estoque %d\nBulldozer permite demolir esta empresa." % [model.housing.economy.workers(model.housing,lot.id),model.housing.economy.job_capacity(lot),lot.business.cash,lot.business.stock]
	details+="\n"+Utilities.state(lot,Utilities.budget(model.housing)).text
	lot_label.text=details
	var issues:Array[Dictionary]=_issues_for_id(int(lot.id))
	lot_problem_label.text=""
	for value in issues: lot_problem_label.text+="\n"+value.title+"\n"+value.action+"\n"
	lot_problem_label.visible=not issues.is_empty()
	lot_problem_map.disabled=issues.is_empty()
	lot_usage_row.visible=waiting
	for i in range(lot_usage_buttons.size()): lot_usage_buttons[i].disabled=lot.zone==["residential","commercial","industrial"][i]
	lot_cancel_button.text="Cancelar zoneamento" if waiting else "Cancelar obra"
	lot_cancel_button.disabled=lot.stage>=2

func _change_inspected_zone(zone: String) -> void:
	var result: Dictionary=model.change_waiting_zone(inspected_lot_id,zone)
	if result.ok:
		_cancel_preview()
		_refresh_housing()
		_refresh_status()
		if not store.save_city(current_seed,model): result.message+=" Falha ao salvar; tente Opções → Salvar."
	message_label.text=result.message
	_refresh_lot_panel()

func _request_cancel_lot() -> void:
	if inspected_lot_id<1 or inspected_lot_id>model.housing.lots.size(): return
	var lot: Dictionary=model.housing.lots[inspected_lot_id-1]
	if lot.stage>=2: return
	cancel_lot_id=inspected_lot_id
	lot_cancel_dialog.dialog_text="Cancelar %s %d e liberar %.0f × %.0f m? Sem reembolso de valores já pagos. Moradores e empresas dos outros lotes serão mantidos." % [_zone_name(lot.zone),lot.id,lot.width,lot.depth]
	lot_cancel_dialog.popup_centered(Vector2i(720,230))

func _confirm_cancel_lot() -> void:
	var target:=cancel_lot_id
	cancel_lot_id=0
	var result: Dictionary=model.cancel_unfinished_lot(target)
	if result.ok:
		_close_lot_panel()
		_cancel_preview()
		_refresh_housing()
		_refresh_status()
		if not store.save_city(current_seed,model): result.message+=" Falha ao salvar; tente Opções → Salvar."
	else: _refresh_lot_panel()
	message_label.text=result.message


func _create_infrastructure_panel(root: Control) -> void:
	infrastructure_panel=_panel(root)
	var stack:=VBoxContainer.new()
	infrastructure_panel.add_child(stack)
	var categories:=HBoxContainer.new()
	stack.add_child(categories)
	for kind in ["water","power","sewage"]:
		var button:=_button({"water":"Água","power":"Energia","sewage":"Esgoto"}[kind],_choose_catalog_kind.bind(kind))
		button.toggle_mode=true
		catalog_categories[kind]=button
		categories.add_child(button)
	var tiers:=HBoxContainer.new()
	stack.add_child(tiers)
	for tier in ["small","medium","large"]:
		var button:=_button({"small":"Pequeno 4×6","medium":"Médio 6×8","large":"Grande 10×12"}[tier],_choose_catalog.bind(tier))
		button.toggle_mode=true
		catalog_buttons[tier]=button
		tiers.add_child(button)
	infrastructure_label=Label.new()
	infrastructure_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	infrastructure_label.add_theme_font_size_override("font_size",17)
	stack.add_child(infrastructure_label)
	var row:=HBoxContainer.new()
	stack.add_child(row)
	catalog_build=_button("Construir água",_build_catalog)
	row.add_child(catalog_build)
	row.add_child(_button("Fechar catálogo",_toggle_infrastructure))
	var maps:=HBoxContainer.new()
	stack.add_child(maps)
	catalog_map=_button("Mapa: água",_catalog_coverage)
	maps.add_child(catalog_map)
	maps.add_child(_button("Fontes de água",_set_coverage.bind("sources")))
	infrastructure_panel.visible=false
	city_camera.blocked_regions.append(infrastructure_panel)

func _choose_catalog_kind(kind:String)->void:
	catalog_kind=kind
	_refresh_infrastructure()

func _build_catalog()->void: _service_mode(catalog_kind)
func _catalog_coverage()->void: _set_coverage(catalog_kind)

func _toggle_infrastructure() -> void:
	var opening:=not infrastructure_panel.visible
	_navigate()
	_set_active("Infraestrutura")
	options_panel.visible=false
	economy_panel.visible=false
	report_panel.visible=false
	infrastructure_panel.visible=opening
	_refresh_infrastructure()

func _refresh_infrastructure() -> void:
	for tier in catalog_buttons: catalog_buttons[tier].set_pressed_no_signal(tier==catalog_tier)
	for kind in catalog_categories: catalog_categories[kind].set_pressed_no_signal(kind==catalog_kind)
	var item:=Catalog.spec(catalog_kind,catalog_kind+"_"+catalog_tier)
	var quote:Dictionary=model.budget_forecast({"zone":catalog_kind,"catalog_id":catalog_kind+"_"+catalog_tier})
	var label:String={"water":"água","power":"energia","sewage":"esgoto"}[catalog_kind]
	catalog_build.text="Construir "+label
	catalog_build.disabled=quote.cash_after<0
	catalog_map.text="Mapa: "+label
	var requirement:String={"water":"Exige aquífero; vazão compartilhada. Bomba própria.","power":"Exige frente de rua. Atende somente a rede conectada.","sewage":"Coleta e trata pela rua; descarte por infiltração."}[catalog_kind]
	infrastructure_label.text="%s • %d×%d m • Capacidade %d\nCompra R$ %d • Manutenção R$ %d/dia\nCaixa após R$ %d • Saldo previsto R$ %d/dia\n%s\nObra 24 s. Manutenção ao concluir, mesmo isolada.\nPrevisão: impostos do último dia − despesas autorizadas.%s" % [item.name,item.width,item.depth,item.capacity,item.price,item.maintenance,quote.cash_after,quote.net,requirement,"\nCaixa insuficiente para esta instalação." if quote.cash_after<0 else ""]

func _choose_catalog(tier:String)->void:
	catalog_tier=tier
	_refresh_infrastructure()


func _service_mode(kind: String) -> void:
	selected_zone=kind
	selected_size=catalog_tier
	_residential_mode()
	_set_active("Infraestrutura")
	_set_coverage("sources" if kind=="water" else kind)
	var spec:=Catalog.spec(kind,kind+"_"+catalog_tier)
	var quote:Dictionary=model.budget_forecast({"zone":kind,"catalog_id":kind+"_"+catalog_tier})
	message_label.text="%s • R$ %d • R$ %d/dia • Caixa após R$ %d • Saldo previsto R$ %d/dia" % [spec.name,spec.price,spec.maintenance,quote.cash_after,quote.net]


func _set_coverage(kind: String) -> void:
	coverage_kind=kind
	infrastructure_panel.visible=false
	map_panel.visible=kind!=""
	selected_citizen=0
	_refresh_overlay()
	_refresh_map_panel()
	message_label.text="Mapa técnico: construções e árvores ocultas. Toque nos lotes para consultar." if kind!="" else "Visualização normal da cidade."

func _bulldozer() -> void:
	if bulldozer_mode:
		_navigate()
		return
	_navigate()
	_set_active("Bulldozer")
	options_panel.visible=false
	economy_panel.visible=false
	report_panel.visible=false
	bulldozer_mode=true
	city_camera.build_mode=true
	message_label.text="BULLDOZER • Selecione uma rua, prédio ou instalação. Confira os efeitos antes de confirmar."

func _refresh_overlay() -> void:
	if not is_instance_valid(terrain): return
	overlay.rebuild(model,terrain,coverage_kind,overlay_target,road_target)
	var technical:=coverage_kind!=""
	housing_view.visible=not technical
	alert_view.visible=not technical
	citizen_view.visible=not technical
	vehicle_view.visible=not technical
	if is_instance_valid(terrain.tree_root): terrain.tree_root.visible=not technical
	if is_instance_valid(terrain.ground_node):
		if layer_ground==null:
			layer_ground=StandardMaterial3D.new()
			layer_ground.albedo_color=Color(0.48,0.53,0.57)
			layer_ground.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		terrain.ground_node.material_overlay=layer_ground if technical else null
	var sources:Array[Dictionary]=[]
	if coverage_kind in ["water","power","sewage","sources"]:
		for lot in model.housing.lots:
			if lot.zone==coverage_kind or (coverage_kind=="sources" and lot.zone=="water"): sources.append(lot)
	service_view.rebuild(sources,selected_lot)
	service_view.visible=technical
	if is_instance_valid(map_panel) and map_panel.visible: _refresh_map_panel()

func _tool_icon(index:int) -> Texture2D:
	var paths:=["M9 3L5 20L11 15L16 21L19 19L14 13L21 11Z", "M7 2L4 22M17 2L20 22M12 3V7M12 10V14M12 17V21", "M3 3H10V10H3ZM14 3H21V10H14ZM3 14H10V21H3ZM14 14H21V21H14Z", "M4 20V9L12 3L20 9V20ZM8 20V12H16V20", "M3 5L9 3L15 6L21 4V20L15 22L9 19L3 21ZM9 3V19M15 6V22", "M3 16H18V21H3ZM5 16V9H12L16 16M12 9L15 5L21 16V21", "M4 6H20M4 12H20M4 18H20M8 3V9M16 9V15M10 15V21"]
	var svg:="<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'><path d='%s' fill='none' stroke='#c5d8e8' stroke-width='1.7' stroke-linecap='round' stroke-linejoin='round'/></svg>" % paths[index]
	var image:=Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)

func _set_active(tool:String) -> void:
	if is_instance_valid(traffic_panel):traffic_panel.visible=false
	selected_vehicle=0
	if is_instance_valid(problems_panel): problems_panel.visible=false
	upgrade_mode=false
	upgrade_target={}
	road_surface_button.visible=tool=="Rua de terra"
	upgrade_button.visible=tool=="Rua de terra"
	upgrade_button.text="Asfaltar trecho"
	active_tool=tool
	for name in toolbar_buttons:
		var button:Button=toolbar_buttons[name]
		var color:=Color(0.12,0.17,0.24)
		if name==tool: color=Color(0.08,0.36,0.52) if name!="Bulldozer" else Color(0.57,0.22,0.12)
		button.add_theme_stylebox_override("normal",_style(color))
	if is_instance_valid(demolition_dialog) and demolition_dialog.visible: demolition_dialog.hide()
	demolition_target={}
	road_target={}

func _create_maps(root:Control) -> void:
	map_panel=_panel(root)
	map_panel.offset_left=-374
	map_panel.offset_right=-24
	map_panel.anchor_left=1
	map_panel.anchor_right=1
	map_panel.offset_bottom=400
	var stack:=VBoxContainer.new()
	map_panel.add_child(stack)
	map_label=Label.new()
	map_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	map_label.add_theme_font_size_override("font_size",16)
	stack.add_child(map_label)
	var buttons:=GridContainer.new()
	buttons.columns=2
	stack.add_child(buttons)
	for kind in ["water","power","sewage","sources","access","zones"]:
		buttons.add_child(_button({"water":"Água","power":"Energia","sewage":"Esgoto","sources":"Fontes","access":"Acesso viário","zones":"Uso do solo"}[kind],_set_coverage.bind(kind)))
	stack.add_child(_button("Voltar à cidade",_set_coverage.bind("")))
	map_panel.visible=false
	city_camera.blocked_regions.append(map_panel)

func _toggle_maps() -> void:
	map_panel.visible=not map_panel.visible
	_refresh_map_panel()

func _refresh_map_panel() -> void:
	var supply:Dictionary=Utilities.budget(model.housing)
	var title:String={"water":"REDE DE ÁGUA","power":"REDE DE ENERGIA","sewage":"COLETA E TRATAMENTO","sources":"FONTES SUBTERRÂNEAS","access":"ACESSO VIÁRIO","zones":"USO DO SOLO","":"MAPAS DA CIDADE"}.get(coverage_kind,"")
	var detail:="Selecione uma camada de informações."
	if coverage_kind=="sources":
		detail="Áreas azuis: posicione o poço aqui.\nVazão alocada / limite compartilhado:\n"
		for i in range(Utilities.Resources.FIELDS.size()):
			var field:Dictionary=Utilities.Resources.FIELDS[i]
			detail+="%s: %d / %d\n" % [field.name,supply.resources.used[i],field.yield]
		detail+="Vazão renovável abstrata; sem estoque."
	elif coverage_kind=="sewage":
		detail="Reserva %d / %d • capacidade\nGerado %d • tratado local %d\nLegado externo %d • sem tratamento %d\nVerde: atendido • Roxo: legado\nVermelho: falta acesso ou capacidade\nETE: coleta, trata e infiltra o efluente." % [supply.sewage_used,supply.sewage,supply.sewage_generated,supply.sewage_treated,supply.sewage_external,supply.sewage_untreated]
	elif coverage_kind in ["water","power"]:
		detail="%d / %d unidades • reserva/capacidade\n%d imóveis com abastecimento legado\nVerde: atendido ou disponível\nVermelho: sem acesso ou capacidade\nRoxo: legado pela entrada\nCinza: rede sem fonte / outro serviço" % [supply[coverage_kind+"_used"],supply[coverage_kind],supply.legacy]
	elif coverage_kind=="access": detail="Verde: conectado à entrada\nLaranja: rua em rede isolada\nVermelho: lote sem rua / via isolada\n%d lotes fora da rede da entrada." % supply.disconnected
	elif coverage_kind=="zones": detail="Verde: residencial\nAzul: comércio • Amarelo: indústria\nCiano: água • Laranja: energia\nTurquesa: esgoto\nToque no lote para consultar."
	map_label.text=title+"\n"+detail

func _create_demolition_dialog(root:Control) -> void:
	demolition_dialog=ConfirmationDialog.new()
	demolition_dialog.title="Confirmar demolição"
	demolition_dialog.ok_button_text="Demolir"
	demolition_dialog.cancel_button_text="Cancelar"
	keep_zone_check=CheckBox.new()
	keep_zone_check.text="Manter zoneamento para reconstrução"
	keep_zone_check.custom_minimum_size=Vector2(0,48)
	var body:=VBoxContainer.new()
	body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var spacer:=Control.new()
	spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	body.add_child(keep_zone_check)
	for state in ["normal","hover","pressed","focus"]: keep_zone_check.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	demolition_dialog.add_child(body)
	demolition_dialog.confirmed.connect(_confirm_demolition)
	demolition_dialog.canceled.connect(_cancel_demolition)
	var dialog_theme:=Theme.new()
	dialog_theme.default_font_size=18
	dialog_theme.set_stylebox("panel","AcceptDialog",_style(Color(0.055,0.085,0.13)))
	var border:=_style(Color(0.08,0.12,0.18))
	border.expand_margin_top=32
	dialog_theme.set_stylebox("embedded_border","Window",border)
	dialog_theme.set_constant("title_height","Window",32)
	for state in ["normal","hover","pressed"]: dialog_theme.set_stylebox(state,"Button",_style(Color(0.16,0.24,0.32)))
	demolition_dialog.theme=dialog_theme
	for button in [demolition_dialog.get_ok_button(),demolition_dialog.get_cancel_button()]: button.custom_minimum_size=Vector2(160,48)
	demolition_dialog.get_ok_button().add_theme_stylebox_override("normal",_style(Color(0.57,0.22,0.12)))
	root.add_child(demolition_dialog)

func _request_demolition(target:Dictionary) -> void:
	_close_lot_panel()
	demolition_target=target
	road_target={}
	keep_zone_check.button_pressed=false
	keep_zone_check.visible=false
	var detail:=""
	if target.kind=="road":
		road_target=target.road
		var length:float=preload("res://scripts/citizen_routes.gd").length(road_target.points)
		var impact:Dictionary=model.demolition_impact(road_target)
		detail="Demolir o trecho destacado (%.0f m)?\n%s\n%s\nPrédios mantidos. Serviços e viagens serão recalculados. Sem reembolso." % [length,_impact_text("Sem rua na frente",impact.no_road),_impact_text("Isolados da entrada",impact.isolated)]
	else:
		if target.id<1 or target.id>model.housing.lots.size(): return
		var lot:Dictionary=model.housing.lots[target.id-1]
		overlay_target=int(lot.id)
		var residents:=0
		for person in model.housing.residents:
			if person.home==lot.id: residents+=1
		var jobs:int=model.housing.economy.workers(model.housing,lot.id)
		detail="Demolir %s %d?\n%d moradores sairão da cidade; %d trabalhadores perderão este emprego.\n" % [_zone_name(lot.zone),lot.id,residents,jobs]
		if Utilities.is_service(lot.zone): detail+="A capacidade será retirada da rede; imóveis podem perder abastecimento."
		else:
			keep_zone_check.visible=true
			detail+="Sem marcar a opção abaixo, o lote também será liberado."
		detail+="\nDemolição gratuita nesta fase, sem reembolso."
	_refresh_overlay()
	demolition_dialog.dialog_text=detail+"\n"
	demolition_dialog.popup_centered(Vector2i(780,270))

func _cancel_demolition() -> void:
	demolition_target={}
	road_target={}
	overlay_target=0
	_refresh_overlay()

func _confirm_demolition() -> void:
	if demolition_target.is_empty(): return
	var result:Dictionary=model.demolish_road(demolition_target.road) if demolition_target.kind=="road" else model.demolish_lot(int(demolition_target.id),keep_zone_check.visible and keep_zone_check.button_pressed)
	_cancel_demolition()
	if result.ok:
		road_view.rebuild(model.roads)
		_cancel_preview()
		_refresh_housing()
		_refresh_status()
		if not store.save_city(current_seed,model): result.message+=" Falha ao salvar; use Opções → Salvar."
	message_label.text=result.message

func _create_problems_panel(root:Control)->void:
	problems_panel=_panel(root)
	var stack:=VBoxContainer.new()
	problems_panel.add_child(stack)
	problems_title=Label.new()
	problems_title.add_theme_font_size_override("font_size",18)
	stack.add_child(problems_title)
	var filters:=HBoxContainer.new()
	stack.add_child(filters)
	for category in ["all","services","access","demand"]:
		var button:=_button({"all":"Todos","services":"Serviços","access":"Acesso","demand":"Demanda"}[category],_choose_problem_filter.bind(category))
		button.toggle_mode=true
		problem_filters[category]=button
		filters.add_child(button)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(0,230)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	problems_rows=VBoxContainer.new()
	problems_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(problems_rows)
	var footer:=HBoxContainer.new()
	stack.add_child(footer)
	footer.add_child(_button("Fechar problemas",_toggle_problems))
	footer.add_child(_button("Orçamento",_toggle_economy))
	problems_panel.visible=false
	city_camera.blocked_regions.append(problems_panel)

func _toggle_problems()->void:
	var opening:=not problems_panel.visible
	_navigate()
	_set_coverage("")
	problems_panel.visible=opening
	problem_list_signature=""
	_refresh_problems()

func _choose_problem_filter(category:String)->void:
	problems_filter=category
	problem_list_signature=""
	_refresh_problems()

func _refresh_problems()->void:
	problem_snapshot=Problems.capture(model)
	if is_instance_valid(alert_view): alert_view.update_entries(problem_snapshot.entries)
	if is_instance_valid(problems_button):
		problems_button.text="Avisos %d" % problem_snapshot.counts.all
		problems_button.modulate=Color(1,0.83,0.63) if problem_snapshot.counts.all>0 else Color.WHITE
	if not is_instance_valid(problems_panel) or not problems_panel.visible: return
	for category in problem_filters: problem_filters[category].set_pressed_no_signal(category==problems_filter)
	problems_title.text="PROBLEMAS • %d imóveis • %d causas" % [problem_snapshot.counts.all,problem_snapshot.causes]
	var entries:Array[Dictionary]=Problems.filtered(problem_snapshot,problems_filter)
	var signature:=JSON.stringify([problems_filter,entries])
	if signature==problem_list_signature: return
	for button in problem_rows:
		if is_instance_valid(button) and button.button_pressed: return
	problem_list_signature=signature
	for child in problems_rows.get_children():
		problems_rows.remove_child(child)
		child.queue_free()
	problem_rows.clear()
	if entries.is_empty():
		var empty:=Label.new()
		empty.text="Nenhum aviso neste filtro." if problem_snapshot.counts.all>0 else "Nenhum problema encontrado."
		problems_rows.add_child(empty)
	for entry in entries:
		var button:=_button("%s %d • %s\nLocalizar e consultar • %d causa(s)" % [_zone_name(entry.zone),entry.id,entry.issues[0].title,entry.issues.size()],_show_problem.bind(entry))
		button.custom_minimum_size.y=64
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		button.icon=ProblemIcons.texture(entry.issues[0].code)
		button.add_theme_constant_override("icon_max_width",28)
		problems_rows.add_child(button)
		problem_rows.append(button)

func _show_problem(target:Dictionary)->void:
	var lot:Dictionary=Problems.find_target(model,target)
	if lot.is_empty():
		problem_list_signature=""
		_refresh_problems()
		message_label.text="O lote mudou. A lista de problemas foi atualizada."
		return
	_navigate()
	_set_coverage("")
	city_camera.clear_gestures()
	city_camera.focus=Vector3(lot.x,float(lot.height)+1.0,lot.z)
	city_camera.distance=48
	city_camera._apply()
	_refresh_problems()
	_inspect_lot(lot)

func _issues_for_id(lot_id:int)->Array[Dictionary]:
	for entry in problem_snapshot.entries:
		if entry.id==lot_id: return entry.issues
	return []

func _show_lot_problem_map()->void:
	var issues:Array[Dictionary]=_issues_for_id(inspected_lot_id)
	if issues.is_empty(): return
	_set_coverage(issues[0].layer)


func _toggle_road_surface()->void:
	selected_road_surface="asphalt" if selected_road_surface=="dirt" else "dirt"
	road_surface_button.text="Piso: asfalto" if selected_road_surface=="asphalt" else "Piso: terra"
	_cancel_preview()
	message_label.text="%s • R$ %d/m • Manutenção R$ %.2f/m/dia. Marque início e fim." % ["Asfalto com calçadas" if selected_road_surface=="asphalt" else "Rua de terra",80 if selected_road_surface=="asphalt" else 40,0.12 if selected_road_surface=="asphalt" else 0.05]

func _toggle_upgrade()->void:
	upgrade_mode=not upgrade_mode
	_cancel_preview()
	shape_button.visible=not upgrade_mode
	road_surface_button.visible=not upgrade_mode
	upgrade_button.text="Construir rua" if upgrade_mode else "Asfaltar trecho"
	message_label.text="ASFALTAR • Toque no trecho entre cruzamentos. R$ 40/m; calçadas incluídas." if upgrade_mode else "Marque início e fim da nova rua."

func _select_upgrade(point:Vector2)->void:
	upgrade_target=model.pick_demolition_road(point)
	var quote:Dictionary=model.upgrade_quote(upgrade_target)
	road_view.show_upgrade(upgrade_target,quote.valid)
	confirm_button.disabled=not quote.valid
	message_label.text="Asfaltar %.0f m • R$ %d • Caixa após R$ %d\nManutenção total de ruas após: R$ %d/dia • Imóveis preservados • Confirme" % [quote.length,quote.cost,quote.cash_after,quote.maintenance_after] if quote.valid else quote.reason

func _confirm_upgrade()->void:
	var result:Dictionary=model.upgrade_road(upgrade_target)
	if result.ok:
		road_view.rebuild(model.roads)
		_cancel_preview()
		_refresh_housing()
		_refresh_status()
		if not store.save_city(current_seed,model): result.message+=" Falha ao salvar; use Opções → Salvar."
	message_label.text=result.message

func _impact_text(title:String,ids:Array)->String:
	var labels:=PackedStringArray()
	for i in range(mini(ids.size(),8)): labels.append("#%d" % ids[i])
	return "%s: %d imóveis%s%s" % [title,ids.size()," ("+", ".join(labels)+")" if not ids.is_empty() else ""," e outros" if ids.size()>8 else ""]


func _create_traffic_panel(root:Control)->void:
	traffic_panel=_panel(root)
	var stack:=VBoxContainer.new()
	traffic_panel.add_child(stack)
	var title:=Label.new()
	title.text="TRÂNSITO • VEÍCULOS"
	title.add_theme_font_size_override("font_size",20)
	stack.add_child(title)
	traffic_label=Label.new()
	traffic_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	traffic_label.add_theme_font_size_override("font_size",17)
	traffic_label.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stack.add_child(traffic_label)
	var types:=HBoxContainer.new()
	stack.add_child(types)
	var names:=["Compacto","Sedã","Moto","Leve","Grande"]
	for i in range(names.size()):
		var kind:String=preload("res://scripts/vehicle_catalog.gd").TYPES[i]
		var button:=_button(names[i],_locate_vehicle.bind(kind))
		button.add_theme_font_size_override("font_size",16)
		types.add_child(button)
		traffic_buttons[kind]=button
	stack.add_child(_button("Fechar trânsito",func():traffic_panel.visible=false;selected_vehicle=0))
	traffic_panel.visible=false
	city_camera.blocked_regions.append(traffic_panel)
func _toggle_traffic()->void:
	var opening:=not traffic_panel.visible
	_navigate()
	traffic_panel.visible=opening
	_refresh_traffic()
func _refresh_traffic()->void:
	var stats:Dictionary=model.traffic.stats()
	var detail:="%d circulando • %d parados • %d viagens concluídas\nCarros %d • Motos %d • Leves %d • Grandes %d\n\n" % [stats.active,stats.waiting,stats.completed,stats.counts.hatch+stats.counts.sedan,stats.counts.motorcycle,stats.counts.light_truck,stats.counts.heavy_truck]
	var found:=false
	for vehicle in model.traffic.vehicles:
		if vehicle.id!=selected_vehicle:continue
		found=true
		detail+="%s #%d • %.0f km/h\n%s • %s\n\n" % [preload("res://scripts/vehicle_catalog.gd").spec(vehicle.kind).name,vehicle.id,vehicle.speed*3.6,"Entrada → imóvel" if vehicle.origin.get("entry",false) else "Imóvel → saída",vehicle.reason if vehicle.reason!="" else "Em movimento"]
	if not found:detail+="Toque num veículo ou escolha o modelo abaixo.\n\n"
	detail+="Imóveis concluídos e ligados à entrada geram viagens.\nLeves: comércio/indústria. Grandes: indústria.\nRotas estreitas ficam sem o modelo.\nEstoque e pagamentos ainda não dependem do trânsito."
	traffic_label.text=detail
func _locate_vehicle(kind:String)->void:
	var candidates:Array[Dictionary]=[]
	for vehicle in model.traffic.vehicles:
		if vehicle.kind==kind:candidates.append(vehicle)
	if candidates.is_empty():
		message_label.text="Nenhum %s circulando agora. Aguarde com a cidade em funcionamento." % preload("res://scripts/vehicle_catalog.gd").spec(kind).name.to_lower()
		return
	var target:Dictionary=candidates[0]
	for i in range(candidates.size()):
		if candidates[i].id==selected_vehicle:target=candidates[(i+1)%candidates.size()];break
	_show_vehicle(target)
func _show_vehicle(vehicle:Dictionary)->void:
	_navigate()
	selected_vehicle=int(vehicle.id)
	traffic_panel.visible=true
	var p:Vector2=preload("res://scripts/citizen_routes.gd").position(vehicle.route.points,vehicle.distance)
	city_camera.distance=40
	city_camera.focus=Vector3(p.x,terrain.road_height_at(p.x,p.y),p.y)-city_camera.camera.global_basis.x*city_camera.distance*0.32
	city_camera._apply()
	_refresh_traffic()
func _pick_vehicle(point:Vector2)->bool:
	var best:=22.0
	var picked:Dictionary={}
	for vehicle in model.traffic.vehicles:
		var p:Vector2=preload("res://scripts/citizen_routes.gd").position(vehicle.route.points,vehicle.distance)
		var world:=Vector3(p.x,terrain.road_height_at(p.x,p.y)+1.0,p.y)
		if city_camera.camera.is_position_behind(world):continue
		var gap:float=city_camera.camera.unproject_position(world).distance_to(point)
		if gap<best:best=gap;picked=vehicle
	if picked.is_empty():return false
	_show_vehicle(picked)
	return true
