extends Node3D

var audio: Node
var sounds_enabled := true
var audio_volume := 1.0
var collector_hired := false
var collector_rank := 1
var collector_load := 0
var catch_stock := 0
var collector: Node3D
var collector_fish: Array = []
var catch_models: Array = []
var catch_label: Label3D
const CATCH_POINT := Vector3(-1.5,0,4.8)
const CATCH_LIMIT := 30
var start_pending := false
var action_zones: Array = []
var hero: Node3D
var camera: Camera3D
var ice: Array = []
var shop_ui: CanvasLayer
var shop_open := false
var shop_entry_armed := true
const SHOP_ENTRY := Vector3(1.5,0,11.6)
var money := 0 # Collected coins only; spendable at the shop.
var pending_coins := 0
var hero_dish_count := 0
var runner_hired := false
var runner_rank := 1
var transfer_timer := 0.0
var coin_timer := 0.0
var hero_dish_models: Array = []
var raw_table_models: Array = []
var coin_models: Array = []
var coin_label: Label3D
var dish_pickup_label: Label3D
var delivery_label: Label3D
const COIN_POINT := Vector3(6.8,0,-3.4)
const COUNTER_DROP := Vector3(6.4,0,0.4)
const RAW_TABLE_TOP := Vector3(0.35,1.15,3.65)
const KITCHEN_TABLE_TOP := Vector3(2.6,1.3,3.8)
const SALES_TABLE_TOP := Vector3(5.7,1.15,-1.9)

var cargo := 0
var player_level := 1
var xp := 0
var raw_stock := 0
var cooked_stock := 0 # Delivered dishes at the sales counter only.
var kitchen_ready := 0
var runner_load := 0
var runner: Node3D
var runner_dishes: Array = []
var kitchen_dishes: Array = []
var counter_dishes: Array = []
var runner_state := "pickup"
var runner_waypoint := 0
const KITCHEN_LIMIT := 12
const RUNNER_CAPACITY := 3
const PICKUP_POINT := Vector3(4.6,0,4.8)
const RUNNER_ROUTE := [Vector3(7.6,0,4.8),Vector3(7.6,0,0.4),COUNTER_DROP]

var kitchen_rank := 1
var active_recipe := 0
var recipe_unlocked := [true,false,false]
var kitchen_running := false
var cooking_recipe := 0
var kitchen_food: Array = []
var runner_food: Array = []
var hero_food: Array = []
var counter_food: Array = []
var customer_timer := 0.0
var drop_label: Label3D
const DROP_CENTER := Vector3(1.6,0,4.8)
const RECIPE_TITLES := ["Риба на грилі","Копчена риба","Рибна юшка"]
const RECIPE_BONUS := [0,8,16]
const RECIPE_TIMES := [3.0,4.0,5.0]
var cook_progress := 0.0
var seller_hired := false
var fisher_hired := false
var seller: Node3D
var fisher: Node3D
var fisher_load := 0
var fisher_timer := 0.0
var cook_label: Label3D
const COOK_CENTER := Vector3(1.6,0,1.8)
const STOCK_LIMIT := 50
const NPC_SPEED_MULTIPLIER := 0.75
const CUSTOMER_SPEED_MULTIPLIER := 1.30
var mesh_cache: Dictionary = {}

func xp_required() -> int:
	return player_level*30

func gain_xp(amount: int) -> void:
	xp+=amount
	while xp>=xp_required() and player_level<50:
		xp-=xp_required()
		player_level+=1
		play_sound("level",-15.0)

func hire(kind: String) -> void:
	if kind=="seller" and not seller_hired and player_level>=2 and money>=100:
		money-=100
		seller_hired=true
	elif kind=="fisher" and not fisher_hired and player_level>=3 and money>=180:
		money-=180
		fisher_hired=true
	elif kind=="runner" and not runner_hired and player_level>=2 and money>=80:
		money-=80
		runner_hired=true
	elif kind=="collector" and not collector_hired and player_level>=2 and money>=90:
		money-=90
		collector_hired=true
	else:
		return
	ensure_collector()
	ensure_runner()
	ensure_workers()
	play_sound("hire",-15.0)
	save_game()

func ensure_workers() -> void:
	if seller_hired and not is_instance_valid(seller):
		seller=person(Vector3(4,0,-2.4),Color("a46ac1"),"skin_seller")
	if fisher_hired and not is_instance_valid(fisher):
		fisher=person(Vector3(-1,0,2),Color("d47c35"),"skin_fisher")
		bevel(fisher,Vector3(0,0.8,0.43),Vector3(0.65,0.75,0.42),Color("94724f"))
		for strap_x in [-0.23,0.23]:
			box(fisher,Vector3(strap_x,0.78,0.66),Vector3(0.06,0.65,0.035),Color("d1ad72"))
		bevel(fisher,Vector3(0,0.78,0.68),Vector3(0.18,0.1,0.035),Color("cad2d4"))
		for i in range(3):
			var fish := make_fish(fisher,Vector3(0,1.0+float(i)*0.2,0.4))
			fish.scale=Vector3.ONE*0.6
			fisher_fish.append(fish)
		fisher_tool=Node3D.new()
		fisher.add_child(fisher_tool)
		fisher_tool.position=Vector3(0.35,0.8,0)
		box(fisher_tool,Vector3(0.3,0,0),Vector3(0.7,0.08,0.08),Color("ac7747"))
		rounded(fisher_tool,Vector3(0.6,0,0),Vector3(0.12,0.55,0.18),Color("bcdce7"))

func update_fisher(delta: float) -> void:
	if not fisher_hired:
		return
	fisher_timer-=delta
	if fisher_load>=3 or (fisher_stash_full() and fisher_load>0):
		var destination := CATCH_POINT if collector_hired else DROP_CENTER+Vector3(-1.4,0,0)
		fisher.position=fisher.position.move_toward(destination,delta*(2.0+0.65*float(fisher_rank-1))*NPC_SPEED_MULTIPLIER)
		if fisher.position.distance_to(destination)<0.15:
			deposit_fisher()
		return
	if fisher_stash_full():
		return
	var target: Dictionary = {}
	var best: float = INF
	for entry in ice:
		if entry.respawn<=0:
			var dist: float=fisher.position.distance_to(entry.node.position)
			if dist<best:
				best=dist
				target=entry
	if target.is_empty():
		if fisher_load>0:
			var destination := CATCH_POINT if collector_hired else DROP_CENTER+Vector3(-1.4,0,0)
			fisher.position=fisher.position.move_toward(destination,delta*(2.0+0.65*float(fisher_rank-1))*NPC_SPEED_MULTIPLIER)
			if fisher.position.distance_to(destination)<0.15:
				deposit_fisher()
		return
	var goal: Vector3=target.node.position
	goal.y=0
	var direction := goal-fisher.position
	if direction.length()>1.3:
		fisher.position=fisher.position.move_toward(goal,delta*(2.0+0.65*float(fisher_rank-1))*NPC_SPEED_MULTIPLIER)
	elif fisher_timer<=0:
		fisher_timer=1.4/((1.0+0.35*float(fisher_rank-1))*NPC_SPEED_MULTIPLIER)
		target.hp-=1
		fisher.set_meta("work",0.5)
		if hero.position.distance_to(fisher.position)<9:
			play_sound("ice",-21.0)
		if target.hp<=0:
			target.node.visible=false
			target.respawn=7.0
			fisher_load+=1
			gain_xp(1)

var level := 1
var upgrades := {"bag":1,"speed":1,"trade":1}
var selected_upgrade := "tool"
const MAX_LEVEL := 10

func selected_level() -> int:
	return level if selected_upgrade == "tool" else int(upgrades[selected_upgrade])

func upgrade_name() -> String:
	return {"tool":"Інструмент","bag":"Рюкзак","speed":"Швидкість","trade":"Продаж"}[selected_upgrade]

func upgrade_effect() -> String:
	match selected_upgrade:
		"tool": return "Сила удару: %d → %d" % [level,mini(level+1,MAX_LEVEL)]
		"bag": return "Місткість: %d → %d" % [capacity(),5+mini(int(upgrades.bag),MAX_LEVEL-1)*3]
		"speed": return "Швидкість: %.1f → %.1f" % [move_speed(),4.8+float(mini(int(upgrades.speed),MAX_LEVEL-1))*0.35]
		_: return "Ціна риби: %d → %d" % [fish_price(),10+mini(int(upgrades.trade),MAX_LEVEL-1)*2+RECIPE_BONUS[active_recipe]]

func move_speed() -> float:
	return 4.8+float(upgrades.speed-1)*0.35

func fish_price(recipe: int = -1) -> int:
	return 10+int(upgrades.trade-1)*2+RECIPE_BONUS[active_recipe if recipe<0 else clampi(recipe,0,2)]

func choose_upgrade(kind: String) -> void:
	selected_upgrade=kind
	upgrade_hold=0.0
	upgrade_latched=false

var mouse_drag := false
var ground_zones: Array = []
var departing: Array = []
var fisher_fish: Array = []
var fisher_tool: Node3D
var smoke: CPUParticles3D
var seller_activity := 0.0
var seller_rank := 1
var fisher_rank := 1
var served := 0
var cooldown := 0.0
var sell_timer := 0.0
var touch_id := -1
var touch_start := Vector2.ZERO
var stick := Vector2.ZERO
var held := Vector2.ZERO
var clock := 0.0
var save_timer := 0.0
var customers: Array = []
var backpack_fish: Array = []
var hero_legs: Array = []
var tool_pivot: Node3D
var hit_flash := 0.0
var sale_label: Label3D
var upgrade_hold := 0.0
var upgrade_latched := false
const SALE_CENTER := Vector3(3.4,0,-0.4)
const WORKSHOP_CENTER := Vector3(2,0,5)
const ZONE_RADIUS := 0.95

func rounded(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var result := ball(parent,pos,0.5,color)
	result.scale = size
	return result

func zone(pos: Vector3, color: Color, title: String) -> Label3D:
	var root := Node3D.new()
	root.name="ActionPad"
	add_child(root)
	root.position=pos+Vector3(0,0.24,0)
	var disc := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius=ZONE_RADIUS
	cylinder.bottom_radius=ZONE_RADIUS
	cylinder.height=0.04
	cylinder.radial_segments=64
	disc.mesh=cylinder
	disc.material_override=material(color.darkened(0.55))
	root.add_child(disc)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius=ZONE_RADIUS-0.09
	torus.outer_radius=ZONE_RADIUS
	ring.mesh=torus
	ring.scale.y=0.24
	ring.position.y=0.035
	var glow := material(color.lightened(0.3))
	glow.emission_enabled=true
	glow.emission=color*0.5
	ring.material_override=glow
	root.add_child(ring)
	var description := "МАГАЗИН"
	var icon_path := "icons/bag.svg"
	if pos.is_equal_approx(DROP_CENTER):
		description="ВИВАНТАЖИТИ"
		icon_path="icons/bag.svg"
	elif pos.is_equal_approx(COOK_CENTER):
		description="ГОТУВАТИ"
		icon_path="icons/kitchen.svg"
	elif pos.is_equal_approx(PICKUP_POINT):
		description="ЗАБРАТИ СТРАВИ"
		icon_path="icons/recipe_grill.svg"
	elif pos.is_equal_approx(COUNTER_DROP):
		description="СКЛАСТИ СТРАВИ"
		icon_path="icons/recipe_soup.svg"
	elif pos.is_equal_approx(SALE_CENTER):
		description="ПРОДАТИ"
		icon_path="icons/trade.svg"
	elif pos.is_equal_approx(CATCH_POINT):
		description="ЗБІР РИБИ"
		icon_path="icons/bag.svg"
	elif pos.is_equal_approx(COIN_POINT):
		description="ЗІБРАТИ МОНЕТИ"
		icon_path="icons/trade.svg"
	var icon := Sprite3D.new()
	icon.texture=load("res://"+icon_path)
	icon.pixel_size=0.005
	icon.rotation_degrees.x=-90
	icon.position.y=0.04
	icon.shaded=false
	root.add_child(icon)
	var name_label := Label3D.new()
	root.add_child(name_label)
	name_label.text=description
	name_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position=Vector3(0,0.85,-0.2)
	name_label.font_size=48
	name_label.pixel_size=0.006
	name_label.outline_size=12
	name_label.modulate=color.lightened(0.65)
	var value := Label3D.new()
	root.add_child(value)
	value.position=Vector3(0,0.42,0.1)
	value.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	value.font_size=40
	value.pixel_size=0.006
	value.outline_size=10
	value.text=title
	action_zones.append({"pos":pos,"radius":ZONE_RADIUS,"root":root,"title":description})
	return value

var surface_materials: Dictionary = {}
var camera_focus := Vector3.ZERO
const CAMERA_OFFSET := Vector3(0,22,26)
const CAMERA_FOLLOW_SPEED := 6.0

func surface(name: String, repeats: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	var key := name + str(repeats)
	if surface_materials.has(key):
		return surface_materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/" + name + ".png")
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_scale = repeats
	m.uv1_triplanar = true
	m.uv1_world_triplanar = name in ["snow", "water", "wood", "bark"]
	m.roughness = {"snow":0.86,"wood":0.72,"cloth":0.94,"leather":0.65,"bark":0.9}.get(name,0.55)
	m.metallic_specular=0.35
	if name in ["snow","wood","cloth","leather","bark","ice","shop"] or name.begins_with("skin_"):
		var detail: Image=m.albedo_texture.get_image()
		detail.resize(512,512,Image.INTERPOLATE_LANCZOS)
		detail.bump_map_to_normal_map(0.25)
		detail.generate_mipmaps(true)
		m.normal_enabled=true
		m.normal_texture=ImageTexture.create_from_image(detail)
		m.normal_scale=0.12 if name=="snow" else 0.22
	if name == "ice":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.8,0.95,1.0,0.30)
		m.roughness = 0.12
		m.metallic_specular=0.8
		m.rim_enabled=true
		m.rim=0.4
	surface_materials[key] = m
	return m

func make_fish(parent: Node3D, pos: Vector3) -> Node3D:
	var fish := Node3D.new()
	parent.add_child(fish)
	fish.position = pos
	var body := ball(fish, Vector3.ZERO, 0.32, Color("dae8e8"))
	body.scale = Vector3(2.0,0.7,0.8)
	var stripe := ball(fish, Vector3(0,0.09,0),0.25,Color("d76b82"))
	stripe.scale = Vector3(2.1,0.55,0.84)
	var tail := box(fish,Vector3(-0.68,0,0),Vector3(0.28,0.12,0.5),Color("639cae"))
	tail.rotation.y = PI / 4.0
	ball(fish,Vector3(0.42,0.07,0.20),0.055,Color("172b39"))
	return fish

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

func ball(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 32
	shape.rings = 16
	mesh.mesh = shape
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

func person(pos: Vector3, color: Color, skin: String = "") -> Node3D:
	var p := Node3D.new()
	add_child(p)
	p.position = pos
	var coat := rounded(p, Vector3(0,0.65,0), Vector3(0.65,0.95,0.5), color)
	var fabric := surface("cloth" if skin.is_empty() else skin).duplicate() as StandardMaterial3D
	fabric.albedo_color = color if skin.is_empty() else Color.WHITE
	coat.material_override = fabric
	rounded(p, Vector3(0,1.0,-0.03), Vector3(0.62,0.16,0.5), Color("f5eee2"))
	bevel(p, Vector3(0,0.69,0.36), Vector3(0.58,0.7,0.4), Color.WHITE).material_override = surface("leather")
	rounded(p,Vector3(0,0.65,0.57),Vector3(0.34,0.32,0.12),Color("bd925f"))
	for strap in [-0.20,0.20]:
		rounded(p,Vector3(strap,0.8,0),Vector3(0.08,0.67,0.58),Color("725136"))
	for side in [-1.0,1.0]:
		rounded(p,Vector3(side*0.36,0.83,0),Vector3(0.22,0.27,0.25),color).material_override=fabric
		rounded(p,Vector3(side*0.36,0.60,0),Vector3(0.19,0.24,0.24),color).material_override=fabric
		ball(p,Vector3(side*0.36,0.43,0),0.12,Color("543f35"))
	ball(p, Vector3(0,1.22,0), 0.25, Color("f4cca5"))
	var cap := ball(p, Vector3(0,1.42,0), 0.26, color)
	cap.material_override=fabric
	# Jacket zipper, cuffs and layered boot soles.
	box(p,Vector3(0,0.72,-0.26),Vector3(0.016,0.55,0.015),Color("c2c9c9"))
	for side in [-1.0,1.0]:
		bevel(p,Vector3(side*0.17,0.035,-0.03),Vector3(0.23,0.07,0.34),Color("182d36"))
		rounded(p,Vector3(side*0.36,0.49,0),Vector3(0.21,0.09,0.26),Color("d4d9d6"))
	for x in [-0.17,0.17]:
		rounded(p, Vector3(x,0.31,0), Vector3(0.22,0.22,0.26), Color("344958"))
		rounded(p, Vector3(x,0.12,-0.02), Vector3(0.23,0.24,0.34), Color("3e3c37"))
	for side in [-1.0,1.0]:
		ball(p,Vector3(side*0.09,1.24,-0.22),0.028,Color("233440"))
		ball(p,Vector3(side*0.18,1.18,-0.17),0.045,Color("e7a98c"))
	ball(p,Vector3(0,1.19,-0.26),0.055,Color("e9b493"))
	for i in range(12):
		var angle := float(i)*TAU/12.0
		ball(p,Vector3(sin(angle)*0.26,1.36,cos(angle)*0.26),0.065,Color("f5e8ce"))
	for button_y in [0.55,0.72,0.89]:
		ball(p,Vector3(0,button_y,-0.25),0.025,Color("d9c7a1"))
	# Tailored winter clothing: stitched panels, padded pockets, hood and mittens.
	for side in [-1.0,1.0]:
		bevel(p,Vector3(side*0.19,0.62,-0.267),Vector3(0.22,0.20,0.055),color.darkened(0.13))
		box(p,Vector3(side*0.19,0.71,-0.30),Vector3(0.23,0.025,0.015),Color("e6dac2"))
		box(p,Vector3(side*0.19,0.55,-0.30),Vector3(0.17,0.009,0.012),color.lightened(0.25))
		ball(p,Vector3(side*0.41,0.44,-0.06),0.06,Color("6b4f39"))
		for lace in [0.12,0.18,0.24]:
			box(p,Vector3(side*0.17,lace,-0.17),Vector3(0.12,0.014,0.018),Color("b7b9ad"))
		box(p,Vector3(side*0.20,0.73,0.58),Vector3(0.07,0.12,0.035),Color("d6bc80"))
		box(p,Vector3(side*0.20,0.73,0.602),Vector3(0.035,0.06,0.008),Color("615341"))
		box(p,Vector3(side*0.12,1.30,-0.23),Vector3(0.09,0.022,0.024),Color("5a4236"))
	# Hood is open around the face, with a soft light rim and a folded scarf.
	for i in range(11):
		var angle := -PI*0.72+float(i)*PI*1.44/10.0
		ball(p,Vector3(sin(angle)*0.28,1.24+cos(angle)*0.29,-0.12),0.07,Color("eee4d0"))
	bevel(p,Vector3(0,1.02,-0.18),Vector3(0.44,0.14,0.20),Color("ece2cf"))
	bevel(p,Vector3(0.12,0.92,-0.29),Vector3(0.13,0.24,0.045),Color("d6c8ad"))
	box(p,Vector3(0,0.43,-0.25),Vector3(0.53,0.055,0.03),color.darkened(0.28))
	bevel(p,Vector3(0,0.96,0.48),Vector3(0.34,0.14,0.16),Color("b18b61"))
	rig_person(p)
	return p

func _ready() -> void:
	start_pending=FileAccess.file_exists("user://progress.json")
	if start_pending:
		var preferences=JSON.parse_string(FileAccess.get_file_as_string("user://progress.json"))
		if preferences is Dictionary:
			sounds_enabled=bool(preferences.get("sounds_enabled",true))
			audio_volume=clampf(float(preferences.get("audio_volume",1.0)),0.0,1.0)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("a8c9de")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.42
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-25,0)
	sun.light_energy = 1.35
	sun.light_color = Color("fff0d8")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance=50.0
	sun.shadow_bias=0.03
	add_child(sun)
	box(self, Vector3(0,-0.4,0), Vector3(180,0.6,320), Color.WHITE).material_override = surface("snow",Vector3(0.5,0.5,0.5))
	var water := MeshInstance3D.new()
	water.name="River"
	var river_mesh := PlaneMesh.new()
	river_mesh.size=Vector2(9,240)
	river_mesh.subdivide_width=12
	river_mesh.subdivide_depth=240
	water.mesh=river_mesh
	add_child(water)
	water.position=Vector3(-3,0.02,0)
	var water_material := ShaderMaterial.new()
	water_material.shader=load("res://Water.gdshader")
	water_material.set_shader_parameter("water_texture",load("res://textures/water.png"))
	water.material_override=water_material
	box(self, Vector3(4,0.05,-2.25), Vector3(9,0.3,11.5), Color.WHITE).material_override = surface("wood",Vector3(0.5,0.5,0.5))
	for z in range(-7,18):
		rounded(self,Vector3(8.5,0.45,z),Vector3(0.35,1.3,0.35),Color.WHITE).material_override = surface("bark")
	box(self, Vector3(4,0.75,-3), Vector3(3,1.2,1.2), Color.WHITE).material_override = surface("wood")
	bevel(self, Vector3(4,1.4,-3), Vector3(3.6,0.3,1.7), Color.WHITE).material_override = surface("wood")
	sale_label = zone(SALE_CENTER,Color("6ce5aa"),"$")
	# Courtyard is built once below; avoid coplanar overlapping decks.
	create_ground_zones()
	
	for i in range(10):
		var p := Vector3(-5.8 + float(i%3)*2.4,0.8,-7+float(i/3)*4.2)
		var block := rounded(self,p,Vector3(1.8,1.7,1.8),Color("9bdfef"))
		var ice_shape := bevel_mesh(Vector3(1.7,1.7,1.7))
		block.mesh = ice_shape
		block.scale = Vector3.ONE
		block.material_override = surface("ice")
		var fish := make_fish(block,Vector3.ZERO)
		fish.rotation.y = 0.4
		ice.append({"node":block,"hp":3,"respawn":0.0})
	for i in range(14):
		var x := -10.0 if i%2==0 else 9.0
		var z := float(i)*2.4-15
		box(self,Vector3(x,0.6,z),Vector3(0.3,1.2,0.3),Color("765844"))
		var tree := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius=0
		cone.bottom_radius=1.1
		cone.height=2.8
		tree.mesh=cone
		tree.material_override=wind_material(false)
		add_child(tree)
		tree.position=Vector3(x,2,z)
	hero = person(Vector3(0,0,3),Color("208db2"))
	tool_pivot = Node3D.new()
	hero.add_child(tool_pivot)
	tool_pivot.position = Vector3(0.35,0.85,0)
	box(tool_pivot,Vector3(0.25,0,0),Vector3(0.8,0.09,0.09),Color.WHITE).material_override = surface("wood")
	var steel := material(Color("b6d3e0"))
	steel.metallic = 0.65
	steel.roughness = 0.25
	var head := rounded(tool_pivot,Vector3(0.65,0,0),Vector3(0.16,0.65,0.2),Color.WHITE)
	head.material_override = steel
	for child in hero.get_children():
		if child is MeshInstance3D and child.position.y < 0.3:
			hero_legs.append(child)
	decorate_world()
	for i in range(5):
		var carried := make_fish(hero,Vector3(0,1.0+float(i)*0.17,0.42))
		carried.scale = Vector3.ONE*0.65
		carried.rotation.y = float(i%2)*0.3
		carried.visible=false
		backpack_fish.append(carried)
	camera = Camera3D.new()
	add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=17.5
	camera_focus = hero.position
	camera.position = camera_focus + CAMERA_OFFSET
	camera.look_at(camera_focus)
	camera.current = true
	make_ui()
	add_weather()
	cook_label=zone(COOK_CENTER,Color("ff9957"),"≈")
	build_kitchen()
	for i in range(5):
		box(self,Vector3(0.5,1.18,1.7+float(i)*0.3),Vector3(0.75,0.05,0.04),Color("222c33"))
	var fire := ball(self,Vector3(0.5,0.95,2.3),0.24,Color("ff813c"))
	var hot := material(Color("ff8b35"))
	hot.emission_enabled=true
	hot.emission=Color("ff621c")
	fire.material_override=hot
	ensure_workers()
	ensure_runner()
	build_shop_and_tables()
	audio=Node.new()
	audio.set_script(load("res://GameAudio.gd"))
	add_child(audio)
	audio.set_enabled(sounds_enabled)
	audio.set_volume(audio_volume)
	build_catch_point()
	ensure_collector()
	if start_pending:
		var menu := CanvasLayer.new()
		menu.set_script(load("res://StartMenu.gd"))
		menu.game=self
		add_child(menu)

func make_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var overlay := Control.new()
	overlay.set_script(load("res://QuietHUD.gd"))
	overlay.game=self
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	shop_ui=CanvasLayer.new()
	shop_ui.set_script(load("res://ShopUI.gd"))
	shop_ui.game=self
	add_child(shop_ui)

func _input(event: InputEvent) -> void:
	if start_pending or shop_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_drag=event.pressed
		if mouse_drag:
			touch_start=event.position
		else:
			stick=Vector2.ZERO
	if event is InputEventMouseMotion and mouse_drag:
		stick=((event.position-touch_start)/70.0).limit_length()
	# Receive releases even when the finger ends over a UI button.
	if event is InputEventScreenTouch and not event.pressed and event.index == touch_id:
		touch_id = -1
		stick = Vector2.ZERO
	if event is InputEventScreenDrag and event.index == touch_id:
		stick = ((event.position-touch_start)/70.0).limit_length()

func _unhandled_input(event: InputEvent) -> void:
	if start_pending or shop_open:
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id==-1:
			touch_id=event.index
			touch_start=event.position
		elif event.index==touch_id and not event.pressed:
			touch_id=-1
			stick=Vector2.ZERO
	if event is InputEventScreenDrag and event.index==touch_id:
		stick=((event.position-touch_start)/70.0).limit_length()

func _process(delta: float) -> void:
	if start_pending:
		return
	normalise_food()
	clock+=delta
	cooldown-=delta
	var movement := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	movement+=Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
	movement=(movement+stick+held).limit_length()
	if shop_open:
		movement=Vector2.ZERO
	var right := camera.global_basis.x
	var forward := Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
	var travel := right*movement.x+forward*movement.y
	hero.position+=travel*delta*move_speed()
	hero.position.x=clampf(hero.position.x,-7,8)
	hero.position.z=clampf(hero.position.z,-9,16)
	# Exponential smoothing keeps the same follow feel across frame rates.
	camera_focus = camera_focus.lerp(hero.position,1.0-exp(-CAMERA_FOLLOW_SPEED*delta))
	camera.position = camera_focus + CAMERA_OFFSET
	camera.look_at(camera_focus)
	if travel.length()>0.1:
		hero.rotation.y=lerp_angle(hero.rotation.y,atan2(-travel.x,-travel.z),1.0-exp(-14.0*delta))
	animate_worker(hero,travel.length()>0.1,delta)
	hit_flash = maxf(0.0,hit_flash-delta)
	tool_pivot.rotation.z = sin((0.4-hit_flash)*18.0)*hit_flash*2.0
	var message := "Підійди до льоду — герой б'є автоматично."
	for entry in ice:
		var node: MeshInstance3D=entry.node
		if entry.respawn>0:
			entry.respawn-=delta
			if entry.respawn<=0:
				node.visible=true
				entry.hp=3
		elif hero.position.distance_to(Vector3(node.position.x,0,node.position.z))<1.9 and cargo+hero_dish_count<capacity():
			message="Видобуваємо рибу…"
			if cooldown<=0:
				entry.hp-=level
				hit_flash = 0.4
				hero.set_meta("work",0.5)
				play_sound("ice",-17.0)
				cooldown=0.55
				node.scale=Vector3.ONE*0.86
				if entry.hp<=0:
					cargo+=1
					gain_xp(1)
					node.visible=false
					entry.respawn=7.0
		if node.visible:
			node.scale=node.scale.lerp(Vector3.ONE,delta*8)
	if cargo>=capacity():
		message="Рюкзак повний! Неси сиру рибу до печі."
	var old_fisher_pos := fisher.position if is_instance_valid(fisher) else Vector3.ZERO
	update_fisher(delta)
	update_collector(delta)
	if is_instance_valid(fisher):
		var moving := fisher.position.distance_to(old_fisher_pos)>0.001
		if moving:
			var step := fisher.position-old_fisher_pos
			fisher.rotation.y=lerp_angle(fisher.rotation.y,atan2(-step.x,-step.z),1.0-exp(-12.0*delta))
		animate_worker(fisher,moving,delta)
		var work := clampf(fisher.get_meta("work",0.0),0.0,0.5)
		fisher_tool.rotation.z=sin((0.5-work)*PI*3.0)*work*1.8
		for i in range(fisher_fish.size()):
			fisher_fish[i].visible=i<fisher_load
	update_customers(delta)
	update_ground_zones(delta)
	update_player_transfers(delta)
	# The stove cooks from the deposit table even while the hero is elsewhere.
	if hero.position.distance_to(COOK_CENTER)<0.95:
		kitchen_running=true
	if kitchen_running and raw_stock>0 and kitchen_ready<KITCHEN_LIMIT:
		if cook_progress<=0.0:
			cooking_recipe=active_recipe
		cook_progress+=delta
		while cook_progress>=cooking_time(cooking_recipe) and raw_stock>0 and kitchen_ready<KITCHEN_LIMIT:
			cook_progress-=cooking_time(cooking_recipe)
			raw_stock-=1
			kitchen_ready+=1
			kitchen_food.append(cooking_recipe)
			cooking_recipe=active_recipe
			gain_xp(2)
	else:
		cook_progress=0.0
	drop_label.text="↓ %d / %d" % [raw_stock,STOCK_LIMIT]
	cook_label.text="▶" if not kitchen_running else "%d%%" % int(100*cook_progress/cooking_time(cooking_recipe))
	dish_pickup_label.text="%d" % kitchen_ready
	delivery_label.text="%d / %d" % [cooked_stock,STOCK_LIMIT]
	smoke.emitting=kitchen_running and raw_stock>0 and kitchen_ready<KITCHEN_LIMIT
	update_runner(delta)
	update_dish_displays()
	update_coin_pickup(delta)
	sell_timer=maxf(0.0,sell_timer-delta)
	if hero.position.distance_to(SALE_CENTER)<ZONE_RADIUS or seller_hired:
		if hero.position.distance_to(SALE_CENTER)<ZONE_RADIUS:
			message="Продаємо готову рибу." if cooked_stock>0 else "Спочатку приготуй рибу в помаранчевій зоні."
		if cooked_stock>0 and sell_timer<=0 and customer_ready():
			var sold_recipe: int=counter_food.pop_front()
			cooked_stock-=1
			pending_coins+=fish_price(sold_recipe)
			served+=1
			gain_xp(3)
			sell_timer=3.0/(1.0+0.45*float(seller_rank-1)) if seller_hired else 1.0
			complete_customer(sold_recipe)
			seller_activity=0.6
	for i in range(backpack_fish.size()):
		backpack_fish[i].visible = i < cargo
	for i in range(hero_dish_models.size()):
		hero_dish_models[i].visible=i<hero_dish_count
		if i<hero_dish_count:
			show_dish(hero_dish_models[i],hero_food[i])
	sale_label.text = "$ %d" % cooked_stock
	seller_activity=maxf(0.0,seller_activity-delta)
	if is_instance_valid(seller):
		animate_worker(seller,false,delta)
	for marker in action_zones:
		var active: bool=hero.position.distance_to(marker.pos)<ZONE_RADIUS
		var target := 1.0+sin(clock*3.0)*0.025 if active else 1.0
		marker.root.scale=marker.root.scale.lerp(Vector3(target,1,target),1.0-exp(-8*delta))
	catch_label.text="%d / %d" % [catch_stock,CATCH_LIMIT]
	for i in range(catch_models.size()):
		catch_models[i].visible=i<catch_stock
	audio.update_stove(smoke.emitting,hero.position.distance_to(COOK_CENTER))
	save_timer+=delta
	if save_timer>3:
		save_timer=0
		save_game()

func capacity() -> int:
	return 5+(int(upgrades.bag)-1)*3

func price() -> int:
	return int(round(30.0*pow(1.6,float(selected_level()-1))))

func upgrade() -> void:
	if selected_level()<MAX_LEVEL and money>=price():
		money-=price()
		if selected_upgrade=="tool":
			level+=1
		else:
			upgrades[selected_upgrade]=int(upgrades[selected_upgrade])+1
		upgrade_latched=true
		save_game()

func save_game() -> void:
	normalise_food()
	var file := FileAccess.open("user://progress.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"money":money,"level":level,"cargo":cargo,"served":served,"upgrades":upgrades,"player_level":player_level,"xp":xp,"raw_stock":raw_stock,"cooked_stock":cooked_stock,"seller_hired":seller_hired,"fisher_hired":fisher_hired,"fisher_load":fisher_load,"schema":8,"audio_volume":audio_volume,"collector_hired":collector_hired,"collector_rank":collector_rank,"collector_load":collector_load,"catch_stock":catch_stock,"sounds_enabled":sounds_enabled,"kitchen_rank":kitchen_rank,"active_recipe":active_recipe,"recipe_unlocked":recipe_unlocked,"kitchen_running":kitchen_running,"kitchen_food":kitchen_food,"runner_food":runner_food,"hero_food":hero_food,"counter_food":counter_food,"pending_coins":pending_coins,"hero_dish_count":hero_dish_count,"runner_hired":runner_hired,"runner_rank":runner_rank,"kitchen_ready":kitchen_ready,"runner_load":runner_load,"seller_rank":seller_rank,"fisher_rank":fisher_rank}))

func load_game() -> void:
	if not FileAccess.file_exists("user://progress.json"):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://progress.json"))
	if data is Dictionary:
		money=maxi(0,int(data.get("money",0)))
		sounds_enabled=bool(data.get("sounds_enabled",true))
		audio_volume=clampf(float(data.get("audio_volume",1.0)),0.0,1.0)
		collector_hired=bool(data.get("collector_hired",false))
		collector_rank=clampi(int(data.get("collector_rank",1)),1,5)
		collector_load=clampi(int(data.get("collector_load",0)),0,collector_capacity())
		catch_stock=clampi(int(data.get("catch_stock",0)),0,CATCH_LIMIT)
		level=clampi(int(data.get("level",1)),1,MAX_LEVEL)
		var saved_upgrades = data.get("upgrades",{})
		if saved_upgrades is Dictionary:
			for kind in upgrades:
				upgrades[kind]=clampi(int(saved_upgrades.get(kind,1)),1,MAX_LEVEL)
		cargo=clampi(int(data.get("cargo",0)),0,capacity())
		served=maxi(0,int(data.get("served",0)))
		player_level=clampi(int(data.get("player_level",1)),1,50)
		xp=clampi(int(data.get("xp",0)),0,xp_required()-1)
		raw_stock=clampi(int(data.get("raw_stock",0)),0,STOCK_LIMIT)
		cooked_stock=clampi(int(data.get("cooked_stock",0)),0,STOCK_LIMIT)
		kitchen_ready=clampi(int(data.get("kitchen_ready",0)),0,KITCHEN_LIMIT+RUNNER_CAPACITY)
		runner_rank=clampi(int(data.get("runner_rank",1)),1,5)
		runner_hired=bool(data.get("runner_hired",false))
		runner_load=clampi(int(data.get("runner_load",0)),0,runner_capacity())
		pending_coins=maxi(0,int(data.get("pending_coins",0)))
		hero_dish_count=clampi(int(data.get("hero_dish_count",0)),0,capacity()-cargo)
		if not runner_hired and runner_load>0:
			kitchen_ready+=runner_load
			runner_load=0
		seller_hired=bool(data.get("seller_hired",false))
		fisher_hired=bool(data.get("fisher_hired",false))
		fisher_load=clampi(int(data.get("fisher_load",0)),0,3)
		seller_rank=clampi(int(data.get("seller_rank",1)),1,5)
		fisher_rank=clampi(int(data.get("fisher_rank",1)),1,5)
		kitchen_rank=clampi(int(data.get("kitchen_rank",1)),1,5)
		active_recipe=clampi(int(data.get("active_recipe",0)),0,2)
		var unlocked=data.get("recipe_unlocked",[true,false,false])
		if unlocked is Array and unlocked.size()==3:
			recipe_unlocked=[true,bool(unlocked[1]),bool(unlocked[2])]
		if not recipe_unlocked[active_recipe]:
			active_recipe=0
		kitchen_running=bool(data.get("kitchen_running",int(data.get("schema",0))<6))
		kitchen_food=read_food(data.get("kitchen_food",[]))
		runner_food=read_food(data.get("runner_food",[]))
		hero_food=read_food(data.get("hero_food",[]))
		counter_food=read_food(data.get("counter_food",[]))
		normalise_food()

func decorate_world() -> void:
	# Snow banks follow the lake edges without covering the gameplay path.
	for i in range(22):
		var z := -10.0+float(i)
		for x in [-7.7,7.5]:
			var drift := rounded(self,Vector3(x,0.04,z),Vector3(1.3,0.55,1.8),Color.WHITE)
			drift.material_override = surface("snow")
	for i in range(14):
		var x := -10.0 if i%2==0 else 9.0
		var z := float(i)*2.4-15.0
		for tier in range(3):
			var foliage := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.04
			cone.bottom_radius = 1.25-float(tier)*0.25
			cone.height = 1.4
			cone.radial_segments = 24
			foliage.mesh = cone
			foliage.material_override = wind_material(true)
			add_child(foliage)
			foliage.position = Vector3(x,1.7+float(tier)*0.65,z)
	# Bench behind the shop, wooden slats and iron legs.
	for i in range(3):
		box(self,Vector3(5.5,0.58,1.8+float(i)*0.18),Vector3(1.8,0.12,0.14),Color.WHITE).material_override = surface("wood")
	for x in [4.9,6.1]:
		box(self,Vector3(x,0.3,2),Vector3(0.10,0.6,0.45),Color("344b5c"))
	# Detailed market counter: posts, canopy, fish display and sign.
	for x in [2.5,5.5]:
		box(self,Vector3(x,1.7,-3.4),Vector3(0.12,3.0,0.12),Color.WHITE).material_override = surface("wood")
	for i in range(8):
		var color := Color("2c8b9d") if i%2==0 else Color("f4e5c5")
		box(self,Vector3(2.6+float(i)*0.4,3.15,-3.0),Vector3(0.4,0.12,1.9),color)
	for i in range(3):
		var fish := make_dish(self,Vector3(3.0+float(i)*0.8,1.62,-3.0))
		fish.scale = Vector3.ONE*0.55
		fish.rotation.y = 0.65
		fish.visible=false
		counter_dishes.append(fish)
	var sign := Label3D.new()
	add_child(sign)
	sign.position = Vector3(4,2.65,-2.5)
	sign.text = "$"
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.outline_size = 8
	# Fish crates beside the platform.
	for j in range(2):
		var center := Vector3(6.0,0.35,6.6+float(j)*1.2)
		for k in range(3):
			for side in [-1.0,1.0]:
				box(self,center+Vector3(0,float(k)*0.18,side*0.42),Vector3(1.0,0.13,0.08),Color.WHITE).material_override = surface("wood")
		for side in [-1.0,1.0]:
			box(self,center+Vector3(side*0.46,0.2,0),Vector3(0.08,0.55,0.9),Color.WHITE).material_override = surface("wood")
		# Empty decorative crates: no free fish is displayed on a fresh start.

func create_ground_zones() -> void:
	# Purchase pads have moved into the shop interface.
	pass

func update_ground_zones(_delta: float) -> void:
	var distance := hero.position.distance_to(SHOP_ENTRY)
	if distance>1.8:
		shop_entry_armed=true
	if distance<1.1 and shop_entry_armed and not shop_open:
		open_shop()

func open_shop() -> void:
	if hero.position.distance_to(SHOP_ENTRY)>1.4:
		return
	shop_open=true
	shop_entry_armed=false
	stick=Vector2.ZERO
	held=Vector2.ZERO
	touch_id=-1
	mouse_drag=false
	shop_ui.set_open(true)
	play_sound("shop",-19.0)

func close_shop() -> void:
	shop_open=false
	stick=Vector2.ZERO
	mouse_drag=false
	touch_id=-1
	shop_ui.set_open(false)

func shop_item(kind: String) -> Dictionary:
	var titles := {"collector":"Збирач риби","collector_rank":"Розвиток збирача","runner":"Кур’єр","seller":"Продавець","fisher":"Рибалка","tool":"Інструмент","bag":"Рюкзак","speed":"Швидкість героя","trade":"Ціна страви","runner_rank":"Розвиток кур’єра","seller_rank":"Розвиток продавця","fisher_rank":"Розвиток рибалки","kitchen_rank":"Розвиток кухні","recipe_grill":"Риба на грилі","recipe_smoke":"Копчена риба","recipe_soup":"Рибна юшка"}
	if not titles.has(kind):
		return {}
	var cost := 0
	var required := 1
	var kitchen_required := 1
	var current := 1
	var capped := false
	var texture := "wood"
	var detail := ""
	if kind in ["tool","bag","speed","trade"]:
		current=level if kind=="tool" else int(upgrades[kind])
		cost=int(round(30.0*pow(1.6,float(current-1))))
		capped=current>=MAX_LEVEL
		texture="leather" if kind=="bag" else "wood"
		match kind:
			"tool": detail="Сила удару: %d → %d" % [level,mini(level+1,MAX_LEVEL)]
			"bag": detail="Місць: %d → %d" % [capacity(),5+mini(int(upgrades.bag),MAX_LEVEL-1)*3]
			"speed": detail="Швидкість: %.2f → %.2f" % [move_speed(),4.8+float(mini(int(upgrades.speed),MAX_LEVEL-1))*0.35]
			"trade": detail="Монет за страву: %d → %d" % [fish_price(),10+mini(int(upgrades.trade),MAX_LEVEL-1)*2+RECIPE_BONUS[active_recipe]]
		detail="Рівень %d/%d. " % [current,MAX_LEVEL]+detail
	elif kind in ["runner","seller","fisher","collector"]:
		texture="skin_"+kind
		cost={"runner":80,"seller":100,"fisher":180,"collector":90}[kind]
		required=3 if kind=="fisher" else 2
		capped=collector_hired if kind=="collector" else (runner_hired if kind=="runner" else (seller_hired if kind=="seller" else fisher_hired))
		detail={"collector":"Забирає улов біля річки й переносить сиру рибу на кухню.","runner":"Переносить страви з кухні на прилавок.","seller":"Обслуговує чергу, поки ти займаєшся іншими справами.","fisher":"Добуває рибу й приносить її на кухню."}[kind]
	elif kind=="kitchen_rank":
		current=kitchen_rank
		cost=current*150
		required=2
		capped=current>=5
		texture="kitchen"
		detail="Рівень %d/5. Гриль %.1f → %.1f с. Відкриває кращу кухню." % [current,cooking_time(0),3.0/(1.0+0.3*float(mini(current,4)))]
	elif kind.begins_with("recipe_"):
		var recipe := ["recipe_grill","recipe_smoke","recipe_soup"].find(kind)
		cost=0 if recipe_unlocked[recipe] else [0,120,220][recipe]
		required=1 if recipe_unlocked[recipe] else [1,3,4][recipe]
		kitchen_required=1 if recipe_unlocked[recipe] else [1,2,3][recipe]
		capped=active_recipe==recipe
		texture=kind
		detail="%d монет за порцію · %.1f с. Одна сира риба." % [fish_price(recipe),cooking_time(recipe)]
	else:
		var role := kind.replace("_rank","")
		texture="skin_"+role
		current=collector_rank if role=="collector" else (runner_rank if role=="runner" else (seller_rank if role=="seller" else fisher_rank))
		cost=current*120
		required=4
		var hired: bool=collector_hired if role=="collector" else (runner_hired if role=="runner" else (seller_hired if role=="seller" else fisher_hired))
		if not hired:
			required=99
		capped=current>=5
		detail="Рівень %d/5. " % current
		if role=="collector":
			detail+="Швидше доставляє улов; місць %d → %d." % [collector_capacity(),mini(collector_capacity()+1,8)]
		elif role=="runner":
			detail+="Рух %.1f → %.1f; місць %d → %d." % [(2.0+0.65*(current-1))*NPC_SPEED_MULTIPLIER,(2.0+0.65*mini(current,4))*NPC_SPEED_MULTIPLIER,runner_capacity(),mini(runner_capacity()+1,7)]
		elif role=="seller":
			detail+="Обслуговування %.1f → %.1f с." % [3.0/(1.0+0.45*(current-1)),3.0/(1.0+0.45*mini(current,4))]
		else:
			detail+="Рух %.1f → %.1f; удар %.1f → %.1f с." % [(2.0+0.65*(current-1))*NPC_SPEED_MULTIPLIER,(2.0+0.65*mini(current,4))*NPC_SPEED_MULTIPLIER,1.4/((1.0+0.35*(current-1))*NPC_SPEED_MULTIPLIER),1.4/((1.0+0.35*mini(current,4))*NPC_SPEED_MULTIPLIER)]
	var icon := "icons/"+texture+".svg"
	if kind in ["runner","seller","fisher","collector"] or kind.ends_with("_rank") and kind!="kitchen_rank":
		icon="icons/portrait_"+kind.replace("_rank","")+".png"
	elif kind in ["tool","bag","speed","trade"]:
		icon="icons/"+kind+".svg"
	return {"icon":icon,"active":capped if kind.begins_with("recipe_") else false,"title":titles[kind],"cost":cost,"required":required,"kitchen_required":kitchen_required,"capped":capped,"texture":texture,"detail":detail,"available":not capped and player_level>=required and kitchen_rank>=kitchen_required and money>=cost}

func shop_purchase(kind: String) -> bool:
	if not shop_open or hero.position.distance_to(SHOP_ENTRY)>1.4:
		return false
	var item := shop_item(kind)
	if item.is_empty() or not item.available:
		return false
	if kind=="kitchen_rank":
		money-=int(item.cost)
		kitchen_rank+=1
		save_game()
	elif kind.begins_with("recipe_"):
		var recipe := ["recipe_grill","recipe_smoke","recipe_soup"].find(kind)
		money-=int(item.cost)
		recipe_unlocked[recipe]=true
		active_recipe=recipe
		save_game()
	elif kind in ["runner","seller","fisher","collector"]:
		hire(kind)
	elif kind in ["tool","bag","speed","trade"]:
		selected_upgrade=kind
		upgrade()
	else:
		money-=int(item.cost)
		match kind:
			"collector_rank": collector_rank+=1
			"runner_rank": runner_rank+=1
			"seller_rank": seller_rank+=1
			"fisher_rank": fisher_rank+=1
		save_game()
	play_sound("hire",-18.0)
	return true

func customer_ready() -> bool:
	return not customers.is_empty() and customers[0].position.distance_to(Vector3(4,0,-4.4))<0.15

func complete_customer(recipe: int = 0) -> void:
	var buyer: Node3D=customers.pop_front()
	var parcel := make_dish(buyer,Vector3(0,0.8,-0.45),recipe)
	parcel.name="Purchase"
	parcel.scale=Vector3.ONE*0.5
	departing.append(buyer)
	if is_instance_valid(seller):
		seller.set_meta("handover",0.65)
	play_sound("sale",-20.0)
	transfer_visual(Vector3(4,1.7,-3),COIN_POINT+Vector3(0,0.5,0),"coin")

func animate_worker(actor: Node3D, moving: bool, delta: float) -> void:
	if not actor.has_meta("rig"):
		return
	var rig: Dictionary=actor.get_meta("rig")
	var travelled: float=actor.position.distance_to(rig.last)
	rig.last=actor.position
	var previous: float=rig.phase
	if moving:
		rig.phase+=minf(travelled*4.2,delta*13.0)
	var phase: float=rig.phase
	var speed := travelled/maxf(delta,0.001)
	var amplitude := clampf(speed*0.19,0.25,0.65) if moving else 0.0
	var weight := 1.0-exp(-12.0*delta)
	var carrying: bool=(actor==runner and runner_load>0) or (actor==hero and hero_dish_count>0) or actor.has_node("Purchase")
	var handover: float=maxf(0.0,float(actor.get_meta("handover",0.0))-delta)
	var work: float=maxf(0.0,float(actor.get_meta("work",0.0))-delta)
	actor.set_meta("handover",handover)
	actor.set_meta("work",work)
	for i in range(2):
		var stride := sin(phase+float(i)*PI)
		var hip: Node3D=rig.hips[i]
		var knee: Node3D=rig.knees[i]
		var arm: Node3D=rig.arms[i]
		var elbow: Node3D=rig.elbows[i]
		hip.rotation.x=lerpf(hip.rotation.x,stride*amplitude,weight)
		knee.rotation.x=lerpf(knee.rotation.x,maxf(0.0,-stride)*amplitude*0.6,weight)
		var arm_target := -stride*amplitude*0.55
		if carrying:
			arm_target=0.85+sin(phase*2)*0.025
		if handover>0:
			arm_target=0.95
		if work>0 and i==1:
			arm_target=sin((0.5-work)*PI*3.0)*0.85
		arm.rotation.x=lerpf(arm.rotation.x,arm_target,weight)
		elbow.rotation.x=lerpf(elbow.rotation.x,0.25 if carrying or handover>0 else 0.06,weight)
	var body: Node3D=rig.body
	body.position.y=0.65+(absf(sin(phase))*0.025 if moving else sin(clock*1.6+rig.offset)*0.006)
	body.rotation.z=lerpf(body.rotation.z,sin(phase)*amplitude*0.045 if moving else 0.0,weight)
	body.rotation.x=lerpf(body.rotation.x,0.12 if handover>0 else (0.035 if moving and carrying else 0.0),weight)
	if moving and int(phase/PI)!=int(previous/PI) and hero.position.distance_to(actor.position)<7:
		play_sound("step",-22.0 if actor==hero else -29.0)

func update_customers(delta: float) -> void:
	customer_timer-=delta
	if cooked_stock>0 and customers.size()+departing.size()<6 and customer_timer<=0:
		customers.append(person(Vector3(4,0,-12),Color("e1ac40")))
		customer_timer=1.6
	for i in range(customers.size()):
		var buyer: Node3D=customers[i]
		var target := Vector3(4,0,-4.4-float(i)*0.85)
		var moving := buyer.position.distance_to(target)>0.02
		buyer.position=buyer.position.move_toward(target,delta*1.8*CUSTOMER_SPEED_MULTIPLIER)
		buyer.rotation.y=lerp_angle(buyer.rotation.y,PI,1.0-exp(-10.0*delta))
		animate_worker(buyer,moving,delta)
	for i in range(departing.size()-1,-1,-1):
		var buyer: Node3D=departing[i]
		var target := Vector3(7.4,0,-4.4) if buyer.position.x<7.3 else Vector3(7.4,0,-12)
		var direction := target-buyer.position
		buyer.rotation.y=lerp_angle(buyer.rotation.y,atan2(-direction.x,-direction.z),1.0-exp(-10.0*delta))
		buyer.position=buyer.position.move_toward(target,delta*2.5*CUSTOMER_SPEED_MULTIPLIER)
		animate_worker(buyer,true,delta)
		if buyer.position.z<=-11.9:
			buyer.get_node("Purchase").queue_free()
			buyer.position=Vector3(4,0,-12)
			departing.remove_at(i)
			customers.append(buyer)

func add_weather() -> void:
	var snow := CPUParticles3D.new()
	add_child(snow)
	snow.position=Vector3(0,8,2)
	snow.amount=120
	snow.lifetime=7.0
	snow.preprocess=7.0
	snow.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents=Vector3(14,1,18)
	snow.direction=Vector3(0.45,-1,0.12)
	snow.initial_velocity_min=0.7
	snow.initial_velocity_max=1.3
	snow.gravity=Vector3(0,-0.15,0)
	var flake := SphereMesh.new()
	flake.radius=0.035
	flake.height=0.07
	flake.radial_segments=4
	flake.rings=2
	snow.mesh=flake
	snow.material_override=material(Color.WHITE)
	smoke=CPUParticles3D.new()
	add_child(smoke)
	smoke.position=Vector3(0.5,1.3,2.3)
	smoke.amount=12
	smoke.lifetime=1.4
	smoke.direction=Vector3.UP
	smoke.gravity=Vector3(0,0.15,0)
	smoke.initial_velocity_min=0.4
	smoke.initial_velocity_max=0.7
	var puff := SphereMesh.new()
	puff.radius=0.12
	puff.height=0.24
	puff.radial_segments=8
	puff.rings=4
	smoke.mesh=puff
	var steam := material(Color(0.9,0.96,1,0.28))
	steam.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.material_override=steam
	smoke.emitting=false

func wind_material(snowy: bool) -> ShaderMaterial:
	var key := "wind_"+str(snowy)
	if surface_materials.has(key):
		return surface_materials[key]
	var result := ShaderMaterial.new()
	result.shader=load("res://Wind.gdshader")
	result.set_shader_parameter("textured",false)
	result.set_shader_parameter("base_color",Color("c7e8df") if snowy else Color("5caa8b"))
	result.set_shader_parameter("strength",0.16 if snowy else 0.10)
	surface_materials[key]=result
	return result

func bevel_mesh(size: Vector3) -> ArrayMesh:
	var key := str(size)
	if mesh_cache.has(key):
		return mesh_cache[key]
	var source := BoxMesh.new()
	source.size=Vector3.ONE
	source.subdivide_width=2
	source.subdivide_height=2
	source.subdivide_depth=2
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	for i in range(vertices.size()):
		var v: Vector3=vertices[i]
		var core := v.clamp(Vector3.ONE*-0.36,Vector3.ONE*0.36)
		var normal := (v-core).normalized()
		vertices[i]=(core+normal*0.14)*size
		normals[i]=(normal/size).normalized()
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	# Recompute tangents for normal-mapped bevel surfaces.
	arrays[Mesh.ARRAY_TANGENT]=null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var st := SurfaceTool.new()
	st.create_from(mesh,0)
	st.generate_tangents()
	var result := st.commit()
	mesh_cache[key]=result
	return result

func bevel(parent: Node3D,pos: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh=bevel_mesh(size)
	result.material_override=material(color)
	parent.add_child(result)
	result.position=pos
	return result

func make_dish(parent: Node3D,pos: Vector3,recipe: int = 0) -> Node3D:
	var dish := Node3D.new()
	parent.add_child(dish)
	dish.position=pos
	for kind in range(3):
		var group := Node3D.new()
		group.name="Food%d" % kind
		dish.add_child(group)
		if kind==2:
			rounded(group,Vector3(0,0.05,0),Vector3(0.7,0.3,0.6),Color("e4ddcb"))
			rounded(group,Vector3(0,0.19,0),Vector3(0.59,0.03,0.49),Color("d9a25e"))
			for x in [-0.14,0.12]:
				ball(group,Vector3(x,0.21,0.06),0.08,Color("e8d4a7"))
		else:
			rounded(group,Vector3.ZERO,Vector3(0.9,0.08,0.6),Color("e9e6d9"))
			rounded(group,Vector3(0,0.07,0),Vector3(0.65,0.12,0.3),Color("d89a54") if kind==0 else Color("a16a43"))
			for x in [-0.18,0.0,0.18]:
				box(group,Vector3(x,0.13,0),Vector3(0.025,0.01,0.23),Color("844a2c"))
		ball(group,Vector3(0.30,0.08,0.15),0.07,Color("d3c75e"))
		ball(group,Vector3(-0.28,0.08,0.15),0.06,Color("609655"))
	show_dish(dish,recipe)
	return dish

func show_dish(dish: Node3D,recipe: int) -> void:
	for i in range(3):
		dish.get_node("Food%d" % i).visible=i==recipe

func ensure_runner() -> void:
	if is_instance_valid(runner) or not runner_hired:
		return
	runner=person(PICKUP_POINT,Color("639d88"),"skin_runner")
	# Larger insulated carrier bag, straps and a metal clasp.
	bevel(runner,Vector3(0,0.8,0.45),Vector3(0.7,0.85,0.5),Color("53696d"))
	for x in [-0.22,0.22]:
		box(runner,Vector3(x,0.8,0.72),Vector3(0.06,0.75,0.04),Color("ccad7a"))
	bevel(runner,Vector3(0,0.84,0.73),Vector3(0.16,0.12,0.04),Color("cad1ca"))
	for i in range(7):
		var dish := make_dish(runner,Vector3(0,1.28+float(i)*0.16,0.45))
		dish.scale=Vector3.ONE*0.65
		dish.visible=false
		runner_dishes.append(dish)
	runner_state="deliver" if runner_load>0 else "pickup"
	runner_waypoint=0

func update_runner(delta: float) -> void:
	normalise_food()
	if not runner_hired or not is_instance_valid(runner):
		return
	var target := PICKUP_POINT
	if runner_state=="deliver":
		target=RUNNER_ROUTE[runner_waypoint]
	elif runner_state=="return":
		target=RUNNER_ROUTE[0] if runner_waypoint==0 else PICKUP_POINT
	var direction := target-runner.position
	var moving := direction.length()>0.05
	if moving:
		runner.position=runner.position.move_toward(target,delta*(2.0+0.65*float(runner_rank-1))*NPC_SPEED_MULTIPLIER)
		runner.rotation.y=lerp_angle(runner.rotation.y,atan2(-direction.x,-direction.z),1.0-exp(-12*delta))
	animate_worker(runner,moving,delta)
	if runner.position.distance_to(target)<0.06:
		if runner_state=="pickup":
			var count := mini(runner_capacity(),mini(kitchen_ready,STOCK_LIMIT-cooked_stock))
			if count>0:
				kitchen_ready-=count
				runner_load=count
				runner.set_meta("handover",0.6)
				runner_food=move_food(kitchen_food,count)
				transfer_visual(KITCHEN_TABLE_TOP,runner.position+Vector3(0,1.4,0.4),"dish")
				runner_state="deliver"
				runner_waypoint=0
		elif runner_state=="deliver":
			if runner_waypoint<RUNNER_ROUTE.size()-1:
				runner_waypoint+=1
			else:
				var delivered := mini(runner_load,STOCK_LIMIT-cooked_stock)
				cooked_stock+=delivered
				if delivered>0:
					runner.set_meta("handover",0.6)
				counter_food.append_array(move_food(runner_food,delivered))
				if delivered>0:
					transfer_visual(runner.position+Vector3(0,1.4,0.4),SALES_TABLE_TOP,"dish")
				runner_load-=delivered
				if runner_load==0:
					runner_state="return"
					runner_waypoint=0
		else:
			if runner_waypoint==0:
				runner_waypoint=1
			else:
				runner_state="pickup"
	for i in range(runner_dishes.size()):
		runner_dishes[i].visible=i<runner_load
		if i<runner_load:
			show_dish(runner_dishes[i],runner_food[i])

func update_dish_displays() -> void:
	normalise_food()
	for i in range(kitchen_dishes.size()):
		kitchen_dishes[i].visible=i<kitchen_ready
		if i<kitchen_ready:
			show_dish(kitchen_dishes[i],kitchen_food[i])
	for i in range(counter_dishes.size()):
		counter_dishes[i].visible=i<cooked_stock
		if i<cooked_stock:
			show_dish(counter_dishes[i],counter_food[i])

func build_kitchen() -> void:
	var steel := material(Color("84969b"))
	steel.metallic=0.65
	steel.roughness=0.32
	var stove := bevel(self,Vector3(0.35,0.65,2.2),Vector3(1.35,1.2,1.7),Color.WHITE)
	stove.material_override=steel
	bevel(self,Vector3(0.35,0.65,1.32),Vector3(0.9,0.6,0.06),Color("293f4b"))
	for x in [-0.1,0.2,0.5,0.8]:
		ball(self,Vector3(x,1.05,1.3),0.05,Color("d7cfc1"))
	bevel(self,Vector3(0.35,2.1,2.2),Vector3(1.65,0.3,1.95),Color("5e727c"))
	box(self,Vector3(0.35,2.7,2.5),Vector3(0.4,1.1,0.4),Color("7f9095"))
	var prep := bevel(self,Vector3(0.35,0.9,3.65),Vector3(1.4,0.15,1.1),Color.WHITE)
	prep.material_override=surface("wood")
	for x in [-0.15,0.85]:
		box(self,Vector3(x,0.5,3.65),Vector3(0.1,0.8,0.85),Color("3d535a"))
	bevel(self,Vector3(2.6,1.05,3.8),Vector3(1.6,0.15,0.9),Color("aebcba"))
	for x in [2.0,3.2]:
		box(self,Vector3(x,0.6,3.8),Vector3(0.1,0.9,0.7),Color("40545c"))
	for i in range(3):
		var dish := make_dish(self,Vector3(2.1+float(i)*0.5,1.2,3.8))
		dish.scale=Vector3.ONE*0.5
		dish.visible=false
		kitchen_dishes.append(dish)
	var glow := OmniLight3D.new()
	add_child(glow)
	glow.position=Vector3(0.35,1.45,2.2)
	glow.light_color=Color("ffc982")
	glow.light_energy=0.65
	glow.omni_range=3.2

func runner_capacity() -> int:
	return RUNNER_CAPACITY+runner_rank-1

func update_player_transfers(delta: float) -> void:
	transfer_timer=maxf(0.0,transfer_timer-delta)
	if transfer_timer>0:
		return
	if collector_hired and hero.position.distance_to(CATCH_POINT)<0.95 and cargo>0 and catch_stock<CATCH_LIMIT:
		cargo-=1
		catch_stock+=1
		transfer_visual(hero.position+Vector3(0,1.4,0),CATCH_POINT+Vector3(0,0.6,0),"raw")
		transfer_timer=0.07
	elif hero.position.distance_to(DROP_CENTER)<0.95 and cargo>0 and raw_stock<STOCK_LIMIT:
		cargo-=1
		raw_stock+=1
		transfer_visual(hero.position+Vector3(0,1.4,0),RAW_TABLE_TOP,"raw")
		transfer_timer=0.07
	elif hero.position.distance_to(PICKUP_POINT)<0.85 and kitchen_ready>0 and cargo+hero_dish_count<capacity():
		var recipe: int=kitchen_food.pop_front()
		kitchen_ready-=1
		hero_dish_count+=1
		hero_food.append(recipe)
		transfer_visual(KITCHEN_TABLE_TOP,hero.position+Vector3(0,1.4,0),"dish",recipe)
		transfer_timer=0.07
	elif hero.position.distance_to(COUNTER_DROP)<0.95 and hero_dish_count>0 and cooked_stock<STOCK_LIMIT:
		var recipe: int=hero_food.pop_front()
		hero_dish_count-=1
		cooked_stock+=1
		counter_food.append(recipe)
		transfer_visual(hero.position+Vector3(0,1.4,0),SALES_TABLE_TOP,"dish",recipe)
		transfer_timer=0.07

func transfer_visual(start: Vector3,finish: Vector3,kind: String,recipe: int = 0) -> void:
	if kind!="coin":
		play_sound("transfer",-24.0)
	var model: Node3D
	if kind=="coin":
		model=make_coin(self,start)
	else:
		model=make_fish(self,start) if kind=="raw" else make_dish(self,start,recipe)
		model.scale=Vector3.ONE*0.5
	var tween := create_tween()
	tween.tween_method(func(t: float): model.position=start.lerp(finish,t)+Vector3.UP*sin(t*PI)*0.45,0.0,1.0,0.18)
	tween.tween_callback(model.queue_free)

func make_coin(parent: Node3D,pos: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius=0.12
	disc.bottom_radius=0.12
	disc.height=0.045
	disc.radial_segments=16
	mesh.mesh=disc
	var gold := material(Color("f8c75c"))
	gold.metallic=0.65
	gold.roughness=0.28
	mesh.material_override=gold
	parent.add_child(mesh)
	mesh.position=pos
	return mesh

func update_coin_pickup(delta: float) -> void:
	coin_timer=maxf(0.0,coin_timer-delta)
	if pending_coins>0 and hero.position.distance_to(COIN_POINT)<0.9 and coin_timer<=0:
		var amount := mini(pending_coins,20)
		pending_coins-=amount
		money+=amount
		play_sound("coin",-18.0)
		transfer_visual(COIN_POINT+Vector3(0,0.4,0),hero.position+Vector3(0,1,0.4),"coin")
		coin_timer=0.04
	for i in range(coin_models.size()):
		coin_models[i].visible=i<mini(30,int(ceil(float(pending_coins)/10.0)))
	coin_label.text=str(pending_coins) if pending_coins>0 else "$"
	for i in range(raw_table_models.size()):
		raw_table_models[i].visible=i<raw_stock

func table(pos: Vector3,size: Vector3) -> void:
	bevel(self,pos+Vector3(0,1,0),Vector3(size.x,0.16,size.z),Color.WHITE).material_override=surface("shop")
	for x in [-size.x*0.35,size.x*0.35]:
		for z in [-size.z*0.35,size.z*0.35]:
			box(self,pos+Vector3(x,0.55,z),Vector3(0.09,0.9,0.09),Color("43585b"))

func build_shop_and_tables() -> void:
	# A real shop building and courtyard surround the automatic purchase pads.
	box(self,Vector3(2.25,0.05,10.25),Vector3(12.5,0.3,13.5),Color.WHITE).material_override=surface("wood",Vector3(0.5,0.5,0.5))
	zone(SHOP_ENTRY,Color("e3c891"),"МАГАЗИН")
	var shop := Node3D.new()
	shop.name="Shop"
	add_child(shop)
	bevel(shop,Vector3(1.5,1.6,14),Vector3(5.5,3,2.4),Color.WHITE).material_override=surface("shop")
	bevel(shop,Vector3(1.5,3.2,14),Vector3(6.1,0.45,3),Color.WHITE).material_override=surface("snow")
	for x in [-0.2,3.2]:
		bevel(shop,Vector3(x,1.8,15.23),Vector3(1.1,1.25,0.08),Color("e4bb72"))
		box(shop,Vector3(x,1.8,15.3),Vector3(0.06,1.25,0.04),Color("495c5d"))
	bevel(shop,Vector3(1.5,1.2,15.24),Vector3(0.9,2.1,0.10),Color("7a5438"))
	var sign := Label3D.new()
	shop.add_child(sign)
	sign.position=Vector3(1.5,3.75,14)
	sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sign.text="МАГАЗИН"
	sign.font_size=44
	sign.pixel_size=0.007
	sign.outline_size=8
	table(Vector3(5.7,0,-1.9),Vector3(1.5,0,1.1))
	# Display the actual sales inventory on the receiving table.
	for i in range(counter_dishes.size()):
		counter_dishes[i].position=SALES_TABLE_TOP+Vector3((float(i)-1)*0.42,0,0)
	for i in range(5):
		var fish := make_fish(self,RAW_TABLE_TOP+Vector3(0,0.07*float(i),0))
		fish.scale=Vector3.ONE*0.55
		raw_table_models.append(fish)
		var dish := make_dish(hero,Vector3(0,1.3+float(i)*0.15,0.45))
		dish.scale=Vector3.ONE*0.6
		dish.visible=false
		hero_dish_models.append(dish)
	drop_label=zone(DROP_CENTER,Color("6caac8"),"↓")
	dish_pickup_label=zone(PICKUP_POINT,Color("e7c481"),"0")
	delivery_label=zone(COUNTER_DROP,Color("88cead"),"0")
	coin_label=zone(COIN_POINT,Color("f5c65e"),"$")
	for i in range(30):
		var coin := make_coin(self,COIN_POINT+Vector3(float(i%3)*0.25-0.25,0.3+float(i/9)*0.07,float((i/3)%3)*0.25-0.25))
		coin.visible=false
		coin_models.append(coin)

func cooking_time(recipe: int) -> float:
	return RECIPE_TIMES[clampi(recipe,0,2)]/(1.0+0.3*float(kitchen_rank-1))

func normalise_food() -> void:
	for pair in [[kitchen_food,kitchen_ready],[runner_food,runner_load],[hero_food,hero_dish_count],[counter_food,cooked_stock]]:
		var food: Array=pair[0]
		var count: int=pair[1]
		while food.size()<count:
			food.append(0)
		if food.size()>count:
			food.resize(count)

func move_food(source: Array,count: int) -> Array:
	var result: Array=[]
	for i in range(mini(count,source.size())):
		result.append(source.pop_front())
	return result

func read_food(value: Variant) -> Array:
	var result: Array=[]
	if value is Array:
		for item in value:
			result.append(clampi(int(item),0,2))
	return result

func rig_person(actor: Node3D) -> void:
	var hips: Array=[]
	var knees: Array=[]
	var ankles: Array=[]
	var arms: Array=[]
	var elbows: Array=[]
	for side in [-1.0,1.0]:
		var hip := Node3D.new()
		actor.add_child(hip)
		hip.position=Vector3(side*0.17,0.4,0)
		hips.append(hip)
		var knee := Node3D.new()
		hip.add_child(knee)
		knee.position=Vector3(0,-0.15,0)
		knees.append(knee)
		var ankle := Node3D.new()
		knee.add_child(ankle)
		ankle.position=Vector3(0,-0.15,0)
		ankles.append(ankle)
		var arm := Node3D.new()
		actor.add_child(arm)
		arm.position=Vector3(side*0.33,0.96,0)
		arms.append(arm)
		var elbow := Node3D.new()
		arm.add_child(elbow)
		elbow.position=Vector3(0,-0.23,0)
		elbows.append(elbow)
	for child in actor.get_children():
		if not child is MeshInstance3D:
			continue
		var pos: Vector3=child.position
		var side := 0 if pos.x<0 else 1
		if pos.y<0.4 and absf(pos.x)>0.1:
			child.reparent(ankles[side] if pos.y<0.25 else hips[side],true)
		elif absf(pos.x)>0.3 and pos.y<0.95 and pos.y>0.4:
			child.reparent(elbows[side] if pos.y<0.74 else arms[side],true)
	var body := Node3D.new()
	actor.add_child(body)
	body.position=Vector3(0,0.65,0)
	for child in actor.get_children():
		if child is MeshInstance3D:
			child.reparent(body,true)
	var head := Node3D.new()
	body.add_child(head)
	head.position=Vector3(0,0.55,0)
	for child in body.get_children():
		if child is MeshInstance3D and child.position.y>0.4:
			child.reparent(head,true)
	actor.set_meta("rig",{"hips":hips,"knees":knees,"ankles":ankles,"head":head,"arms":arms,"elbows":elbows,"body":body,"phase":0.0,"last":actor.position,"offset":actor.position.x+actor.position.z})

func play_sound(name: String, volume: float = -18.0) -> void:
	if is_instance_valid(audio):
		audio.play_event(name,volume)

func toggle_audio() -> void:
	sounds_enabled=not sounds_enabled
	audio.set_enabled(sounds_enabled)
	audio.set_volume(audio_volume)
	save_game()

func continue_saved() -> void:
	if not start_pending:
		return
	load_game()
	normalise_food()
	ensure_workers()
	ensure_runner()
	ensure_collector()
	audio.set_enabled(sounds_enabled)
	audio.set_volume(audio_volume)
	start_pending=false

func start_fresh() -> bool:
	if not start_pending:
		return false
	var source := ProjectSettings.globalize_path("user://progress.json")
	var backup := ProjectSettings.globalize_path("user://progress.before-new-game.json")
	if FileAccess.file_exists(source):
		if DirAccess.copy_absolute(source,backup)!=OK:
			return false
		if DirAccess.remove_absolute(source)!=OK:
			return false
	start_pending=false
	return true

func set_audio_volume(value: float) -> void:
	audio_volume=clampf(value,0.0,1.0)
	audio.set_volume(audio_volume)
	save_game()

func collector_capacity() -> int:
	return 4+collector_rank-1

func fisher_stash_full() -> bool:
	return catch_stock>=CATCH_LIMIT if collector_hired else raw_stock>=STOCK_LIMIT

func deposit_fisher() -> void:
	var available := CATCH_LIMIT-catch_stock if collector_hired else STOCK_LIMIT-raw_stock
	var amount := mini(fisher_load,available)
	if collector_hired:
		catch_stock+=amount
	else:
		raw_stock+=amount
	fisher_load-=amount
	if amount>0:
		fisher.set_meta("handover",0.5)

func ensure_collector() -> void:
	if not collector_hired or is_instance_valid(collector):
		return
	collector=person(CATCH_POINT,Color("507f9c"))
	bevel(collector,Vector3(0,0.8,0.45),Vector3(0.75,0.85,0.5),Color("a48660"))
	for x in [-0.23,0.23]:
		box(collector,Vector3(x,0.8,0.72),Vector3(0.06,0.7,0.04),Color("e3cda5"))
	for i in range(8):
		var fish := make_fish(collector,Vector3(0,1.1+float(i)*0.12,0.45))
		fish.scale=Vector3.ONE*0.55
		fish.visible=false
		collector_fish.append(fish)

func update_collector(delta: float) -> void:
	if not collector_hired or not is_instance_valid(collector):
		return
	var target := DROP_CENTER+Vector3(-1.3,0,0) if collector_load>0 else CATCH_POINT
	var direction := target-collector.position
	var moving := direction.length()>0.08
	if moving:
		collector.position=collector.position.move_toward(target,delta*(1.6+0.4*float(collector_rank-1)))
		collector.rotation.y=lerp_angle(collector.rotation.y,atan2(-direction.x,-direction.z),1.0-exp(-10*delta))
	animate_worker(collector,moving,delta)
	if collector.position.distance_to(target)<0.1:
		if collector_load>0:
			var amount := mini(collector_load,STOCK_LIMIT-raw_stock)
			raw_stock+=amount
			collector_load-=amount
			if amount>0:
				collector.set_meta("handover",0.5)
				transfer_visual(collector.position+Vector3(0,1.3,0),RAW_TABLE_TOP,"raw")
		elif catch_stock>0 and raw_stock<STOCK_LIMIT:
			var amount := mini(collector_capacity(),mini(catch_stock,STOCK_LIMIT-raw_stock))
			catch_stock-=amount
			collector_load=amount
			collector.set_meta("handover",0.5)
			transfer_visual(CATCH_POINT+Vector3(0,0.6,0),collector.position+Vector3(0,1.3,0),"raw")
	for i in range(collector_fish.size()):
		collector_fish[i].visible=i<collector_load

func build_catch_point() -> void:
	# Collection point stands on the existing continuous courtyard.
	bevel(self,Vector3(-1.5,0.5,5.9),Vector3(1.2,0.5,0.7),Color.WHITE).material_override=surface("shop")
	catch_label=zone(CATCH_POINT,Color("81c5e8"),"0")
	for i in range(6):
		var fish := make_fish(self,Vector3(-1.5,0.8+float(i)*0.07,5.9))
		fish.scale=Vector3.ONE*0.55
		fish.visible=false
		catch_models.append(fish)
