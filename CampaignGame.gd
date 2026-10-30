extends "res://Game.gd"
const CLOTHES = preload("res://Wardrobe.gd")
const DATA = preload("res://CampaignData.gd")
var profile: Dictionary = DATA.new_profile()
var zone_live: Array = []
var fish_live: Array = []
var fish_by_zone: Dictionary = {}
var workers_live: Array = []
var buyers_live: Array = []
var pads: Array = []
var hero_velocity := Vector3.ZERO
var hero_carry_models: Array = []
var selected_zone := 0
var deposit_clock := 0.0
var buyer_clock := 0.0
var campaign_ui: CanvasLayer
var water_y := -0.8
var material_cache: Dictionary = {}
var sphere_cache: Dictionary = {}
var render_cache: Dictionary = {}
var unlocked_hold := {}
var snowfall: CPUParticles3D
var kitchen_steam: Array = []
var furniture: Array = []
var ice_effects: Array = []
var sound_mix := {"effects":1.0,"music":0.32,"ambient":0.70}
const TUTORIAL_STEPS := 12
var tutorial_walk := 0.0
var tutorial_marker: Label3D
var customer_serial := 0
var wind_clock := 0.0
var paused := false
var economy_graphics := true
var weak_device := false
var zone_celebration: Control
var streamed_zone := -100
var worker_counts: Dictionary = {}
var worker_count_size := -1
var display_timer := 0.0
var region_roots: Dictionary = {}
var coastline_cache: Dictionary = {}
var ice_fragment_mesh: ArrayMesh
var ice_fragment_material: StandardMaterial3D

func _ready() -> void:
 profile=DATA.new_profile()
 start_pending=true
 var old=read_progress()
 if not old.is_empty():
  if old is Dictionary:
   sounds_enabled=bool(old.get("sounds_enabled",true))
   audio_volume=clampf(float(old.get("audio_volume",1.0)),0,1)
   sound_mix=read_sound_mix(old.get("sound_mix",{}))
 build_environment()
 snowfall=make_particles(Vector3(0,8,0),40,7.0,true)
 zone_live.resize(DATA.ZONES.size())
 kitchen_steam.resize(DATA.ZONES.size())
 for i in range(DATA.ZONES.size()):
  zone_live[i]={"floor":null,"sale_clock":0.0,"gate_hold":0.0,"business_open":false}
 ensure_zone(0)
 ensure_zone(1)
 hero=person(Vector3(2,0.2,4),Color("218caf"),"",profile.wardrobe.equipped)
 hero.name="Hero"
 tutorial_marker=Label3D.new()
 tutorial_marker.text="↓"
 tutorial_marker.font_size=76
 tutorial_marker.pixel_size=0.01
 tutorial_marker.modulate=Color("f3d58b")
 tutorial_marker.outline_size=8
 tutorial_marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 tutorial_marker.visible=false
 add_child(tutorial_marker)
 hero_carry_models=carry_models(hero,3)
 tool_pivot=make_pickaxe(hero)
 camera=Camera3D.new()
 add_child(camera)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=20.0
 camera_focus=hero.position
 camera.position=camera_focus+Vector3(14,22,25)
 camera.look_at(camera_focus)
 camera.current=true
 camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
 audio=Node.new()
 audio.set_script(load("res://GameAudio.gd"))
 add_child(audio)
 audio.set_enabled(sounds_enabled)
 audio.set_volume(audio_volume)
 apply_sound_mix()
 var overlay := CanvasLayer.new()
 add_child(overlay)
 var hud := Control.new()
 hud.set_script(load("res://CampaignHUD.gd"))
 hud.game=self
 hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
 overlay.add_child(hud)
 campaign_ui=CanvasLayer.new()
 campaign_ui.set_script(load("res://CampaignUI.gd"))
 campaign_ui.game=self
 add_child(campaign_ui)
 var controls := CanvasLayer.new()
 controls.set_script(load("res://GameMenu.gd"))
 controls.game=self
 add_child(controls)
 shop_ui=campaign_ui
 refresh_unlocks()
 var preferences := ConfigFile.new()
 var economy := true
 if preferences.load("user://settings.cfg")==OK:economy=bool(preferences.get_value("graphics","economy",true))
 weak_device=bool(preferences.get_value("graphics","weak_device",false))
 set_economy_graphics(economy)
 set_weak_device(weak_device)
 if start_pending:
  var menu := CanvasLayer.new()
  menu.set_script(load("res://StartMenu.gd"))
  menu.game=self
  add_child(menu)

func _process(delta: float) -> void:
 if start_pending or paused:return
 camera_focus=camera_focus.lerp(hero.get_global_transform_interpolated().origin,1.0-exp(-9*delta))
 camera.position=camera_focus+Vector3(14,22,25)
 camera.look_at(camera_focus)

func _physics_process(delta: float) -> void:
 if not start_pending and not paused:simulate(delta)

func simulate(delta: float) -> void:
 if paused:return
 clock+=delta
 update_ice_effects(delta)
 wind_clock+=delta
 snowfall.direction=Vector3(0.55+sin(wind_clock*0.45)*0.35,-1,0.18)
 snowfall.gravity=Vector3(sin(wind_clock*0.45)*0.12,-0.2,0.03)
 recover_removed_cargo()
 deposit_clock=maxf(0,deposit_clock-delta)
 var input_axis := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
 input_axis+=Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
 input_axis=(input_axis+stick).limit_length()
 if shop_open:
  input_axis=Vector2.ZERO
 var forward := Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
 var desired := (camera.global_basis.x*input_axis.x+forward*input_axis.y)*move_speed()
 desired*=maxf(0.8,1.0-0.18*float(DATA.weight(profile.bag))/capacity())
 hero_velocity=hero_velocity.lerp(desired,1.0-exp(-(9.0 if input_axis.length()>0 else 14.0)*delta))
 if desired.length_squared()<0.001 and hero_velocity.length_squared()<0.0025:hero_velocity=Vector3.ZERO
 if shop_open:
  hero_velocity=Vector3.ZERO
 var old_hero_position := hero.position
 hero.position+=hero_velocity*delta
 hero.position=resolve_furniture_collision(old_hero_position,resolve_ice_collision(old_hero_position,hero.position))
 hero.position.x=clampf(hero.position.x,-9.7,22.0)
 if hero.position.x>10.2:
  var coast_zone := zone_for_position(hero.position)
  if not Geometry2D.is_point_in_polygon(Vector2(hero.position.x,hero.position.z-coast_zone*DATA.ZONE_SPACING),island_outline(coast_zone)):
   hero.position=old_hero_position
 var last := last_unlocked()
 hero.position.z=clampf(hero.position.z,-13,19.0+last*DATA.ZONE_SPACING if last<DATA.ZONES.size()-1 else 17.0+last*DATA.ZONE_SPACING)
 hero.position.y=lerpf(hero.position.y,stand_height(hero.position),1.0-exp(-12*delta))
 if hero_velocity.length()>0.08:
  hero.rotation.y=lerp_angle(hero.rotation.y,atan2(-hero_velocity.x,-hero_velocity.z),1.0-exp(-12.0*delta))
 if hit_flash>0.05 and hero_velocity.length()<0.4 and hero.has_meta("mining_facing"):
  hero.rotation.y=lerp_angle(hero.rotation.y,float(hero.get_meta("mining_facing")),1.0-exp(-14*delta))
 hero.set_meta("load_ratio",float(DATA.weight(profile.bag))/capacity())
 animate_worker(hero,hero_velocity.length()>0.08,delta)
 snowfall.position=hero.position+Vector3(0,8,0)
 selected_zone=zone_for_position(hero.position)
 profile.last_zone=selected_zone
 stream_regions()
 cooldown=maxf(0,cooldown-delta)
 hit_flash=maxf(0,hit_flash-delta)
 tool_pivot.rotation.z=0.5+mining_swing(hit_flash)*0.35
 update_ice(delta)
 if not shop_open:
  hero_actions(delta)
 for i in range(DATA.ZONES.size()):
  if profile.zones[i].unlocked:
   process_kitchen(i,delta)
 update_staff(delta)
 update_buyers(delta)
 update_sales(delta)
 display_timer+=delta
 if display_timer>=0.1:
  update_displays()
  update_pads(display_timer)
  display_timer=0
 update_tutorial(delta)
 var cooking: bool=profile.zones[selected_zone].cooking!=null
 audio.update_stove(cooking,hero.position.distance_to(point(selected_zone,"cook")))
 save_timer+=delta
 if save_timer>3:
  save_timer=0
  save_game()

func material(color: Color) -> StandardMaterial3D:
 var key := color.to_html()
 if material_cache.has(key):
  return material_cache[key]
 var m := StandardMaterial3D.new()
 m.albedo_color=color
 m.diffuse_mode=BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
 m.metallic_specular=0.15
 m.roughness=0.78
 material_cache[key]=m
 return m

func ball(parent: Node3D,pos: Vector3,radius: float,color: Color) -> MeshInstance3D:
 var key := str(radius)
 if not sphere_cache.has(key):
  var sphere := SphereMesh.new()
  sphere.radius=radius
  sphere.height=radius*2
  sphere.radial_segments=12
  sphere.rings=6
  sphere_cache[key]=sphere
 var result := MeshInstance3D.new()
 result.mesh=sphere_cache[key]
 result.material_override=material(color)
 parent.add_child(result)
 result.position=pos
 return result

func surface(name: String,repeats: Vector3 = Vector3.ONE) -> StandardMaterial3D:
 var colors := {"snow":"e6f4fa","water":"52c6de","wood":"d7a36f","bark":"a87953","cloth":"f4ead9","leather":"b78052","ice":"9cdef0","shop":"87b4a7","skin_fisher":"e8b65d","skin_runner":"6bc0a3","skin_seller":"ba91d6"}
 return material(Color(colors.get(name,"d2dfe1")))

func build_environment() -> void:
 var env := WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("b6c9d9")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("d7e6f0")
 env.environment.ambient_light_energy=0.42
 add_child(env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-55,-35,0)
 sun.light_energy=0.85
 sun.light_color=Color("fff0dc")
 sun.shadow_enabled=true
 sun.directional_shadow_max_distance=45
 add_child(sun)
 box(self,Vector3(0,-1.5,60),Vector3(180,0.6,1500),Color("bacbd8"))
 var river := MeshInstance3D.new()
 river.name="River"
 var mesh := PlaneMesh.new()
 mesh.size=Vector2(10,140)
 mesh.subdivide_width=2
 mesh.subdivide_depth=60
 river.mesh=mesh
 var shader := ShaderMaterial.new()
 shader.shader=load("res://Water.gdshader")
 river.material_override=shader
 add_child(river)
 river.position=Vector3(-5,water_y,280)
 for i in range(80):
  var z := float(i)*2.0-16
  rounded(self,Vector3(-10.5,-0.65,z),Vector3(1.8,0.5,2.4),Color("e1e8ee"))
  if i%3==0:
   tree_at(Vector3(-12,0,z),0.9)

func point(index: int,kind: String) -> Vector3:
 var positions := {"sale":Vector3(5,0,-1.4),"counter":Vector3(7.8,0,-2.4),"coins":Vector3(8,0,-4.2),"drop":Vector3(2.9,0,4.6),"cook":Vector3(2.7,0,1.7),"output":Vector3(8.4,0,4.6),"catch":Vector3(0.35,0,9),"shop":Vector3(9.1,0,10.0)}
 if count_workers("seller",index)>0:
  positions["sale"]=Vector3(6.8,0,-1.4)
  positions["counter"]=Vector3(8.9,0,-1.0)
 if kind=="cook" and index==4:
  positions[kind]=Vector3(3.9,0,2.3)
 return positions[kind]+Vector3(0,0,DATA.ZONE_SPACING*index)

func build_island(index: int) -> void:
 var offset := Vector3(0,0,DATA.ZONE_SPACING*index)
 var floor_material := ShaderMaterial.new()
 floor_material.shader=load("res://Ground.gdshader")
 floor_material.set_shader_parameter("terrain_atlas",load("res://textures/cartoon_terrain_atlas.png"))
 floor_material.set_shader_parameter("base_tint",floor_color(index))
 floor_material.set_shader_parameter("zone_origin",float(index)*DATA.ZONE_SPACING)
 floor_material.set_shader_parameter("grass_amount",[0.28,0.4,0.75,0.35,0.25][index%5])
 floor_material.set_shader_parameter("snow_amount",[0.55,0.4,0.35,0.7,0.55][index%5])
 build_island_terrain(index,offset,floor_material)
 # Counter and customer bench use the same understated wood shapes as the reference.
 table_at(offset+Vector3(5,0,-3),Vector3(3.0,0,1.35))
 var counter_models: Array=[]
 var pickup_models: Array=[]
 if index>0:
  build_cuisine(index,offset)
  table_at(offset+Vector3(6,0,4.6),Vector3(2.1,0,1.0))
 var catch_table := table_at(offset+Vector3(-1.9,0,9),Vector3(1.8,0,1.0))
 catch_table.visible=false
 box(catch_table,Vector3(0,0.92,0.52),Vector3(1.75,0.16,0.045),Color("477f75"))
 var shop_visual := build_shop(offset)
 var sign: Label3D=shop_visual.get_node("ZoneSign")
 sign.text=DATA.ZONES[index].name
 # A dedicated incoming/outgoing customer boardwalk avoids walking through the fence.
 var pier := bevel(self,offset+Vector3(5,-0.06,-10.2),Vector3(4.2,0.28,6.4),Color("b69b7a"))
 pier.material_override=surface("wood",Vector3(0.8,0.8,0.8))
 for step in range(14):
  box(self,offset+Vector3(5,0.09,-13.1+step*0.45),Vector3(4.05,0.015,0.025),Color("6c6557"))
 var pad_records: Array=[]
 for kind in ["sale","counter","coins","catch","shop"]:
  pad_records.append(make_pad(index,kind))
 if index>0:
  for kind in ["drop","cook","output"]:
   pad_records.append(make_pad(index,kind))
 var cash_models: Array=[]
 for i in range(12):
  var coin := make_coin(self,point(index,"coins")+Vector3(float(i%3)*0.2-0.2,0.3+float(i/9)*0.07,float((i/3)%3)*0.2-0.2))
  coin.visible=false
  cash_models.append(coin)
 var unlock: Label3D=null
 if index>0:
  box(self,offset+Vector3(5,-0.02,-11.5),Vector3(4,0.25,9),Color("d9e2e8"))
  unlock=zone(offset+Vector3(5,0,-11),Color("e6c785"),str(DATA.ZONES[index].cost))
  unlock.set_meta("unlock",index)
  var guide := Label3D.new()
  add_child(guide)
  guide.position=offset+Vector3(5,1.8,-12.8)
  guide.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  guide.text="↑  ЗОНА %d" % (index+1)
  guide.font=preload("res://ArtTheme.gd").WORLD
  guide.font_size=40
  guide.pixel_size=0.008
  guide.outline_size=4
  guide.modulate=Color("193746")
  guide.outline_modulate=Color("f0eadb")
 var steam: CPUParticles3D=null
 if index>0:
  steam=make_particles(offset+Vector3(0.5,1.5,2.4),12,1.5,false)
 kitchen_steam[index]=steam
 var record := {"floor":floor_material,"sign":sign,"pads":pad_records,"counter_models":counter_models,"output_models":pickup_models,"cash_models":cash_models,"unlock":unlock,"sale_clock":0.0,"gate_hold":0.0,"raw_models":[],"catch_models":[],"catch_table":catch_table,"shop_visual":shop_visual,"business_open":false}
 zone_live[index]=record
 build_rest_corner(index,offset)
 build_zone_garden(index,offset)
 build_border_details(index,offset)
 build_landmark(index,offset)
 spawn_ice_field(index)
 scatter_zone_details(index)
 plant_ground_details(index)
 for i in range(6):
  tree_at(offset+Vector3(12+float(i%2),0,-5+float(i)*3.5),0.8+0.08*(index%5))

func log_at(pos: Vector3,height: float) -> void:
 var node := MeshInstance3D.new()
 var cylinder := CylinderMesh.new()
 cylinder.top_radius=0.14
 cylinder.bottom_radius=0.17
 cylinder.height=height
 cylinder.radial_segments=12
 node.mesh=cylinder
 node.material_override=material(Color("bd8659"))
 add_child(node)
 node.position=pos
 var cap := MeshInstance3D.new()
 var disc := CylinderMesh.new()
 disc.top_radius=0.143
 disc.bottom_radius=0.143
 disc.height=0.025
 disc.radial_segments=12
 cap.mesh=disc
 cap.material_override=detail_shader("log_rings","res://LogRings.gdshader")
 node.add_child(cap)
 cap.position.y=height*0.5

func table_at(pos: Vector3,size: Vector3) -> Node3D:
 var root := Node3D.new()
 add_child(root)
 root.position=pos
 furniture.append({"pos":pos,"half":Vector2(size.x*0.5+0.22,size.z*0.5+0.22),"root":root})
 var top := bevel(root,Vector3(0,1.0,0),Vector3(size.x,0.16,size.z),Color("bf8a59"))
 top.material_override=detail_shader("painted_wood","res://PaintedWood.gdshader")
 for line in [-0.22,0.22]:
  box(root,Vector3(0,1.084,line*size.z),Vector3(size.x*0.93,0.008,0.016),Color("72563b"))
 for x in [-size.x*0.35,size.x*0.35]:
  for z in [-size.z*0.32,size.z*0.32]:
   box(root,Vector3(x,0.55,z),Vector3(0.09,0.9,0.09),Color("8b6143"))
   ball(root,Vector3(x,1.085,z),0.022,Color("5e6461"))
 return root

func build_shop(offset: Vector3) -> Node3D:
 var zone_index := clampi(int(round(offset.z/DATA.ZONE_SPACING)),0,DATA.ZONES.size()-1)
 var theme := Color(DATA.ZONES[zone_index].color)
 var root := Node3D.new()
 add_child(root)
 root.position=offset+Vector3(6.8,0,10)
 root.rotation.y=PI*0.5
 furniture.append({"pos":root.position,"half":Vector2(0.92,2.47),"root":root})
 var siding := detail_shader("shop_siding_%d" % zone_index,"res://ShopSiding.gdshader")
 siding.set_shader_parameter("tint",Color("87b4a7").lerp(theme,0.3))
 bevel(root,Vector3(0,1.2,0),Vector3(4.5,2.0,1.4),Color.WHITE).material_override=siding
 var roof := detail_shader("shop_roof_%d" % zone_index,"res://ShopRoof.gdshader")
 roof.set_shader_parameter("tint",theme.lightened(0.5))
 bevel(root,Vector3(0,2.35,0),Vector3(5.0,0.35,2.0),theme.lightened(0.5)).material_override=roof
 for side in [-1.0,1.0]:
  bevel(root,Vector3(side*1.4,1.35,0.73),Vector3(1.05,0.85,0.05),Color("8cbdc7")).material_override=detail_shader("shop_glass","res://ShopGlass.gdshader")
  for x in [-0.53,0.53]:
   box(root,Vector3(side*1.4+x,1.35,0.78),Vector3(0.045,0.95,0.04),Color("d1b488"))
  box(root,Vector3(side*1.4,1.35,0.79),Vector3(1.05,0.045,0.04),Color("d1b488"))
 for i in range(10):
  bevel(root,Vector3(-2.2+i*0.49,2.2,1.1),Vector3(0.49,0.18,1.0),theme.darkened(0.2) if i%2==0 else Color("efe1bd"))
 bevel(root,Vector3(0,0.85,0.78),Vector3(0.78,1.55,0.06),Color("4c666a"))
 ball(root,Vector3(0.25,0.85,0.85),0.045,Color("dcb66c"))
 var sign := Label3D.new()
 sign.name="ZoneSign"
 root.add_child(sign)
 sign.position=Vector3(0,2.9,0)
 sign.font=preload("res://ArtTheme.gd").WORLD
 sign.font_size=44
 sign.pixel_size=0.0065
 sign.outline_size=4
 sign.modulate=Color("193746")
 sign.outline_modulate=Color("f0eadb")
 sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 return root

func tree_at(pos: Vector3,scale_factor: float) -> void:
 box(self,pos+Vector3(0,0.6,0),Vector3(0.23,1.2,0.23),Color("765c4e"))
 for tier in range(3):
  var mesh := MeshInstance3D.new()
  var cone := CylinderMesh.new()
  cone.top_radius=0.02
  cone.bottom_radius=(1.1-float(tier)*0.25)*scale_factor
  cone.height=1.5*scale_factor
  cone.radial_segments=12
  mesh.mesh=cone
  mesh.material_override=wind_material(true)
  add_child(mesh)
  mesh.position=pos+Vector3(0,(1.4+float(tier)*0.65)*scale_factor,0)

func build_cuisine(index: int,offset: Vector3) -> void:
 var base := offset+Vector3(0.5,0,2.4)
 furniture.append({"pos":base+Vector3(0.6 if index==4 else 0.0,0,0),"half":Vector2(1.62,1.02) if index==4 else Vector2(1.18,1.18)})
 if index>=5:
  build_new_kitchen(index,base)
 elif index==1:
  bevel(self,base+Vector3(0,0.8,0),Vector3(1.6,1.2,1.2),Color("4a535a"))
  for i in range(7):
   box(self,base+Vector3(-0.65+float(i)*0.22,1.45,0),Vector3(0.035,0.04,1.25),Color("252d33"))
  rounded(self,base+Vector3(0,1.3,0),Vector3(1.2,0.12,0.8),Color("da6f3a"))
 elif index==2:
  bevel(self,base+Vector3(0,1.2,0),Vector3(1.65,2.2,1.5),Color("805c45"))
  box(self,base+Vector3(0,1.0,0.78),Vector3(1.25,1.4,0.06),Color("4e4440"))
  box(self,base+Vector3(0.55,2.85,0),Vector3(0.35,1.2,0.35),Color("61717a"))
  for x in [-0.55,0.55]:
   box(self,base+Vector3(x,1.2,0.83),Vector3(0.06,1.6,0.05),Color("c4a075"))
 elif index==3:
  rounded(self,base+Vector3(0,0.75,0),Vector3(1.9,1.15,1.9),Color("454b52"))
  rounded(self,base+Vector3(0,1.3,0),Vector3(1.6,0.08,1.6),Color("ddb15d"))
  for i in range(12):
   var angle := float(i)*TAU/12
   ball(self,base+Vector3(sin(angle),0.2,cos(angle)),0.24,Color("767b86"))
  for x in [-0.4,0.4]:
   rounded(self,base+Vector3(x,0.25,0),Vector3(1.8,0.25,0.3),Color("a35e38"))
 else:
  bevel(self,base+Vector3(0.6,0.9,0),Vector3(2.8,1.4,1.6),Color("8facae"))
  for x in [-0.2,1.1]:
   bevel(self,base+Vector3(x,0.8,0.84),Vector3(1.0,0.7,0.06),Color("354c58"))
   rounded(self,base+Vector3(x,1.65,0),Vector3(0.9,0.06,0.9),Color("d79b53"))
  bevel(self,base+Vector3(0.6,2.7,0),Vector3(3.2,0.4,1.9),Color("667f89"))
  for x in [-0.3,1.3]:
   var light := OmniLight3D.new()
   add_child(light)
   light.position=base+Vector3(x,2.2,0.4)
   light.light_color=Color("ffd391")
   light.light_energy=0.45
   light.omni_range=3
 table_at(offset+Vector3(0.5,0,5.8),Vector3(2.2,0,1.0))

func make_pad(index: int,kind: String) -> Label3D:
 var colors := {"sale":"e6c06a","counter":"63bfaa","coins":"e6c06a","catch":"80b9d2","drop":"80b9d2","cook":"eaa275","output":"63bfaa","shop":"cbb3df"}
 var color := Color(colors[kind])
 var label := zone(point(index,kind),color,kind)
 pads[-1].zone=index
 pads[-1].kind=kind
 if index==0 and kind=="counter":
  for child in label.get_parent().get_children():
   if child is Sprite3D:
    child.texture=load("res://icons/pad_fish.svg")
 return label

func zone(pos: Vector3,color: Color,title: String) -> Label3D:
 var root := Node3D.new()
 add_child(root)
 root.position=pos+Vector3(0,0.24,0)
 bevel(root,Vector3(0,-0.012,0),Vector3(2.04,0.035,1.39),color.darkened(0.15))
 bevel(root,Vector3.ZERO,Vector3(1.95,0.035,1.3),Color("4c423e"))
 var inset := bevel(root,Vector3(0,0.025,0),Vector3(1.83,0.018,1.18),Color("66564a"))
 var white := Color("f4f4e9")
 for x in [-0.93,0.93]:
  for z in [-0.60,0.60]:
   box(root,Vector3(x-signf(x)*0.19,0.045,z),Vector3(0.38,0.025,0.055),white)
   box(root,Vector3(x,0.045,z-signf(z)*0.15),Vector3(0.055,0.025,0.3),white)
 var icons := {"sale":"pad_coin","counter":"pad_plate","coins":"pad_coin","catch":"pad_fish","shop":"pad_shop","drop":"pad_drop","cook":"pad_cook","output":"pad_plate"}
 var sprite := Sprite3D.new()
 sprite.texture=load("res://icons/"+str(icons.get(title,"pad_shop"))+".svg")
 sprite.pixel_size=0.0040
 sprite.rotation_degrees.x=-90
 sprite.position=Vector3(0,0.07,-0.15)
 sprite.shaded=false
 root.add_child(sprite)
 box(root,Vector3(-0.55,0.055,0.4),Vector3(0.32,0.025,0.15),Color("4acb50"))
 var label := Label3D.new()
 root.add_child(label)
 label.position=Vector3(0.1,0.08,0.43)
 label.rotation_degrees.x=-90
 label.font=preload("res://ArtTheme.gd").WORLD
 label.font_size=60
 label.pixel_size=0.0052
 label.outline_size=4
 label.text=title if not icons.has(title) else ""
 pads.append({"pos":pos,"root":root,"label":label,"zone":-1,"kind":"unlock","half_size":Vector2(1.02,0.70),"inset":inset})
 return label

func spawn_ice_field(index: int) -> void:
 for existing in fish_live:
  if int(existing.zone)==index:return
 var positions := [Vector2(-2.5,-5.4),Vector2(-7,-7.5),Vector2(-7,-2.4),Vector2(-2.5,-0.7),Vector2(-7,3.8),Vector2(-7,8.2),Vector2(-7,13.4)]
 var tiers := [0,0,1,0,2,0,3]
 for i in range(positions.size()):
  var tier: int=tiers[i]
  var config: Dictionary=DATA.FISH[tier]
  var size := Vector3(config.ice,config.height,config.ice)
  var block := MeshInstance3D.new()
  block.mesh=bevel_mesh(size)
  block.name="Ice_%d_%d" % [index,i]
  add_child(block)
  block.position=Vector3(positions[i].x,water_y+size.y*0.5,positions[i].y+DATA.ZONE_SPACING*index)
  var ice_material := ShaderMaterial.new()
  ice_material.shader=load("res://IceVisual.gdshader")
  ice_material.set_shader_parameter("low_detail",weak_device)
  ice_material.set_shader_parameter("variation",float(i+index*7)*0.37)
  ice_material.set_shader_parameter("ice_texture",load("res://textures/cartoon_terrain_atlas.png"))
  block.material_override=ice_material
  var species := fish_species_for(index,i)
  var fish := make_fish(block,Vector3.ZERO,species)
  fish.rotation.y=0.75
  fish.scale=Vector3.ONE*float(config.scale)
  ice_edges(block,size)
  var status := Label3D.new()
  block.add_child(status)
  status.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  status.position=Vector3(0,size.y*0.5+0.32,0)
  status.font=preload("res://ArtTheme.gd").WORLD
  status.font_size=50
  status.pixel_size=0.006
  status.outline_size=4
  status.outline_modulate=Color("263d46")
  status.visible=false
  var bar := Node3D.new()
  block.add_child(bar)
  bar.position=Vector3(size.x*0.58,0,0)
  box(bar,Vector3.ZERO,Vector3(0.16,size.y*0.8,0.10),Color("2b4555"))
  var fill := box(bar,Vector3.ZERO,Vector3(0.11,size.y*0.8,0.12),Color("81dedb"))
  bar.visible=false
  fish_live.append({"slot":i,"species":species,"fish":fish,"hit_flash":0.0,"zone":index,"node":block,"tier":tier,"hp":int(config.hp),"max_hp":int(config.hp),"yield":int(config["yield"]),"reach":size.x*0.5+0.95,"respawn":0.0,"status":status,"bar":bar,"fill":fill,"bar_height":size.y*0.8,"flow_z":positions[i].y,"near_bank":positions[i].x>-4})
  if not fish_by_zone.has(index):fish_by_zone[index]=[]
  fish_by_zone[index].append(fish_live[-1])

func ice_edges(parent: Node3D,size: Vector3) -> void:
 var vertices := PackedVector3Array()
 for axis in range(3):
  for a in [-1.0,1.0]:
   for b in [-1.0,1.0]:
    var start := Vector3.ZERO
    var finish := Vector3.ZERO
    start[axis]=-size[axis]*0.48
    finish[axis]=size[axis]*0.48
    start[(axis+1)%3]=a*size[(axis+1)%3]*0.48
    finish[(axis+1)%3]=start[(axis+1)%3]
    start[(axis+2)%3]=b*size[(axis+2)%3]*0.48
    finish[(axis+2)%3]=start[(axis+2)%3]
    vertices.append(start)
    vertices.append(finish)
 var arrays: Array=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,arrays)
 var model := MeshInstance3D.new()
 model.mesh=mesh
 var white := StandardMaterial3D.new()
 white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 white.albedo_color=Color("d1f1fb")
 model.material_override=white
 parent.add_child(model)

func update_ice(delta: float) -> void:
 for entry in fish_live:
  var old_flash: float=entry.hit_flash
  entry.hit_flash=maxf(0,old_flash-delta*4)
  if old_flash>0 and absi(int(entry.zone)-selected_zone)<=1:entry.node.material_override.set_shader_parameter("impact",entry.hit_flash)
  var unlocked: bool=profile.zones[entry.zone].unlocked
  var near := absi(int(entry.zone)-selected_zone)<=1
  entry.node.visible=near and unlocked and entry.respawn<=0
  entry.status.visible=false
  entry.bar.visible=false
  if unlocked:
   entry.flow_z=wrapf(float(entry.flow_z)+delta*0.28,-10.0,15.5)
   entry.node.position.z=DATA.ZONE_SPACING*int(entry.zone)+float(entry.flow_z)
   if entry.near_bank:
    var bank_blend := smoothstep(1.5,5.0,float(entry.flow_z))
    entry.node.position.x=lerpf(-2.5,-4.3,bank_blend)
  if entry.respawn>0:
   entry.respawn=maxf(0,entry.respawn-delta)
   if entry.respawn<=0:
    entry.hp=entry.max_hp
    entry.species=fish_species_for(int(entry.zone),int(entry.slot))
    apply_fish_species(entry.fish,int(entry.species))
    entry.node.material_override.set_shader_parameter("damage",0.0)
  if not unlocked or entry.respawn>0 or not near:
   continue
  entry.node.position.y=water_y+float(DATA.FISH[int(entry.tier)].height)*0.5+sin(clock*1.3+entry.node.position.z)*0.022
  entry.node.rotation.z=sin(clock*0.9+entry.node.position.x)*0.006
  entry.node.scale=entry.node.scale.lerp(Vector3.ONE,1-exp(-10*delta))
  var nearby := flat_distance(hero.position,entry.node.position)<float(entry.reach)
  if nearby:
   entry.status.visible=true
   entry.bar.visible=entry.hp<entry.max_hp
   var ratio := float(entry.hp)/float(entry.max_hp)
   entry.fill.scale.y=ratio
   entry.fill.position.y=-float(entry.bar_height)*0.5*(1-ratio)
   var config: Dictionary=DATA.FISH[entry.tier]
   entry.status.text="%s · %s\n%.1f кг · %d ● · %d/%d" % [DATA.SPECIES[int(entry.species)].name,DATA.SPECIES[int(entry.species)].rarity,float(config.kg),sale_value(DATA.raw(int(entry.tier),int(entry.species))),entry.hp,entry.max_hp]
   if DATA.weight(profile.bag)+int(entry["yield"])>capacity():
    entry.status.text="Рюкзак: потрібно %d місць" % int(entry["yield"])
   elif cooldown<=0 and not shop_open:
    var won := strike_ice(entry,int(profile.hero.tool),capacity()-DATA.weight(profile.bag))
    if hero_velocity.length()<0.4:
     var toward: Vector3=entry.node.position-hero.position
     hero.set_meta("mining_facing",atan2(-toward.x,-toward.z))
    hero.set_meta("work",0.5)
    hit_flash=0.5
    cooldown=0.55
    play_sound("ice",-17)
    if won:
     profile.bag.append(DATA.raw(int(entry.tier),int(entry.species)))
     item_flight(entry.node.position,hero.position+Vector3(0,1.2,0.4),DATA.raw(int(entry.tier),int(entry.species)))
     if int(entry.species)>=3:hero.set_meta("cheer",0.8)
     gain_xp(int(entry["yield"])+1)

func strike_ice(entry: Dictionary,damage: int,available: int) -> bool:
 if entry.respawn>0 or available<int(entry["yield"]):
  return false
 entry.hp=maxi(0,int(entry.hp)-damage)
 entry.hit_flash=1.0
 entry.node.material_override.set_shader_parameter("impact",1.0)
 entry.node.scale=Vector3.ONE*0.96
 entry.node.material_override.set_shader_parameter("damage",1-float(entry.hp)/float(entry.max_hp))
 emit_ice_fragments(entry,entry.hp==0)
 if entry.hp==0:
  var cycle_key := "%d:%d" % [int(entry.zone),int(entry.slot)]
  profile.ice_cycles[cycle_key]=int(profile.ice_cycles.get(cycle_key,0))+1
  entry.respawn=float(DATA.FISH[int(entry.tier)].respawn)
  entry.node.visible=false
  return true
 return false

func make_fish(parent: Node3D,pos: Vector3,species: int = 0) -> Node3D:
 var root := Node3D.new()
 parent.add_child(root)
 root.position=pos
 if not render_cache.has("tuna"):
  var tool := SurfaceTool.new()
  tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  var xs := [-0.67,-0.52,-0.28,0.08,0.37,0.56,0.68]
  var widths := [0.045,0.13,0.235,0.265,0.20,0.11,0.015]
  for row in range(xs.size()-1):
   for segment in range(16):
    var indices := [[row,segment],[row+1,segment],[row+1,segment+1],[row,segment],[row+1,segment+1],[row,segment+1]]
    for pair in indices:
     var a := float(pair[1])*TAU/16
     var y := sin(a)*float(widths[pair[0]])*0.95
     var color := Color("edf1df") if y<0.03 else (Color("b6c9c9") if y<0.12 else Color("c84e72"))
     if y>0.16:
      color=Color("993d60")
     tool.set_color(color)
     tool.add_vertex(Vector3(xs[pair[0]],y,cos(a)*float(widths[pair[0]])))
  tool.generate_normals()
  render_cache.tuna=tool.commit()
  var skin := ShaderMaterial.new()
  skin.shader=load("res://FishSurface.gdshader")
  skin.set_meta("outlined",true)
  skin.next_pass=null if weak_device else detail_shader("outline","res://ToonOutline.gdshader")
  render_cache.tuna_skin=skin
 var body := MeshInstance3D.new()
 body.name="FishBody"
 body.mesh=render_cache.tuna
 body.material_override=render_cache.tuna_skin
 root.add_child(body)
 fin(root,"tail",[Vector3(-0.62,0,0),Vector3(-1.04,0.08,0.40),Vector3(-0.9,0,0),Vector3(-0.62,0,0),Vector3(-0.9,0,0),Vector3(-1.04,-0.08,-0.4)])
 fin(root,"dorsal",[Vector3(-0.30,0.17,0),Vector3(-0.36,0.43,0),Vector3(0.10,0.21,0)])
 for side in [-1.0,1.0]:
  fin(root,"side"+str(side),[Vector3(0.2,0.01,side*0.17),Vector3(-0.17,-0.02,side*0.53),Vector3(-0.02,-0.03,side*0.19)])
  ball(root,Vector3(0.48,0.04,side*0.14),0.045,Color("253340"))
  ball(root,Vector3(0.49,0.055,side*0.17),0.012,Color.WHITE)
 apply_fish_species(root,species)
 return root

func fin(parent: Node3D,key: String,vertices: Array) -> void:
 if not render_cache.has(key):
  var tool := SurfaceTool.new()
  tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  for vertex in vertices:
   tool.add_vertex(vertex)
  tool.generate_normals()
  render_cache[key]=tool.commit()
 var model := MeshInstance3D.new()
 model.mesh=render_cache[key]
 var m := material(Color("354855"))
 m.cull_mode=BaseMaterial3D.CULL_DISABLED
 model.material_override=m
 parent.add_child(model)

func make_dish(parent: Node3D,pos: Vector3,recipe: int = 0) -> Node3D:
 var dish := Node3D.new()
 parent.add_child(dish)
 dish.position=pos
 show_meal(dish,recipe)
 return dish

func show_meal(model: Node3D,recipe: int) -> void:
 var kind := clampi(recipe,0,DATA.ZONES.size()-1)
 if int(model.get_meta("recipe",-1))==kind:return
 model.set_meta("recipe",kind)
 for child in model.get_children():
  model.remove_child(child)
  child.queue_free()
 var group := Node3D.new()
 model.add_child(group)
 if kind>=5:
  build_new_meal(group,kind)
 elif kind==0:
  make_fish(group,Vector3.ZERO).scale=Vector3.ONE*0.65
 elif kind==3:
  rounded(group,Vector3(0,0.05,0),Vector3(0.72,0.32,0.64),Color("d7e0df"))
  rounded(group,Vector3(0,0.2,0),Vector3(0.62,0.035,0.54),Color("e2b65b"))
  for x in [-0.15,0.12]:
   ball(group,Vector3(x,0.22,0.03),0.07,Color("eee0ae"))
 else:
  rounded(group,Vector3.ZERO,Vector3(0.88,0.08,0.65),Color("d6e2e4"))
  if kind==1:
   rounded(group,Vector3(0,0.09,0),Vector3(0.53,0.13,0.45),Color("d85953"))
   rounded(group,Vector3(0,0.16,0),Vector3(0.20,0.025,0.15),Color("f3d7ab"))
   for mark in [-0.16,0.0,0.16]:
    box(group,Vector3(mark,0.166,0),Vector3(0.025,0.01,0.35),Color("8d4e37"))
  elif kind==2:
   rounded(group,Vector3(0,0.09,0),Vector3(0.64,0.15,0.32),Color("af713f"))
   for x in [-0.18,0,0.18]:
    box(group,Vector3(x,0.17,0),Vector3(0.025,0.015,0.22),Color("6f4734"))
  else:
   for x in [-0.15,0.18]:
    rounded(group,Vector3(x,0.09,0),Vector3(0.32,0.13,0.45),Color("c3864c"))
  ball(group,Vector3(0.3,0.08,0.15),0.075,Color("d5c764"))
  ball(group,Vector3(-0.3,0.08,0.15),0.065,Color("679857"))

func make_pickaxe(actor: Node3D) -> Node3D:
 var tool := Node3D.new()
 actor.add_child(tool)
 tool.position=Vector3(0.36,0.47,-0.08)
 tool.reparent(actor.get_meta("rig").elbows[1],true)
 box(tool,Vector3(0.28,0,0),Vector3(0.75,0.08,0.08),Color("a7754e"))
 rounded(tool,Vector3(0.62,0,0),Vector3(0.16,0.65,0.17),Color("bacbd4"))
 box(tool,Vector3(-0.07,0,0),Vector3(0.08,0.11,0.11),Color("546875"))
 for grip in range(3):
  box(tool,Vector3(0.02+grip*0.09,0,0),Vector3(0.035,0.09,0.09),Color("574432"))
 actor.set_meta("carried_tool",tool)
 return tool

func carry_models(actor: Node3D,count: int) -> Array:
 var models: Array=[]
 for i in range(count):
  var raw := make_fish(actor,Vector3(0,0.88+float(i)*0.18,-0.58))
  raw.visible=false
  raw.reparent(actor.get_meta("rig").body,true)
  var meal := make_dish(actor,Vector3(0,0.88+float(i)*0.18,-0.58))
  meal.scale=Vector3.ONE*0.6
  meal.reparent(actor.get_meta("rig").body,true)
  meal.visible=false
  models.append({"raw":raw,"meal":meal})
 return models

func show_bag(models: Array,items: Array) -> void:
 if not models.is_empty():
  var owner_actor: Node3D=models[0].raw.get_parent().get_parent()
  if owner_actor.has_meta("carried_tool"):
   owner_actor.get_meta("carried_tool").visible=items.is_empty() or float(owner_actor.get_meta("work",0))>0
 for i in range(models.size()):
  var raw: Node3D=models[i].raw
  var meal: Node3D=models[i].meal
  raw.visible=false
  meal.visible=false
  if i>=items.size():
   continue
  var item: Dictionary=items[i]
  if item.kind=="raw":
   raw.visible=true
   apply_fish_species(raw,int(item.get("species",0)))
   raw.scale=Vector3.ONE*0.55*float(DATA.FISH[int(item.size)].scale)
   raw.rotation=Vector3(0,0.15,0.2)
  else:
   meal.visible=true
   show_meal(meal,int(item.recipe))

func hero_actions(delta: float) -> void:
 var z := selected_zone
 var state: Dictionary=profile.zones[z]
 var shop_distance := flat_distance(hero.position,point(z,"shop"))
 if shop_distance>1.8:
  shop_entry_armed=true
 if shop_distance<0.95 and shop_entry_armed:
  open_shop()
  return
 for i in range(1,DATA.ZONES.size()):
  if not profile.zones[i].unlocked and profile.zones[i-1].unlocked:
   var gate := Vector3(5,0,DATA.ZONE_SPACING*i-11)
   if flat_distance(hero.position,gate)<1.0 and money>=int(DATA.ZONES[i].cost):
    zone_live[i].gate_hold+=delta
    if zone_live[i].gate_hold>=1.0:
     unlock_zone(i)
   else:
    zone_live[i].gate_hold=0.0
 if flat_distance(hero.position,point(z,"cook"))<0.95 and z>0:
  state.running=true
 if deposit_clock>0:
  return
 var raw_index := first_kind(profile.bag,"raw")
 var food_index := first_kind(profile.bag,"food")
 var did := false
 if count_workers("runner",z)>0 and flat_distance(hero.position,point(z,"counter"))<1.0 and state.counter.size()<DATA.MAX_STOCK:
  var item_index := raw_index if z==0 else food_index
  if item_index>=0:
   var item: Dictionary=profile.bag.pop_at(item_index)
   state.counter.append(item)
   item_flight(hero.position+Vector3(0,1.4,0),stock_top(z,"counter"),item)
   did=true
 elif z>0 and flat_distance(hero.position,point(z,"drop"))<0.95 and raw_index>=0 and state.input.size()<DATA.MAX_STOCK:
  var item: Dictionary=profile.bag.pop_at(raw_index)
  state.input.append(item)
  item_flight(hero.position+Vector3(0,1.4,0),stock_top(z,"drop"),item)
  did=true
 elif z>0 and flat_distance(hero.position,point(z,"output"))<0.95 and not state.output.is_empty() and DATA.weight(profile.bag)<capacity():
  var item: Dictionary=state.output.pop_front()
  profile.bag.append(item)
  item_flight(stock_top(z,"output"),hero.position+Vector3(0,1.4,0),item)
  did=true
 elif count_workers("runner",z)>0 and flat_distance(hero.position,point(z,"catch"))<0.95:
  # Empty-handed players can retrieve large catches that exceed a helper's bag.
  var mode: String=hero.get_meta("catch_mode","")
  if mode.is_empty():
   mode="drop" if raw_index>=0 else "take"
   hero.set_meta("catch_mode",mode)
  if mode=="drop" and raw_index>=0 and state.catch.size()<DATA.MAX_STOCK:
   state.catch.append(profile.bag.pop_at(raw_index))
   did=true
  elif mode=="take" and not state.catch.is_empty():
   var index := fitting_item(state.catch,capacity()-DATA.weight(profile.bag))
   if index>=0:
    var catch_item: Dictionary=state.catch.pop_at(index)
    profile.bag.append(catch_item)
    item_flight(stock_top(z,"catch"),hero.position+Vector3(0,1.3,0),catch_item)
    did=true
 elif flat_distance(hero.position,point(z,"coins"))<1.0 and state.cash>0:
  var amount := mini(maxi(50,int(ceil(float(state.cash)*0.15))),int(state.cash))
  state.cash-=amount
  money+=amount
  coin_flight(point(z,"coins")+Vector3(0,0.4,0),hero.position+Vector3(0,1,0.4))
  play_sound("coin",-18)
  did=true
 if flat_distance(hero.position,point(z,"catch"))>1.3:
  hero.set_meta("catch_mode","")
 if did:
  deposit_clock=0.08
  play_sound("transfer",-26)
  hero.set_meta("handover",0.3)

func process_kitchen(index: int,delta: float) -> void:
 if index==0:
  return
 var state: Dictionary=profile.zones[index]
 if not state.running:
  return
 if state.cooking==null and not state.input.is_empty():
  var size: int=state.input[0].size
  var portions: int=DATA.FISH[size]["yield"]
  if state.output.size()+portions<=DATA.MAX_STOCK:
   state.cooking=state.input.pop_front()
   state.progress=0.0
 if state.cooking!=null:
  state.progress+=delta
  var size: int=state.cooking.size
  if state.progress>=kitchen_time(index,size):
   for i in range(int(DATA.FISH[size]["yield"])):
    state.output.append(DATA.dish(index,int(state.cooking.get("species",0))))
   state.cooking=null
   state.progress=0.0
   gain_xp(2)

func kitchen_time(index: int,size: int = 0) -> float:
 return float(DATA.ZONES[index].time)*(1.0+0.18*size)/(1.0+0.25*(int(profile.zones[index].kitchen_level)-1))

func spawn_worker(record: Dictionary) -> void:
 var zone: int=record.zone
 var role: String=record.role
 var color := Color("c49442")
 var skin := "skin_fisher"
 if role=="seller":
  color=Color("a46ac1")
  skin="skin_seller"
 elif role=="runner":
  color=Color("639d88")
  skin="skin_runner"
 var actor := person(point(zone,"catch")+Vector3(float(int(record.uid)%3)*0.4,0.2,0),color,skin)
 actor.name="Worker_%d" % int(record.uid)
 actor.set_meta("role",role)
 var models := carry_models(actor,2)
 var pick: Node3D=null
 if role=="fisher":
  pick=make_pickaxe(actor)
 var runtime := {"data":record,"node":actor,"models":models,"velocity":Vector3.ZERO,"path":[],"target":Vector3.INF,"hit":0.0,"tool":pick}
 workers_live.append(runtime)

func update_staff(frame_delta: float) -> void:
 for worker in workers_live:
  var delta := frame_delta
  var near := absi(int(worker.data.zone)-selected_zone)<= (0 if weak_device else 1)
  worker.node.visible=near
  if not near:
   worker["remote_time"]=float(worker.get("remote_time",0))+frame_delta
   if worker.remote_time<0.25:continue
   delta=worker.remote_time
   worker.remote_time=0.0
  var record: Dictionary=worker.data
  worker.node.visible=near
  var zone: int=record.zone
  var state: Dictionary=profile.zones[zone]
  worker.hit=maxf(0,float(worker.hit)-delta)
  if record.role=="seller":
   var station := seller_station(record)
   if move_agent(worker,station,delta,staff_speed(record),false):
    worker.node.rotation.y=lerp_angle(worker.node.rotation.y,0,1-exp(-8*delta))
  elif record.role=="fisher":
   update_miner(worker,delta)
  elif record.role=="runner":
   var task: String=worker.get("task","")
   var raw_ready: bool=fitting_item(state.catch,staff_capacity(record))>=0 and (state.counter.size()<DATA.MAX_STOCK if zone==0 else state.input.size()<DATA.MAX_STOCK)
   var food_ready: bool=zone>0 and not state.output.is_empty() and state.counter.size()<DATA.MAX_STOCK
   if not record.bag.is_empty():
    task="food" if record.bag[0].kind=="food" else "raw"
   elif task.is_empty() or (task=="raw" and not raw_ready) or (task=="food" and not food_ready):
    if food_ready and (not raw_ready or worker.get("last_task","raw")=="raw"):
     task="food"
    elif raw_ready:task="raw"
    else:task=""
   worker["task"]=task
   var source: Array=state.output if task=="food" else state.catch
   var destination: Array=state.counter if task=="food" or zone==0 else state.input
   var take_kind := "output" if task=="food" else "catch"
   var drop_kind := "counter" if task=="food" or zone==0 else "drop"
   var take_point := point(zone,take_kind)
   var drop_point := point(zone,drop_kind)
   if not record.bag.is_empty():
    if move_agent(worker,drop_point,delta,staff_speed(record),true):
     while not record.bag.is_empty() and destination.size()<DATA.MAX_STOCK:
      var item: Dictionary=record.bag.pop_front()
      destination.append(item)
      worker.node.set_meta("handover",0.6)
      item_flight(worker.node.position+Vector3(0,1.35,0.4),stock_top(zone,drop_kind),item)
     if record.bag.is_empty():
      worker["last_task"]=task
      worker["task"]=""
   elif move_agent(worker,take_point,delta,staff_speed(record),false) and destination.size()<DATA.MAX_STOCK:
    while destination.size()+record.bag.size()<DATA.MAX_STOCK:
     var fit := fitting_item(source,staff_capacity(record)-DATA.weight(record.bag))
     if fit<0:break
     var picked: Dictionary=source.pop_at(fit)
     record.bag.append(picked)
     item_flight(stock_top(zone,take_kind),worker.node.position+Vector3(0,1.3,0),picked)
     worker.node.set_meta("handover",0.6)
  worker.node.set_meta("carrying",not record.bag.is_empty())
  worker.node.set_meta("load_ratio",float(DATA.weight(record.bag))/staff_capacity(record))
  if near:
   worker["bag_time"]=float(worker.get("bag_time",0))+delta
   if worker.bag_time>=0.15:
    show_bag(worker.models,record.bag)
    worker.bag_time=0.0
  if worker.tool!=null:
   var work: float=worker.node.get_meta("work",0.0)
   worker.tool.rotation.z=0.5+mining_swing(work)*0.35

func update_miner(worker: Dictionary,delta: float) -> void:
 var record: Dictionary=worker.data
 var zone: int=record.zone
 var state: Dictionary=profile.zones[zone]
 var delegate := count_workers("runner",zone)>0
 var store: Array=state.catch if delegate else (state.counter if zone==0 else state.input)
 var drop := point(zone,"catch") if delegate else (point(zone,"counter") if zone==0 else point(zone,"drop"))
 var target: Dictionary={}
 var best := INF
 var room := staff_capacity(record)-DATA.weight(record.bag)
 for entry in fish_by_zone.get(zone,[]):
  if entry.zone!=zone or entry.respawn>0 or int(entry["yield"])>room:
   continue
  var distance := flat_distance(worker.node.position,entry.node.position)
  if distance<best:
   best=distance
   target=entry
 if (room<=0 or target.is_empty() or store.size()>=DATA.MAX_STOCK) and not record.bag.is_empty():
  if move_agent(worker,drop,delta,staff_speed(record),true):
   while not record.bag.is_empty() and store.size()<DATA.MAX_STOCK:
    var item: Dictionary=record.bag.pop_front()
    store.append(item)
    worker.node.set_meta("handover",0.6)
    item_flight(worker.node.position+Vector3(0,1.3,0),stock_top(zone,"catch" if delegate else ("counter" if zone==0 else "drop")),item)
  return
 if target.is_empty() or store.size()>=DATA.MAX_STOCK:
  move_agent(worker,worker.node.position,delta,staff_speed(record),false)
  return
 var distance := flat_distance(worker.node.position,target.node.position)
 if distance>float(target.reach)*0.85:
  move_agent(worker,target.node.position,delta,staff_speed(record),false)
 else:
  worker.velocity=worker.velocity.move_toward(Vector3.ZERO,12*delta)
  if worker.hit<=0:
   worker.hit=1.5/(1+0.3*(int(record.rank)-1))
   var won := strike_ice(target,1+int(record.rank)/2,room)
   worker.node.set_meta("work",0.5)
   if flat_distance(hero.position,worker.node.position)<8:
    play_sound("ice",-23)
   if won:
    record.bag.append(DATA.raw(int(target.tier),int(target.species)))
    item_flight(target.node.position,worker.node.position+Vector3(0,1.2,0.4),DATA.raw(int(target.tier),int(target.species)))
    gain_xp(1)
  if flat_distance(hero.position,worker.node.position)<35:
   animate_worker(worker.node,false,delta)

func move_agent(agent: Dictionary,target: Vector3,delta: float,speed: float,carrying: bool) -> bool:
 var actor: Node3D=agent.node
 var changed := not (agent.target as Vector3).is_finite() or flat_distance(agent.target,target)>0.3
 if changed:
  agent.target=target
  agent.path=[]
  var zone: int=agent.data.zone if agent.has("data") else zone_for_position(actor.position)
  var base_z := zone*DATA.ZONE_SPACING
  if actor.position.x<-4 and target.x>0:
   agent.path.append(Vector3(-4,0,base_z+6))
  elif actor.position.x>0 and target.x<-4:
   agent.path.append(Vector3(-4,0,base_z+6))
  elif (carrying or (agent.has("data") and agent.data.role=="seller")) and actor.position.z>base_z+2 and target.z<base_z+1:
   agent.path.append(Vector3(9,0,base_z+5.2))
   agent.path.append(Vector3(9,0,base_z-0.8))
   if agent.has("data") and agent.data.role=="seller":
    agent.path.append(Vector3(9,0,target.z))
  agent.path.append(target)
  if flat_distance(hero.position,actor.position)<40:
   var safe_path: Array=[]
   var from := actor.position
   for to in agent.path:
    var segment := navigation_path(from,to)
    safe_path.append_array(segment)
    from=to
   agent.path=safe_path
 var waypoint: Vector3=agent.path[0] if not agent.path.is_empty() else target
 var direction := Vector3(waypoint.x-actor.position.x,0,waypoint.z-actor.position.z)
 var distance := direction.length()
 if distance<0.18 and agent.path.size()>1:
  agent.path.pop_front()
  return false
 var desired_speed := minf(speed,sqrt(maxf(0,2*10.0*distance)))
 var desired := direction.normalized()*desired_speed if distance>0.06 else Vector3.ZERO
 # Gentle separation keeps multiple helpers from occupying the same walking position.
 if distance>0.7:
  for other in workers_live:
   if other.node==actor or absf(other.node.position.z-actor.position.z)>8:
    continue
   var away := Vector3(actor.position.x-other.node.position.x,0,actor.position.z-other.node.position.z)
   if away.length()>0.01 and away.length()<0.55:
    desired+=away.normalized()*(0.55-away.length())*2.0
 agent.velocity=agent.velocity.move_toward(desired,9.0*delta)
 var step: Vector3=agent.velocity*delta
 if step.length()>distance and distance>0:
  step=direction
 var old_position := actor.position
 actor.position+=step
 if flat_distance(hero.position,actor.position)<40:actor.position=resolve_furniture_collision(old_position,actor.position)
 actor.position.y=lerpf(actor.position.y,stand_height(actor.position),1-exp(-10*delta))
 if agent.velocity.length()>0.08:
  actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-agent.velocity.x,-agent.velocity.z),1.0-exp(-10.0*delta))
 if flat_distance(hero.position,actor.position)<35:
  animate_worker(actor,agent.velocity.length()>0.08,delta)
 return flat_distance(actor.position,target)<0.2 and agent.path.size()<=1

func staff_capacity(record: Dictionary) -> int:
 if record.role=="fisher":
  return 3+2*(int(record.rank)-1)
 return 2+int(record.rank)

func staff_speed(record: Dictionary) -> float:
 return 1.5+0.28*(int(record.rank)-1)

func update_buyers(delta: float) -> void:
 for buyer in buyers_live.duplicate():
  if absi(int(buyer.zone)-selected_zone)>0:
   buyer.node.queue_free()
   buyers_live.erase(buyer)
 buyer_clock-=delta
 if buyer_clock<=0:
  buyer_clock=0.4
  for z in range(DATA.ZONES.size()):
   if absi(z-selected_zone)>0 or not profile.zones[z].unlocked:
    continue
   var at_counter: bool=not shop_open and selected_zone==z and flat_distance(hero.position,point(z,"sale"))<0.95
   var backpack_offer: bool=at_counter and first_kind(profile.bag,"raw" if z==0 else "food")>=0
   if not profile.zones[z].counter.is_empty() or backpack_offer:
    zone_live[z].business_open=true
   if not zone_live[z].business_open:
    continue
   var waiting := 0
   var total := 0
   for buyer in buyers_live:
    if buyer.zone==z:
     total+=1
     if not buyer.depart:waiting+=1
   if waiting<5 and total<7:
    var colors := [Color("c6a454"),Color("667f99"),Color("a96860"),Color("78976d"),Color("967aaf"),Color("c88b52")]
    var node := person(Vector3(5,0,z*DATA.ZONE_SPACING-13.0),colors[customer_serial%colors.size()])
    customer_serial+=1
    node.name="Customer_%d" % customer_serial
    buyers_live.append({"node":node,"zone":z,"depart":false,"stage":0,"velocity":Vector3.ZERO,"path":[],"target":Vector3.INF})
 for z in range(DATA.ZONES.size()):
  var place := 0
  for buyer in buyers_live.duplicate():
   if buyer.zone!=z:
    continue
   if not buyer.depart:
    var target := Vector3(5,0,z*DATA.ZONE_SPACING-5.3-float(place)*0.85)
    move_agent(buyer,target,delta,2.3,false)
    if flat_distance(buyer.node.position,target)<0.2:
     buyer.node.rotation.y=lerp_angle(buyer.node.rotation.y,PI,1-exp(-8*delta))
    place+=1
   else:
    var target := Vector3(6.5,0,z*DATA.ZONE_SPACING-5.3) if buyer.stage==0 else Vector3(6.5,0,z*DATA.ZONE_SPACING-14)
    if move_agent(buyer,target,delta,2.6,true):
     if buyer.stage==0:
      buyer.stage=1
     else:
      buyer.node.queue_free()
      buyers_live.erase(buyer)

func update_sales(delta: float) -> void:
 for z in range(DATA.ZONES.size()):
  if not profile.zones[z].unlocked:
   continue
  var hero_selling: bool=not shop_open and selected_zone==z and flat_distance(hero.position,point(z,"sale"))<0.95
  var bag_index := first_kind(profile.bag,"raw" if z==0 else "food") if hero_selling else -1
  var rate := 1.0 if hero_selling else 0.0
  for worker in workers_live:
   if worker.data.role=="seller" and worker.data.zone==z and flat_distance(worker.node.position,seller_station(worker.data))<0.4:
    rate+=1.0/(3.0/(1.0+0.4*(int(worker.data.rank)-1)))
  zone_live[z].sale_clock=maxf(0,float(zone_live[z].sale_clock)-delta)
  if absi(z-selected_zone)>0 and rate>0 and not profile.zones[z].counter.is_empty() and zone_live[z].sale_clock<=0:
   profile.zones[z].cash+=sale_value(profile.zones[z].counter.pop_front())
   zone_live[z].sale_clock=1.0/rate
   continue
  if rate<=0 or (profile.zones[z].counter.is_empty() and bag_index<0) or zone_live[z].sale_clock>0:
   continue
  var first: Dictionary={}
  for buyer in buyers_live:
   if buyer.zone==z and not buyer.depart:
    first=buyer
    break
  if first.is_empty() or flat_distance(first.node.position,Vector3(5,0,z*DATA.ZONE_SPACING-5.3))>0.25:
   continue
  var from_bag := bag_index>=0
  var item: Dictionary=profile.bag.pop_at(bag_index) if from_bag else profile.zones[z].counter.pop_front()
  profile.zones[z].cash+=sale_value(item)
  zone_live[z].sale_clock=1.0/rate
  if selected_zone==z and flat_distance(hero.position,point(z,"sale"))<0.95:
   hero.set_meta("handover",0.65)
  item_flight(hero.position+Vector3(0,1.3,0.3) if from_bag else stock_top(z,"counter"),first.node.position+Vector3(0,0.9,-0.4),item)
  first.depart=true
  first.node.set_meta("carrying",true)
  first.node.set_meta("handover",0.6)
  var parcel := make_dish(first.node,Vector3(0,0.8,-0.45),int(item.recipe) if item.kind=="food" else 0)
  parcel.scale=Vector3.ONE*0.5
  for worker in workers_live:
   if worker.data.role=="seller" and worker.data.zone==z:
    worker.node.set_meta("handover",0.6)
  coin_flight(Vector3(5,1.6,z*DATA.ZONE_SPACING-3),point(z,"coins")+Vector3(0,0.4,0))
  play_sound("sale",-22)
  gain_xp(3)

func sale_value(item: Dictionary) -> int:
 return int(round(int(item.value)*(1.0+0.035*(int(profile.hero.trade)-1))))

func count_workers(role: String,index: int) -> int:
 if worker_count_size!=profile.workers.size():
  worker_counts.clear()
  worker_count_size=profile.workers.size()
  for worker in profile.workers:
   var key := str(worker.zone)+":"+str(worker.role)
   worker_counts[key]=int(worker_counts.get(key,0))+1
 return int(worker_counts.get(str(index)+":"+role,0))

func capacity() -> int:
 return 5+3*(int(profile.hero.bag)-1)

func move_speed() -> float:
 return 4.6+0.3*(int(profile.hero.speed)-1)

func first_kind(items: Array,kind: String) -> int:
 for i in range(items.size()):
  if items[i].kind==kind:
   return i
 return -1

func fitting_item(items: Array,room: int) -> int:
 for i in range(items.size()):
  if DATA.item_weight(items[i])<=room:
   return i
 return -1

func flat_distance(a: Vector3,b: Vector3) -> float:
 return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))

func last_unlocked() -> int:
 var index := 0
 for i in range(DATA.ZONES.size()):
  if profile.zones[i].unlocked:
   index=i
 return index

func zone_for_position(pos: Vector3) -> int:
 return clampi(int(round(pos.z/DATA.ZONE_SPACING)),0,last_unlocked())

func stand_height(pos: Vector3) -> float:
 var zone := clampi(int(round(pos.z/DATA.ZONE_SPACING)),0,DATA.ZONES.size()-1)
 var local_z := pos.z-zone*DATA.ZONE_SPACING
 if Geometry2D.is_point_in_polygon(Vector2(pos.x,local_z),island_outline(zone)):return 0.2
 var edge := -3.0 if local_z>=3.5 else -0.5
 if local_z>13 or local_z<-7:
  return -0.7 if pos.x<2.8 or pos.x>7.2 else 0.12
 return lerpf(water_y+0.03,0.2,smoothstep(edge-1.5,edge,pos.x))

func mining_swing(time_left: float) -> float:
 if time_left<=0:return 0.0
 var t := clampf((0.5-time_left)/0.5,0,1)
 if t<0.32:return lerpf(-0.25,-1.3,smoothstep(0,0.32,t))
 if t<0.54:return lerpf(-1.3,0.9,smoothstep(0.32,0.54,t))
 return lerpf(0.9,0.0,smoothstep(0.54,1.0,t))

func animate_worker(actor: Node3D,moving: bool,delta: float) -> void:
 if not actor.visible:
  if actor.has_meta("rig"):actor.get_meta("rig").last=actor.position
  return
 if not actor.has_meta("rig"):
  return
 var rig: Dictionary=actor.get_meta("rig")
 var travelled := flat_distance(actor.position,rig.last)
 rig.last=actor.position
 var previous: float=rig.phase
 if moving:
  rig.phase+=minf(travelled*(3.3+clampf(float(actor.get_meta("load_ratio",0)),0,1)*0.55),delta*13)
 var phase: float=rig.phase
 var speed := minf(travelled/maxf(delta,0.001),7.0)
 rig["gait_speed"]=lerpf(float(rig.get("gait_speed",0.0)),speed,1-exp(-15*delta))
 var load_weight := clampf(float(actor.get_meta("load_ratio",0)),0,1)
 var amplitude := clampf(float(rig.gait_speed)*0.18,0.0,0.58)*(1.0-load_weight*0.2) if moving else 0.0
 var activity := clampf(float(rig.gait_speed)/1.8,0,1) if moving else 0.0
 var compression := maxf(0,cos(phase*2.0))*activity
 var bob := -compression*(0.038+load_weight*0.028)+sin(phase*2.0)*0.014*activity
 var turn_rate := clampf(angle_difference(float(rig.get("yaw",actor.rotation.y)),actor.rotation.y)/maxf(delta,0.001),-3,3)
 rig["yaw"]=actor.rotation.y
 rig["turn"]=lerpf(float(rig.get("turn",0.0)),turn_rate,1-exp(-8*delta))
 var weight := 1-exp(-11*delta)
 var handover := maxf(0,float(actor.get_meta("handover",0))-delta)
 var work := maxf(0,float(actor.get_meta("work",0))-delta)
 actor.set_meta("handover",handover)
 actor.set_meta("work",work)
 var cheer := maxf(0,float(actor.get_meta("cheer",0))-delta)
 actor.set_meta("cheer",cheer)
 var carrying: bool=actor.get_meta("carrying",false) or (actor==hero and not profile.bag.is_empty())
 for i in range(2):
  var cycle := fposmod((phase+float(i)*PI)/TAU,1.0)
  var swing_t := clampf((cycle-0.62)/0.38,0.0,1.0)
  var stride := lerpf(1.0,-1.0,cycle/0.62) if cycle<0.62 else lerpf(-1.0,1.0,smoothstep(0.0,1.0,swing_t))
  var lift := sin(swing_t*PI)
  rig.hips[i].position.y=lerpf(rig.hips[i].position.y,0.4+lift*0.025*activity,weight)
  rig.arms[i].position.y=lerpf(rig.arms[i].position.y,0.96+bob,weight)
  rig.hips[i].rotation.x=lerpf(rig.hips[i].rotation.x,stride*amplitude,weight)
  rig.knees[i].rotation.x=lerpf(rig.knees[i].rotation.x,pow(lift,1.4)*amplitude*1.55+compression*load_weight*0.045,weight)
  if rig.has("ankles"):
   var foot_roll: float=-rig.hips[i].rotation.x-rig.knees[i].rotation.x+amplitude*(0.16*cos(cycle/0.62*PI) if cycle<0.62 else -0.22*sin(swing_t*PI))
   rig.ankles[i].rotation.x=lerpf(rig.ankles[i].rotation.x,foot_roll,weight)
  var arm := -stride*amplitude*0.6*(1.0-clampf(float(actor.get_meta("load_ratio",0)),0,1)*0.3)
  if carrying:
   arm=0.82+sin(phase*2)*0.025
  if handover>0:
   arm=0.65+sin((0.65-handover)*PI/0.65)*0.45
  if cheer>0 and not moving:
   arm=-1.5+sin(cheer*15)*0.15
  if work>0 and i==1:
   arm=mining_swing(work)
  elif work>0:
   arm=0.35
  var side := -1.0 if i==0 else 1.0
  rig.hips[i].rotation.z=lerpf(rig.hips[i].rotation.z,side*lift*activity*0.045,weight)
  rig.arms[i].rotation.z=lerpf(rig.arms[i].rotation.z,side*(0.05+activity*0.045)+sin(phase+float(i)*PI)*amplitude*0.04,weight)
  rig.arms[i].rotation.x=lerpf(rig.arms[i].rotation.x,arm,weight)
  rig.elbows[i].rotation.x=lerpf(rig.elbows[i].rotation.x,0.42 if work>0 else 0.24 if carrying or handover>0 else 0.09+maxf(0,stride)*amplitude*0.35,weight)
 rig.body.position.y=lerpf(rig.body.position.y,0.65+bob-(load_weight*0.015)+(0.0 if moving else sin(clock*1.5+rig.offset)*0.006),weight)
 rig.body.position.x=lerpf(rig.body.position.x,sin(phase)*0.025*activity*(1+load_weight*0.4),weight)
 rig.body.rotation.y=lerp_angle(rig.body.rotation.y,sin(phase)*amplitude*0.18 if moving and not carrying else 0.0,weight)
 rig.body.rotation.x=lerpf(rig.body.rotation.x,-0.12 if handover>0 else -0.035-load_weight*0.14 if moving else -load_weight*0.045,weight)
 rig.body.rotation.z=lerpf(rig.body.rotation.z,sin(phase)*amplitude*(0.085+load_weight*0.065)+float(rig.turn)*0.025 if moving else 0.0,weight)
 if rig.has("head"):
  rig.head.rotation.y=lerp_angle(rig.head.rotation.y,-float(rig.turn)*0.06-rig.body.rotation.y*0.35,weight)
  rig.head.rotation.z=lerpf(rig.head.rotation.z,-rig.body.rotation.z*0.5,weight)
  rig.head.rotation.x=lerpf(rig.head.rotation.x,-rig.body.rotation.x*0.35+(sin(clock*2+rig.offset)*0.025 if not moving else 0.0),weight)
  if not moving and work<=0 and handover<=0:rig.head.rotation.y=lerp_angle(rig.head.rotation.y,sin(clock*0.7+rig.offset)*0.18,weight)
 if cheer>0 and not moving:rig.body.position.y+=maxf(0,sin(cheer*PI/0.8))*0.035
 if work>0:
  var swing := mining_swing(work)
  rig.body.rotation.x=lerpf(rig.body.rotation.x,0.08+swing*0.13,weight)
  rig.body.rotation.y=lerp_angle(rig.body.rotation.y,swing*0.10,weight)
  rig.knees[0].rotation.x=lerpf(rig.knees[0].rotation.x,0.12,weight)
  rig.knees[1].rotation.x=lerpf(rig.knees[1].rotation.x,0.09,weight)
 if handover>0:
  rig.body.rotation.x=lerpf(rig.body.rotation.x,0.16,weight)
 if moving and int(phase/PI)!=int(previous/PI) and flat_distance(actor.position,hero.position)<6:
  play_sound("step",-22 if actor==hero else -30)

func item_flight(start: Vector3,finish: Vector3,item: Dictionary) -> void:
 if flat_distance(hero.position,start)>40 and flat_distance(hero.position,finish)>40:return
 var model: Node3D=make_fish(self,start,int(item.get("species",0))) if item.kind=="raw" else make_dish(self,start,int(item.recipe))
 model.scale=Vector3.ONE*0.45*(float(DATA.FISH[int(item.size)].scale) if item.kind=="raw" else 1.0)
 var tween := create_tween()
 tween.tween_method(func(t: float): model.position=start.lerp(finish,t)+Vector3.UP*sin(t*PI)*0.4,0.0,1.0,0.17)
 tween.tween_callback(model.queue_free)

func coin_flight(start: Vector3,finish: Vector3) -> void:
 if flat_distance(hero.position,start)>40 and flat_distance(hero.position,finish)>40:return
 var model := make_coin(self,start)
 var tween := create_tween()
 tween.tween_method(func(t: float): model.position=start.lerp(finish,t)+Vector3.UP*sin(t*PI)*0.4,0.0,1.0,0.2)
 tween.tween_callback(model.queue_free)

func update_displays() -> void:
 show_bag(hero_carry_models,profile.bag)
 cargo=0
 hero_dish_count=0
 for item in profile.bag:
  if item.kind=="raw":
   cargo+=DATA.item_weight(item)
  else:
   hero_dish_count+=1
 cooked_stock=profile.zones[selected_zone].counter.size()
 pending_coins=int(profile.zones[selected_zone].cash)
 for i in range(DATA.ZONES.size()):
  var state: Dictionary=profile.zones[i]
  var runtime: Dictionary=zone_live[i]
  if runtime.floor==null:continue
  var nearby := absi(i-selected_zone)<=1
  if kitchen_steam[i]!=null:
   kitchen_steam[i].emitting=state.unlocked and nearby and state.cooking!=null and not weak_device
  var station_visible: bool=state.unlocked and nearby and count_workers("runner",i)>0
  runtime.catch_table.visible=station_visible
  sync_table_items(runtime.catch_models,state.catch,stock_top(i,"catch"),station_visible)
  sync_table_items(runtime.raw_models,state.input,stock_top(i,"drop"),state.unlocked and nearby and i>0)
  sync_table_items(runtime.counter_models,state.counter,stock_top(i,"counter"),state.unlocked and nearby)
  sync_table_items(runtime.output_models,state.output,stock_top(i,"output"),state.unlocked and nearby and i>0)
  for j in range(runtime.cash_models.size()):
   runtime.cash_models[j].visible=state.unlocked and nearby and j<mini(12,int(ceil(float(state.cash)/10.0)))

func update_pads(delta: float) -> void:
 for pad in pads:
  if pad.zone<0:
   continue
  pad.pos=point(int(pad.zone),str(pad.kind))
  pad.root.position=pad.root.position.lerp(pad.pos+Vector3(0,0.24,0),1-exp(-12*delta))
  var state: Dictionary=profile.zones[pad.zone]
  pad.root.visible=state.unlocked and (pad.kind!="catch" or count_workers("runner",int(pad.zone))>0) and (pad.kind!="counter" or count_workers("runner",int(pad.zone))>0)
  var value := ""
  match pad.kind:
   "sale","counter": value=str(state.counter.size())
   "coins": value=str(state.cash)
   "catch": value=str(state.catch.size())
   "drop": value=str(state.input.size())
   "output": value=str(state.output.size())
   "cook": value="%d%%" % int(100*float(state.progress)/maxf(0.1,kitchen_time(pad.zone,int(state.cooking.size) if state.cooking!=null else 0))) if state.cooking!=null else "▶"
   "shop": value=""
  pad.label.text=value
  var active := flat_distance(hero.position,pad.pos)<0.95
  pad.inset.material_override=material(Color("797560") if active else Color("66564a"))
  var target := 1.02 if active else 1.0
  pad.root.scale=pad.root.scale.lerp(Vector3(target,1,target),1-exp(-8*delta))

func refresh_unlocks() -> void:
 for i in range(DATA.ZONES.size()):
  if zone_live[i].floor==null:continue
  var owned: bool=profile.zones[i].unlocked
  zone_live[i].floor.set_shader_parameter("owned",1.0 if owned else 0.0)
  zone_live[i].sign.text=DATA.ZONES[i].name if owned else "ЗОНА %d · %d монет" % [i+1,int(DATA.ZONES[i].cost)]
  for pad in pads:
   if pad.zone==i:
    pad.root.visible=owned and (pad.kind!="catch" or count_workers("runner",i)>0) and (pad.kind!="counter" or count_workers("runner",i)>0)
  if zone_live[i].unlock!=null:
   var label: Label3D=zone_live[i].unlock
   label.get_parent().visible=not owned and profile.zones[i-1].unlocked

func unlock_zone(index: int) -> bool:
 if index<1 or index>=DATA.ZONES.size() or profile.zones[index].unlocked or not profile.zones[index-1].unlocked or money<int(DATA.ZONES[index].cost):
  return false
 money-=int(DATA.ZONES[index].cost)
 profile.zones[index].unlocked=true
 grant_zone_reward(index)
 if absi(index-selected_zone)<=1:ensure_zone(index)
 refresh_unlocks()
 play_sound("level",-16)
 celebrate_zone(index)
 save_game()
 return true

func open_shop() -> void:
 if flat_distance(hero.position,point(selected_zone,"shop"))>1.4:
  return
 shop_open=true
 shop_entry_armed=false
 stick=Vector2.ZERO
 mouse_drag=false
 touch_id=-1
 hero_velocity=Vector3.ZERO
 campaign_ui.set_open(true)
 play_sound("shop",-20)

func close_shop() -> void:
 shop_open=false
 stick=Vector2.ZERO
 mouse_drag=false
 touch_id=-1
 campaign_ui.set_open(false)

func purchase(action: String,index: int,uid: int = -1) -> bool:
 if not shop_open:
  return false
 if action in ["clothes_buy","clothes_equip"]:return wardrobe_action(action,uid)
 var item := catalogue_item(action,index,uid)
 if item.is_empty() or not item.available:
  return false
 if action=="unlock":
  return unlock_zone(index)
 if action=="travel":
  ensure_zone(index)
  selected_zone=index
  hero.position=point(index,"shop")+Vector3(0,0.2,2.7)
  hero_velocity=Vector3.ZERO
  hero.reset_physics_interpolation()
  streamed_zone=-100
  stream_regions()
  camera_focus=hero.position
  close_shop()
  return true
 money-=int(item.cost)
 if DATA.ROLES.has(action):
  var record := {"spent":int(item.cost),"uid":int(profile.next_uid),"role":action,"zone":index,"rank":1,"bag":[]}
  profile.next_uid+=1
  profile.workers.append(record)
  spawn_worker(record)
 elif action.begins_with("hero_"):
  var stat := action.trim_prefix("hero_")
  profile.hero[stat]=int(profile.hero[stat])+1
 elif action=="kitchen":
  profile.zones[index].kitchen_level+=1
 elif action=="rank":
  for record in profile.workers:
   if int(record.uid)==uid:
    record.rank+=1
    break
 update_displays()
 update_pads(0)
 play_sound("hire",-18)
 save_game()
 return true

func catalogue_item(action: String,index: int,uid: int = -1) -> Dictionary:
 if action in ["clothes_buy","clothes_equip"]:return clothing_catalogue(action,uid)
 if index<0 or index>=DATA.ZONES.size():
  return {}
 var title := ""
 var detail := ""
 var cost := 0
 var icon := "icons/feast.svg"
 var available := false
 var done := false
 if action=="unlock":
  title="Зона %d · %s" % [index+1,DATA.ZONES[index].name]
  detail=DATA.ZONES[index].kitchen+" · "+DATA.ZONES[index].dish
  cost=int(DATA.ZONES[index].cost)
  done=profile.zones[index].unlocked
  available=index>0 and not done and profile.zones[index-1].unlocked and money>=cost
  icon="icons/"+DATA.ZONES[index].icon+".svg"
 elif action=="travel":
  title=DATA.ZONES[index].name
  detail="Перейти у відкриту зону. "+DATA.ZONES[index].dish
  available=profile.zones[index].unlocked
  icon="icons/"+DATA.ZONES[index].icon+".svg"
 elif not profile.zones[index].unlocked:
  return {}
 elif DATA.ROLES.has(action):
  title=DATA.ROLES[action].title
  var total := 0
  for member in profile.workers:
   if int(member.zone)==index:total+=1
  cost=DATA.hire_cost(action,index,total)
  var amount := count_workers(action,index)
  detail="У зоні: %d/%d. Кожен працівник має власний рівень." % [amount,DATA.role_limit(action)]
  if action=="fisher":
   detail+=" Добуває рибу з крижин."
  elif action=="runner":
   detail+=" Має стіл улову. Носить рибу до кухні або прилавка, а готові страви — на продаж."
  else:
   detail+=" Один продавець у зоні. Прокачка прискорює обслуговування."
  done=amount>=DATA.role_limit(action)
  available=not done and money>=cost
  icon="icons/portrait_"+action+".png"
 elif action.begins_with("hero_"):
  var stat := action.trim_prefix("hero_")
  if not profile.hero.has(stat):
   return {}
  var rank: int=profile.hero[stat]
  title={"tool":"Інструмент","bag":"Рюкзак","speed":"Швидкість героя","trade":"Продаж"}[stat]
  cost=DATA.rounded_cost(float({"tool":35,"bag":40,"speed":50,"trade":55}[stat])*pow(1.62,rank-1)*(1.0+0.12*last_unlocked()))
  detail="Рівень %d/20. " % rank
  if stat=="tool":
   detail+="Сила удару %d → %d." % [rank,mini(20,rank+1)]
  elif stat=="bag":
   detail+="Місць %d → %d." % [capacity(),5+3*mini(rank,19)]
  elif stat=="speed":
   detail+="Швидкість %.1f → %.1f." % [move_speed(),4.6+0.3*mini(rank,19)]
  else:
   detail+="Більше монет за кожен продаж."
  done=rank>=20
  available=not done and money>=cost
  icon="icons/"+stat+".svg"
 elif action=="kitchen":
  if index==0:
   return {}
  var rank: int=profile.zones[index].kitchen_level
  title="Розвиток кухні"
  cost=DATA.rounded_cost(150*pow(1.75,rank-1)*pow(1.35,index))
  detail="Рівень %d/10. %s: %.1f с за дрібну рибу." % [rank,DATA.ZONES[index].dish,kitchen_time(index)]
  done=rank>=10
  available=not done and money>=cost
  icon="icons/kitchen.svg"
 elif action=="rank":
  var selected: Dictionary={}
  for record in profile.workers:
   if record.uid==uid and record.zone==index:
    selected=record
    break
  if selected.is_empty():
   return {}
  title="%s #%d" % [DATA.ROLES[selected.role].title,uid]
  var rank: int=selected.rank
  cost=DATA.rounded_cost(85*pow(1.65,rank-1)*pow(1.35,index))
  detail="Власний рівень %d/10. Швидкість %.1f → %.1f." % [rank,staff_speed(selected),1.5+0.28*mini(rank,9)]
  if selected.role!="seller":
   detail+=" Місткість %d." % staff_capacity(selected)
  else:
   detail+=" Додає швидкість обслуговування."
  done=rank>=10
  available=not done and money>=cost
  icon="icons/portrait_"+selected.role+".png"
 else:
  return {}
 if action=="unlock" and index>0:detail+="\nНагорода: "+reward_description(index)
 return {"action":action,"zone":index,"uid":uid,"title":title,"detail":detail,"cost":cost,"icon":icon,"available":available,"done":done}

func save_game() -> void:
 profile.wallet=money
 profile.level=player_level
 profile.xp=xp
 profile.audio_volume=audio_volume
 profile.sound_mix=sound_mix.duplicate(true)
 profile.sounds_enabled=sounds_enabled
 var file := FileAccess.open("user://progress.pending.json",FileAccess.WRITE)
 if file==null:return
 file.store_string(JSON.stringify(profile))
 file.flush()
 var error := file.get_error()
 file.close()
 if error!=OK:return
 var original := ProjectSettings.globalize_path("user://progress.json")
 var backup := ProjectSettings.globalize_path("user://progress.backup.json")
 if FileAccess.file_exists(original):
  if DirAccess.copy_absolute(original,backup)!=OK:return
 DirAccess.rename_absolute(ProjectSettings.globalize_path("user://progress.pending.json"),original)

func continue_saved() -> void:
 if not start_pending:
  return
 var data=read_progress()
 if data.is_empty():return
 if data is Dictionary:
  if int(data.get("schema",0))>=20:
   restore_campaign(data)
  else:
   var original := ProjectSettings.globalize_path("user://progress.json")
   var backup := ProjectSettings.globalize_path("user://progress.before-campaign.json")
   if not FileAccess.file_exists(backup):
    DirAccess.copy_absolute(original,backup)
   migrate_legacy(data)
 for entry in fish_live:
  entry.species=fish_species_for(int(entry.zone),int(entry.slot))
  apply_fish_species(entry.fish,int(entry.species))
 money=int(profile.wallet)
 player_level=int(profile.level)
 xp=int(profile.xp)
 audio_volume=float(profile.audio_volume)
 sound_mix=read_sound_mix(profile.sound_mix)
 sounds_enabled=bool(profile.sounds_enabled)
 audio.set_enabled(sounds_enabled)
 audio.set_volume(audio_volume)
 apply_sound_mix()
 for record in profile.workers:
  spawn_ice_field(int(record.zone))
  spawn_worker(record)
 selected_zone=clampi(int(profile.last_zone),0,last_unlocked())
 ensure_zone(selected_zone)
 ensure_zone(selected_zone+1)
 hero.position=point(selected_zone,"shop")+Vector3(0,0.2,-2)
 camera_focus=hero.position
 rebuild_hero_outfit()
 refresh_unlocks()
 start_pending=false

func restore_campaign(data: Dictionary) -> void:
 worker_count_size=-1
 profile=DATA.new_profile()
 var cycles=data.get("ice_cycles",{})
 if cycles is Dictionary:
  for key in cycles:
   if str(key).length()<10:profile.ice_cycles[str(key)]=clampi(int(cycles[key]),0,2000000000)
 profile.wallet=maxi(0,int(data.get("wallet",0)))
 profile.level=clampi(int(data.get("level",1)),1,50)
 profile.xp=maxi(0,int(data.get("xp",0)))
 profile.tutorial_step=clampi(int(data.get("tutorial_step",TUTORIAL_STEPS)),0,TUTORIAL_STEPS)
 if int(data.get("schema",0))<31 and profile.tutorial_step>=6:profile.tutorial_step=TUTORIAL_STEPS
 profile.audio_volume=clampf(float(data.get("audio_volume",1)),0,1)
 profile.sound_mix=read_sound_mix(data.get("sound_mix",{}))
 profile.sounds_enabled=bool(data.get("sounds_enabled",true))
 var stats=data.get("hero",{})
 if stats is Dictionary:
  for key in profile.hero:
   profile.hero[key]=clampi(int(stats.get(key,1)),1,20)
 profile.bag=read_campaign_items(data.get("bag",[]),64)
 var zones=data.get("zones",[])
 if zones is Array:
  for i in range(mini(DATA.ZONES.size(),zones.size())):
   if not zones[i] is Dictionary:
    continue
   var source: Dictionary=zones[i]
   var target: Dictionary=profile.zones[i]
   target.unlocked=i==0 or (bool(source.get("unlocked",false)) and profile.zones[i-1].unlocked)
   target.kitchen_level=clampi(int(source.get("kitchen_level",1)),1,10)
   target.running=bool(source.get("running",false))
   target.cash=maxi(0,int(source.get("cash",0)))
   for key in ["catch","input","output","counter"]:
    target[key]=read_campaign_items(source.get(key,[]),DATA.MAX_STOCK)
   var cooking=source.get("cooking",null)
   if cooking is Dictionary:
    var temp := read_campaign_items([cooking],1)
    target.cooking=temp[0] if not temp.is_empty() else null
    target.progress=maxf(0,float(source.get("progress",0)))
 var recovered=data.get("recovered_cargo",[])
 if recovered is Array:
  for cargo in recovered:
   if not cargo is Dictionary:continue
   var items := read_campaign_items([cargo.get("item",{})],1)
   if not items.is_empty():profile.recovered_cargo.append({"zone":clampi(int(cargo.get("zone",0)),0,last_unlocked()),"item":items[0]})
 var records=data.get("workers",[])
 var seen := {}
 if records is Array:
  records=records.duplicate(true)
  records.sort_custom(func(a,b):return int(a.get("rank",1))>int(b.get("rank",1)) if a is Dictionary and b is Dictionary else false)
  for source in records:
   if not source is Dictionary:
    continue
   var role := str(source.get("role",""))
   var zone := clampi(int(source.get("zone",0)),0,DATA.ZONES.size()-1)
   var uid := maxi(1,int(source.get("uid",1)))
   if role=="collector" and not seen.has(uid):
    seen[uid]=true
    var rank := clampi(int(source.get("rank",1)),1,5)
    profile.wallet+=90+60*rank*(rank-1)
    for item in read_campaign_items(source.get("bag",[]),16):
     profile.recovered_cargo.append({"zone":mini(zone,last_unlocked()),"item":item})
    continue
   if role=="seller" and count_workers(role,zone)>=1 and not seen.has(uid):
    profile.wallet+=int(source.get("spent",100))+60*int(source.get("rank",1))*(int(source.get("rank",1))-1)
    for item in read_campaign_items(source.get("bag",[]),64):
     profile.recovered_cargo.append({"zone":zone,"item":item})
    seen[uid]=true
    continue
   if not DATA.ROLES.has(role) or not profile.zones[zone].unlocked or count_workers(role,zone)>=DATA.role_limit(role) or seen.has(uid):
    continue
   seen[uid]=true
   profile.workers.append({"uid":uid,"role":role,"zone":zone,"spent":int(source.get("spent",DATA.ROLES[role].cost)),"rank":clampi(int(source.get("rank",1)),1,10),"bag":read_campaign_items(source.get("bag",[]),16)})
   profile.next_uid=maxi(int(profile.next_uid),uid+1)
 profile.last_zone=clampi(int(data.get("last_zone",0)),0,last_unlocked())
 profile.wardrobe=CLOTHES.sanitize(data.get("wardrobe",{}))
 # Existing unlocked zones are marked claimed: no retroactive money on reload.
 profile.zone_rewards=[0]
 for i in range(1,DATA.ZONES.size()):
  if profile.zones[i].unlocked:profile.zone_rewards.append(i)

func read_campaign_items(value: Variant,limit: int) -> Array:
 var items: Array=[]
 if value is Array:
  for entry in value:
   if items.size()>=limit:
    break
   if not entry is Dictionary:
    continue
   if entry.get("kind","")=="raw":
    items.append(DATA.raw(clampi(int(entry.get("size",0)),0,3),clampi(int(entry.get("species",0)),0,DATA.SPECIES.size()-1)))
   elif entry.get("kind","")=="food":
    items.append(DATA.dish(clampi(int(entry.get("recipe",1)),1,DATA.ZONES.size()-1),clampi(int(entry.get("species",0)),0,DATA.SPECIES.size()-1)))
 return items

func migrate_legacy(data: Dictionary) -> void:
 profile=DATA.new_profile()
 profile.tutorial_step=TUTORIAL_STEPS
 profile.wallet=maxi(0,int(data.get("money",0)))
 if bool(data.get("collector_hired",false)):
  var rank := clampi(int(data.get("collector_rank",1)),1,5)
  profile.wallet+=90+60*rank*(rank-1)
 profile.level=clampi(int(data.get("player_level",1)),1,50)
 profile.xp=maxi(0,int(data.get("xp",0)))
 profile.audio_volume=clampf(float(data.get("audio_volume",1)),0,1)
 profile.sound_mix=read_sound_mix(data.get("sound_mix",{}))
 profile.sounds_enabled=bool(data.get("sounds_enabled",true))
 profile.hero.tool=clampi(int(data.get("level",1)),1,10)
 var old_stats=data.get("upgrades",{})
 if old_stats is Dictionary:
  for key in ["bag","speed","trade"]:
   profile.hero[key]=clampi(int(old_stats.get(key,1)),1,10)
 for i in range(mini(48,maxi(0,int(data.get("cargo",0))))):
  profile.bag.append(DATA.raw(0))
 var raw_count := 0
 for key in ["raw_stock","catch_stock","fisher_load","collector_load"]:
  raw_count+=maxi(0,int(data.get(key,0)))
 for i in range(mini(raw_count,512)):
  if profile.zones[0].catch.size()<DATA.MAX_STOCK:
   profile.zones[0].catch.append(DATA.raw(0))
  elif profile.zones[0].counter.size()<DATA.MAX_STOCK:
   profile.zones[0].counter.append(DATA.raw(0))
  else:
   profile.wallet+=6
 profile.zones[0].cash=maxi(0,int(data.get("pending_coins",0)))
 var food_count := maxi(0,int(data.get("cooked_stock",0)))+maxi(0,int(data.get("kitchen_ready",0)))+maxi(0,int(data.get("hero_dish_count",0)))+maxi(0,int(data.get("runner_load",0)))
 if food_count>0 or int(data.get("kitchen_rank",1))>1 or bool(data.get("kitchen_running",false)):
  profile.zones[1].unlocked=true
  profile.zones[1].kitchen_level=clampi(int(data.get("kitchen_rank",1)),1,5)
  profile.zones[1].running=true
  for i in range(mini(food_count,512)):
   if profile.zones[1].counter.size()<DATA.MAX_STOCK:
    profile.zones[1].counter.append(DATA.dish(1))
   elif profile.zones[1].output.size()<DATA.MAX_STOCK:
    profile.zones[1].output.append(DATA.dish(1))
   else:
    profile.wallet+=14
 var unlocked=data.get("recipe_unlocked",[])
 if unlocked is Array:
  if unlocked.size()>1 and unlocked[1]:
   profile.zones[1].unlocked=true
   profile.zones[2].unlocked=true
  if unlocked.size()>2 and unlocked[2]:
   profile.zones[1].unlocked=true
   profile.zones[2].unlocked=true
   profile.zones[3].unlocked=true
 for role in DATA.ROLES:
  if bool(data.get(role+"_hired",false)):
   var zone := 1 if role=="runner" and profile.zones[1].unlocked else 0
   profile.workers.append({"uid":int(profile.next_uid),"role":role,"zone":zone,"rank":clampi(int(data.get(role+"_rank",1)),1,5),"bag":[]})
   profile.next_uid+=1

func seller_station(record: Dictionary) -> Vector3:
 return Vector3(4.3+float(int(record.uid)%3)*0.7,0,DATA.ZONE_SPACING*int(record.zone)-1.4)

func floor_color(index: int) -> Color:
 return Color(DATA.ZONES[index].color)

func resolve_ice_collision(old_pos: Vector3,new_pos: Vector3) -> Vector3:
 for entry in fish_live:
  if entry.respawn>0 or not profile.zones[entry.zone].unlocked:
   continue
  var center: Vector3=entry.node.position
  var half := float(DATA.FISH[int(entry.tier)].ice)*0.5+0.22
  if absf(new_pos.x-center.x)>=half or absf(new_pos.z-center.z)>=half:
   continue
  if old_pos.x<=center.x-half:
   new_pos.x=center.x-half
  elif old_pos.x>=center.x+half:
   new_pos.x=center.x+half
  elif old_pos.z<=center.z-half:
   new_pos.z=center.z-half
  elif old_pos.z>=center.z+half:
   new_pos.z=center.z+half
  else:
   var diff := Vector2(new_pos.x-center.x,new_pos.z-center.z)
   if absf(diff.x)>absf(diff.y):
    new_pos.x=center.x+(half if diff.x>=0 else -half)
   else:
    new_pos.z=center.z+(half if diff.y>=0 else -half)
 return new_pos

func make_particles(pos: Vector3,amount: int,lifetime: float,is_snow: bool) -> CPUParticles3D:
 var particles := CPUParticles3D.new()
 add_child(particles)
 particles.position=pos
 particles.amount=amount
 particles.lifetime=lifetime
 particles.local_coords=false
 particles.direction=Vector3(0.3,-1,0.1) if is_snow else Vector3.UP
 particles.initial_velocity_min=0.6 if is_snow else 0.3
 particles.initial_velocity_max=1.1 if is_snow else 0.6
 particles.gravity=Vector3(0,-0.2,0) if is_snow else Vector3(0,0.15,0)
 if is_snow:
  particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
  particles.emission_box_extents=Vector3(12,0.5,16)
  particles.preprocess=7.0
 var sphere := SphereMesh.new()
 sphere.radius=0.025 if is_snow else 0.09
 sphere.height=sphere.radius*2
 sphere.radial_segments=6
 sphere.rings=3
 particles.mesh=sphere
 var m := StandardMaterial3D.new()
 m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 m.albedo_color=Color(1,1,1,0.35 if not is_snow else 0.8)
 m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 particles.material_override=m
 particles.emitting=is_snow
 return particles

func resolve_furniture_collision(old_pos: Vector3,new_pos: Vector3) -> Vector3:
 for obstacle in furniture:
  if obstacle.has("root") and not obstacle.root.visible:
   continue
  var center: Vector3=obstacle.pos
  var half: Vector2=obstacle.half
  if absf(new_pos.x-center.x)>=half.x or absf(new_pos.z-center.z)>=half.y:
   continue
  if old_pos.x<=center.x-half.x:
   new_pos.x=center.x-half.x
  elif old_pos.x>=center.x+half.x:
   new_pos.x=center.x+half.x
  elif old_pos.z<=center.z-half.y:
   new_pos.z=center.z-half.y
  elif old_pos.z>=center.z+half.y:
   new_pos.z=center.z+half.y
  else:
   var dx := half.x-absf(new_pos.x-center.x)
   var dz := half.y-absf(new_pos.z-center.z)
   if dx<dz:
    new_pos.x=center.x+(half.x if new_pos.x>=center.x else -half.x)
   else:
    new_pos.z=center.z+(half.y if new_pos.z>=center.z else -half.y)
 return new_pos

# Bounded transient ice shards shared by hero and hired fishers.
func emit_ice_fragments(entry: Dictionary,broken: bool) -> void:
 if flat_distance(hero.position,entry.node.position)>28:
  return
 if ice_fragment_mesh==null:
  ice_fragment_mesh=bevel_mesh(Vector3(0.13,0.07,0.19))
  ice_fragment_material=StandardMaterial3D.new()
  ice_fragment_material.albedo_color=Color("a4def1")
  ice_fragment_material.roughness=0.22
  ice_fragment_material.metallic_specular=0.8
 var erosion := 1.0-float(entry.hp)/float(entry.max_hp)
 var count := (8 if broken else 2+int(erosion*2)) if weak_device else (22 if broken else 3+int(erosion*7))
 for i in range(count):
  if ice_effects.size()>=(24 if weak_device else 90):
   var oldest: Dictionary=ice_effects.pop_front()
   oldest.node.queue_free()
  var shard := MeshInstance3D.new()
  shard.mesh=ice_fragment_mesh
  shard.material_override=ice_fragment_material
  add_child(shard)
  var width: float=DATA.FISH[int(entry.tier)].ice
  shard.position=entry.node.position+Vector3(randf_range(-0.4,0.4)*width,0.2,randf_range(-0.4,0.4)*width)
  shard.rotation=Vector3(randf()*PI,randf()*PI,randf()*PI)
  var scale_factor := randf_range(0.7,1.9) if broken else randf_range(0.5,1.0)
  shard.scale=Vector3.ONE*scale_factor
  ice_effects.append({"node":shard,"velocity":Vector3(randf_range(-2.0,2.0),randf_range(1.8,3.6),randf_range(-2.0,2.0)),"life":0.85,"scale":scale_factor})

func update_ice_effects(delta: float) -> void:
 for i in range(ice_effects.size()-1,-1,-1):
  var effect: Dictionary=ice_effects[i]
  effect.life-=delta
  if effect.life<=0:
   effect.node.queue_free()
   ice_effects.remove_at(i)
   continue
  effect.velocity.y-=7.5*delta
  effect.node.position+=effect.velocity*delta
  effect.node.rotation+=Vector3(2,3,1)*delta
  effect.node.scale=Vector3.ONE*float(effect.scale)*minf(1,float(effect.life)*4)

func stock_top(index: int,kind: String) -> Vector3:
 var tops := {"counter":Vector3(5,1.15,-3),"drop":Vector3(0.5,1.15,5.8),"output":Vector3(6,1.15,4.6),"catch":Vector3(-1.9,1.15,9)}
 return tops[kind]+Vector3(0,0,DATA.ZONE_SPACING*index)

func sync_table_items(models: Array,items: Array,top: Vector3,visible: bool) -> void:
 var raw_stack: bool=not items.is_empty() and items[0].kind=="raw"
 var count := mini(6 if raw_stack else 4,items.size()) if visible else 0
 while models.size()<count:
  var i := models.size()
  var pos := top+Vector3((float(i%3)-1)*0.55,0.04+float(i/6)*0.13,float((i/3)%2)*0.38-0.19)
  models.append(make_dish(self,pos,0))
  models[-1].visible=false
 for i in range(models.size()):
  var model: Node3D=models[i]
  if i<count and not model.visible:model.set_meta("arrival",clock)
  model.visible=i<count
  if model.visible:
   var item: Dictionary=items[i]
   show_meal(model,0 if item.kind=="raw" else int(item.recipe))
   if item.kind=="raw" and model.get_child_count()>0:
    var group: Node3D=model.get_child(0)
    if group.get_child_count()>0:apply_fish_species(group.get_child(0),int(item.get("species",0)))
   var settle := clampf((clock-float(model.get_meta("arrival",clock)))/0.22,0,1)
   model.scale=Vector3.ONE*(clampf(0.4+float(item.size)*0.10,0.4,0.7) if item.kind=="raw" else 0.58)*(0.9+0.1*settle)
   model.rotation.y=PI if item.kind=="raw" and i%2==1 else 0
   model.position=top+Vector3((float(i%3)-1)*0.55,0.04+float(i/6)*0.13+sin(settle*PI)*0.05,float((i/3)%2)*0.38-0.19)

func update_tutorial(delta: float) -> void:
 tutorial_marker.visible=false
 if start_pending or int(profile.tutorial_step)>=TUTORIAL_STEPS:return
 tutorial_walk+=hero_velocity.length()*delta
 var state: Dictionary=profile.zones[0]
 var kitchen: Dictionary=profile.zones[1]
 var step := int(profile.tutorial_step)
 var improved: bool=not profile.workers.is_empty()
 for value in profile.hero.values():
  if int(value)>1:improved=true
 var completed := false
 match step:
  0: completed=tutorial_walk>0.8 or first_kind(profile.bag,"raw")>=0
  1: completed=first_kind(profile.bag,"raw")>=0 or not state.counter.is_empty() or state.cash>0
  2: completed=flat_distance(hero.position,point(0,"sale"))<0.95 or not state.counter.is_empty() or state.cash>0
  3: completed=state.cash>0 or money>0
  4: completed=money>0 or improved
  5: completed=shop_open or improved or kitchen.unlocked
  6: completed=improved or kitchen.unlocked
  7: completed=kitchen.unlocked
  8: completed=not kitchen.input.is_empty() or kitchen.cooking!=null or not kitchen.output.is_empty() or kitchen.cash>0
  9: completed=kitchen.running
  10: completed=first_kind(profile.bag,"food")>=0 or not kitchen.counter.is_empty() or kitchen.cash>0
  11: completed=kitchen.cash>0
 if completed:profile.tutorial_step=mini(TUTORIAL_STEPS,step+1)
 step=int(profile.tutorial_step)
 if step<1 or step>=TUTORIAL_STEPS or shop_open:return
 var guide_zone := 1 if step>=8 else 0
 if selected_zone!=guide_zone:return
 var target := Vector3.ZERO
 if step==1:
  var nearest := INF
  for entry in fish_live:
   if entry.zone==0 and entry.tier==0 and entry.respawn<=0:
    var distance := flat_distance(hero.position,entry.node.position)
    if distance<nearest:
     nearest=distance
     target=entry.node.position+Vector3(0,float(DATA.FISH[0].height)*0.5+0.65,0)
  if nearest==INF:return
 elif step==7:
  target=Vector3(5,1.5,DATA.ZONE_SPACING-11)
 else:
  var kind: String={2:"sale",3:"sale",4:"coins",5:"shop",6:"shop",8:"drop",9:"cook",10:"output",11:"sale"}[step]
  target=point(guide_zone,kind)+Vector3(0,1.5,0)
 tutorial_marker.position=target+Vector3(0,sin(clock*3)*0.08,0)
 tutorial_marker.visible=true

func tutorial_lines() -> Array:
 var lines := [
  ["Проведи пальцем, щоб рухатися.","На комп’ютері — WASD або стрілки."],
  ["Підійди до малої крижини та зачекай.","Рідкісна риба дорожча. Тріщини — знос льоду."],
  ["Стань на позначку продажу біля столу.","Риба продається прямо з рюкзака."],
  ["Залишайся на позначці й дочекайся покупця.","Монети з’являться праворуч від прилавка."],
  ["Підійди до позначки монет, щоб забрати їх.","Виручка потрапить у твій баланс."],
  ["Стань на позначку магазину.","У ньому — помічники, прокачка й нові зони."],
  ["Купи покращення або першого помічника.","Бракує монет? Добувай і продавай ще рибу."],
  ["Відкрий другу зону за 160 монет.","У магазині: «Зони та кухні» → друга зона."],
  ["У другій зоні принеси сиру рибу до кухні.","Стань на позначку біля вхідного столу."],
  ["Стань на позначку запуску біля кухні.","Далі вона сама готуватиме рибу зі столу."],
  ["Забери готову страву на позначці видачі.","Кур’єр може переносити страви замість тебе."],
  ["Продай страву біля прилавка другої зони.","Вона дорожча за сиру рибу. Збери монети!"]]
 return lines[clampi(int(profile.tutorial_step),0,TUTORIAL_STEPS-1)]

func plant_ground_details(index: int) -> void:
 if not render_cache.has("winter_grass_mesh"):
  var tool := SurfaceTool.new()
  tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  for i in range(7):
   var a := float(i)*2.4
   var base := Vector3(sin(a)*0.09,0,cos(a)*0.09)
   var side := Vector3(cos(a)*0.035,0,sin(a)*0.035)
   var height := 0.18+float(i%3)*0.07
   tool.set_color([Color("8b996c"),Color("c1b78c"),Color("657d68")][i%3])
   for v in [base-side,base+side,base+Vector3(sin(a)*0.04,height,cos(a)*0.04)]:
    tool.add_vertex(v)
  tool.generate_normals()
  render_cache.winter_grass_mesh=tool.commit()
 var field := MultiMeshInstance3D.new()
 var multi := MultiMesh.new()
 multi.transform_format=MultiMesh.TRANSFORM_3D
 multi.mesh=render_cache.winter_grass_mesh
 multi.instance_count=72
 field.multimesh=multi
 var shader := ShaderMaterial.new()
 shader.shader=load("res://Grass.gdshader")
 field.material_override=shader
 add_child(field)
 var rng := RandomNumberGenerator.new()
 rng.seed=842+index*91
 for i in range(72):
  var z := rng.randf_range(-5.8,12.3)
  var x := rng.randf_range(9.5,10.15) if i%2==0 else rng.randf_range(-0.05,0.35) if z<3.5 else rng.randf_range(-2.7,-2.3)
  multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(0.7,1.4)),Vector3(x,0.21,z+index*DATA.ZONE_SPACING)))

func read_sound_mix(value: Variant) -> Dictionary:
 var result := {"effects":1.0,"music":0.32,"ambient":0.70}
 if value is Dictionary:
  for key in result:result[key]=clampf(float(value.get(key,result[key])),0,1)
 return result

func apply_sound_mix() -> void:
 if not is_instance_valid(audio):return
 for group in sound_mix:audio.set_mix(group,float(sound_mix[group]))

func set_sound_level(group: String,value: float) -> void:
 if not sound_mix.has(group):return
 sound_mix[group]=clampf(value,0,1)
 apply_sound_mix()
 if not start_pending:save_game()

func set_audio_volume(value: float) -> void:
 audio_volume=clampf(value,0,1)
 audio.set_volume(audio_volume)
 if not start_pending:save_game()

func toggle_audio() -> void:
 sounds_enabled=not sounds_enabled
 audio.set_enabled(sounds_enabled)
 if not start_pending:save_game()

func recover_removed_cargo() -> void:
 for i in range(profile.recovered_cargo.size()-1,-1,-1):
  var cargo: Dictionary=profile.recovered_cargo[i]
  var z := clampi(int(cargo.zone),0,last_unlocked())
  var item: Dictionary=cargo.item
  var target: Array=profile.zones[z].counter if item.kind=="food" or z==0 else profile.zones[z].input
  if target.size()<DATA.MAX_STOCK:
   target.append(item)
   profile.recovered_cargo.remove_at(i)

func ensure_zone(index: int) -> void:
 if index<0 or index>=DATA.ZONES.size() or zone_live[index].floor!=null:return
 var previous := get_children()
 var state: Dictionary=zone_live[index]
 build_island(index)
 for key in ["sale_clock","gate_hold","business_open"]:zone_live[index][key]=state.get(key,0.0 if key!="business_open" else false)
 var region := Node3D.new()
 region.name="Region_%02d" % index
 add_child(region)
 var ice_nodes: Array=[]
 for entry in fish_live:ice_nodes.append(entry.node)
 for child in get_children():
  if child!=region and not previous.has(child) and child is Node3D and not ice_nodes.has(child):child.reparent(region)
 region_roots[index]=region
 batch_scenery(region,index)
 var details := region.get_node_or_null("GroundDetails_%02d" % index)
 if details!=null:
  batch_scenery(details,index)
  details.visible=not weak_device

func unload_zone(index: int) -> void:
 if not region_roots.has(index):return
 var state: Dictionary=zone_live[index]
 for key in ["counter_models","output_models","raw_models","catch_models"]:
  for model in state[key]:
   if is_instance_valid(model):model.queue_free()
 pads=pads.filter(func(pad):return int(pad.zone)!=index)
 furniture=furniture.filter(func(obstacle):return int(round(obstacle.pos.z/DATA.ZONE_SPACING))!=index)
 region_roots[index].queue_free()
 region_roots.erase(index)
 kitchen_steam[index]=null
 zone_live[index]={"floor":null,"sale_clock":state.sale_clock,"gate_hold":state.gate_hold,"business_open":state.business_open}

func stream_regions() -> void:
 get_node("River").position.z=hero.position.z
 if streamed_zone==selected_zone:return
 streamed_zone=selected_zone
 for index in region_roots.keys():
  if absi(int(index)-selected_zone)>1:unload_zone(int(index))
 for i in range(maxi(0,selected_zone-1),mini(DATA.ZONES.size(),selected_zone+2)):ensure_zone(i)
 refresh_unlocks()

func build_new_kitchen(index: int,base: Vector3) -> void:
 var tone := Color(DATA.ZONES[index].color)
 var style := (index-5)%5
 var station := bevel(self,base+Vector3(0,0.75,0),Vector3(1.9,1.35,1.5),tone.darkened(0.25))
 station.material_override=surface("wood",Vector3(1.1,1,1.1)) if style==0 else material(tone.darkened(0.25))
 if style==0:
  box(self,base+Vector3(0,1.48,0),Vector3(2.2,0.16,1.6),tone.lightened(0.3))
  for x in [-0.7,0.7]:
   box(self,base+Vector3(x,2.0,-0.6),Vector3(0.09,1.1,0.09),tone)
  box(self,base+Vector3(0,2.55,-0.6),Vector3(2,0.12,0.35),tone)
 elif style==1:
  rounded(self,base+Vector3(0,1.6,0),Vector3(1.9,1.4,1.5),tone.lightened(0.15))
  bevel(self,base+Vector3(0,1.3,0.78),Vector3(1,0.6,0.08),Color("342d33"))
 elif style==2:
  for x in [-0.5,0.5]:
   rounded(self,base+Vector3(x,1.55,0),Vector3(0.8,0.22,1.1),Color("353a41"))
   for n in range(6):box(self,base+Vector3(x,1.68,-0.4+n*0.16),Vector3(0.7,0.03,0.03),tone.lightened(0.3))
 elif style==3:
  rounded(self,base+Vector3(0,1.65,0),Vector3(1.4,0.55,1.2),tone.lightened(0.3))
  rounded(self,base+Vector3(0,1.98,0),Vector3(1.3,0.1,1.1),Color("dfb765"))
 else:
  for x in [-0.6,0.6]:
   box(self,base+Vector3(x,2,-0.55),Vector3(0.14,1.6,0.14),tone)
  bevel(self,base+Vector3(0,2.8,0),Vector3(2.2,0.3,1.7),tone.lightened(0.25))
  rounded(self,base+Vector3(0,1.6,0),Vector3(1.25,0.35,1.1),Color("d4a762"))
 # Every region has its own backsplash, inlay pattern and plated dish.
 for n in range(3+index%4):
  box(self,base+Vector3(-0.7+n*1.4/(2+index%4),0.85,0.78),Vector3(0.07,0.6,0.035),tone.lightened(0.45))
 var plate := make_dish(self,base+Vector3(0,1.76,0.15),index)
 plate.scale=Vector3.ONE*0.75

func build_new_meal(parent: Node3D,index: int) -> void:
 var tone := Color(DATA.ZONES[index].color)
 rounded(parent,Vector3.ZERO,Vector3(0.9,0.08,0.7),Color("e8e5d5"))
 var style := (index-5)%5
 for n in range(2+index%3):
  var angle := float(n)*TAU/float(2+index%3)
  var pos := Vector3(sin(angle)*0.2,0.14,cos(angle)*0.16)
  if style==0:
   rounded(parent,pos,Vector3(0.22,0.22,0.22),Color("3f6353"))
   rounded(parent,pos+Vector3(0,0.12,0),Vector3(0.16,0.025,0.16),Color("f2dfbb"))
   ball(parent,pos+Vector3(0,0.15,0),0.045,Color("e68b69"))
  elif style==1:
   rounded(parent,pos,Vector3(0.3,0.12,0.2),Color("eee0b9"))
  elif style==2:
   rounded(parent,pos,Vector3(0.24,0.14,0.27),Color("c88648"))
   box(parent,pos+Vector3(0,0.08,0),Vector3(0.025,0.01,0.19),Color("734b32"))
  elif style==3:
   rounded(parent,pos,Vector3(0.27,0.065,0.17),Color("e6a38a"))
   box(parent,pos+Vector3(0,0.04,0),Vector3(0.2,0.01,0.025),Color("f4d1b3"))
  else:ball(parent,pos,0.13,Color("d9b57b"))
 ball(parent,Vector3(0.3,0.1,0.22),0.07,tone)
 ball(parent,Vector3(-0.3,0.1,0.22),0.06,Color("679657"))

func build_landmark(index: int,offset: Vector3) -> void:
 if index<5:
  build_early_landmark(index,offset+Vector3(1,0,-4.7))
  return
 var base := offset+Vector3(1,0,-4.7)
 var tone := Color(DATA.ZONES[index].color)
 match index:
  5: # Bamboo grove
   for n in range(5):
    var at := base+Vector3(sin(n*2.4)*0.65,0,cos(n*2.4)*0.5)
    for k in range(6):rounded(self,at+Vector3(0,0.3+k*0.45,0),Vector3(0.15,0.48,0.15),tone)
    rounded(self,at+Vector3(0,2.6,0),Vector3(1,0.12,0.45),Color("538761"))
  6: # Lighthouse
   rounded(self,base+Vector3(0,1.3,0),Vector3(1,2.6,1),Color("ded5b7"))
   rounded(self,base+Vector3(0,2.8,0),Vector3(1.4,0.2,1.4),tone)
   ball(self,base+Vector3(0,3.1,0),0.3,Color("f4d98a"))
  7: # Amber tree
   box(self,base+Vector3(0,1,0),Vector3(0.3,2,0.3),Color("715443"))
   for n in range(5):ball(self,base+Vector3(sin(n*2)*0.65,2+cos(n)*0.4,cos(n*2)*0.5),0.6,Color("cb9b53"))
  8,18: # Crystal fan
   for n in range(5):
    var crystal := bevel(self,base+Vector3((n-2)*0.38,1.1+0.2*(n%2),0),Vector3(0.35,1.9+0.2*n,0.4),tone.lightened(0.15))
    crystal.rotation.z=(n-2)*-0.14
  9: # Copper pipes
   for n in range(4):
    rounded(self,base+Vector3((n-1.5)*0.4,1+n*.2,0),Vector3(0.25,2+n*.4,0.25),Color("b27c51"))
    ball(self,base+Vector3((n-1.5)*0.4,2+n*.4,0),0.18,Color("d2a36c"))
  10: # Marsh reeds and pool
   rounded(self,base+Vector3(0,0.23,0),Vector3(2,0.12,1.5),Color("5e9792"))
   for n in range(9):
    var at := base+Vector3(sin(n*2.4)*0.7,1,cos(n*2.4)*0.5)
    box(self,at,Vector3(0.04,1.5,0.04),tone)
    rounded(self,at+Vector3(0,0.8,0),Vector3(0.13,0.3,0.13),Color("a78959"))
  11: # Coral
   for n in range(5):
    var stem := rounded(self,base+Vector3((n-2)*0.32,0.9,0),Vector3(0.2,1.5,0.2),Color("d89c8a"))
    stem.rotation.z=(n-2)*0.25
    ball(self,base+Vector3((n-2)*0.4,1.6,0),0.26,Color("e6b3a0"))
  12: # Palm
   rounded(self,base+Vector3(0,1.3,0),Vector3(0.3,2.6,0.3),Color("a68a5d"))
   for n in range(6):
    var leaf := rounded(self,base+Vector3(sin(n)*0.5,2.6,cos(n)*0.5),Vector3(0.4,0.12,1.7),Color("689468"))
    leaf.rotation.y=n
  13: # Battlements
   bevel(self,base+Vector3(0,1,0),Vector3(1.8,1.8,0.7),tone)
   for n in range(3):box(self,base+Vector3((n-1)*0.65,2,0),Vector3(0.4,0.5,0.7),tone.lightened(0.2))
  14: # Lotus pool
   rounded(self,base+Vector3(0,0.25,0),Vector3(2.2,0.2,1.8),Color("70a4a1"))
   for n in range(7):
    var petal := rounded(self,base+Vector3(sin(n)*0.35,0.55,cos(n)*0.35),Vector3(0.35,0.15,0.75),Color("d9afc3"))
    petal.rotation.y=n
   ball(self,base+Vector3(0,0.6,0),0.18,Color("ddca7d"))
  15: # Lava pillars
   for n in range(4):
    bevel(self,base+Vector3((n-1.5)*0.4,0.8+n*.1,0),Vector3(0.34,1.5+n*.2,0.5),Color("4c505b"))
    box(self,base+Vector3((n-1.5)*0.4,0.8+n*.1,0.26),Vector3(0.04,1.2,0.02),Color("e99a55"))
  16: # Silver sail
   box(self,base+Vector3(0,1.5,0),Vector3(0.08,3,0.08),Color("8f9fa8"))
   var sail := bevel(self,base+Vector3(0.5,1.7,0),Vector3(1,1.6,0.08),Color("d7e0df"))
   sail.rotation.z=-0.2
  17: # Observatory
   rounded(self,base+Vector3(0,0.8,0),Vector3(1.7,1.4,1.7),tone)
   ball(self,base+Vector3(0,1.6,0),0.85,Color("a9bdd2"))
   var telescope := rounded(self,base+Vector3(0.4,2.1,0),Vector3(0.3,1.3,0.3),Color("d1bd8e"))
   telescope.rotation.z=-0.7
  19: # Crown gate
   for x in [-0.7,0.7]:box(self,base+Vector3(x,1.3,0),Vector3(0.25,2.6,0.4),tone)
   bevel(self,base+Vector3(0,2.6,0),Vector3(1.9,0.35,0.6),Color("d6bb6c"))
   for n in range(3):ball(self,base+Vector3((n-1)*0.5,3.0,0),0.16,Color("f0d98c"))
 furniture.append({"pos":base,"half":Vector2(1.15,0.85)})

func set_paused(value: bool) -> void:
 paused=value
 stick=Vector2.ZERO
 mouse_drag=false
 touch_id=-1
 hero_velocity=Vector3.ZERO

func set_economy_graphics(value: bool) -> void:
 economy_graphics=value
 snowfall.amount=12 if weak_device else 40 if value else 90
 get_viewport().msaa_3d=Viewport.MSAA_DISABLED if weak_device else Viewport.MSAA_2X if value else Viewport.MSAA_4X
 get_viewport().scaling_3d_scale=1.0
 Engine.max_fps=30 if weak_device else 60
 for cached in render_cache.values():
  if cached is Material and cached.has_meta("outlined"):cached.next_pass=null if weak_device else detail_shader("outline","res://ToonOutline.gdshader")
 for child in get_children():
  if child is DirectionalLight3D:child.shadow_enabled=not value and not weak_device
 var settings := ConfigFile.new()
 settings.load("user://settings.cfg")
 settings.set_value("graphics","economy",value)
 settings.set_value("graphics","weak_device",weak_device)
 settings.save("user://settings.cfg")

func return_to_title() -> void:
 save_game()
 get_tree().reload_current_scene()

func read_progress() -> Dictionary:
 for path in ["user://progress.json","user://progress.pending.json","user://progress.backup.json"]:
  if not FileAccess.file_exists(path):continue
  var parser := JSON.new()
  if parser.parse(FileAccess.get_file_as_string(path))!=OK:continue
  var result=parser.data
  if result is Dictionary and ((result.get("zones",null) is Array and not result.zones.is_empty()) or result.has("money")):
   return result
 return {}

# Compact, shared-mesh cartoon character: 24 visible pieces instead of tiny stitches.
func person(pos: Vector3,color: Color,skin: String = "",outfit: Dictionary = {}) -> Node3D:
 var actor := Node3D.new()
 add_child(actor)
 actor.position=pos
 var coat := CLOTHES.item(str(outfit.get("coat","coat_default")))
 var hat := CLOTHES.item(str(outfit.get("hat","hat_default")))
 var boots := CLOTHES.item(str(outfit.get("boots","boots_default")))
 if not outfit.is_empty():color=Color(coat.color)
 var coat_trim := Color(coat.trim) if not outfit.is_empty() else Color("fff0ce")
 var hat_color := Color(hat.color) if not outfit.is_empty() else color
 var hat_trim := Color(hat.trim) if not outfit.is_empty() else Color("fff0ce")
 var boot_color := Color(boots.color) if not outfit.is_empty() else Color("43505a")
 var fabric_key := "fabric_"+skin+color.to_html()
 if not render_cache.has(fabric_key):
  var fabric_material: Material=(surface(skin) if not skin.is_empty() else material(color)).duplicate()
  fabric_material.albedo_texture=cloth_texture()
  fabric_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  fabric_material.set_meta("outlined",true)
  fabric_material.next_pass=null if weak_device else detail_shader("outline","res://ToonOutline.gdshader")
  render_cache[fabric_key]=fabric_material
 var fabric: Material=render_cache[fabric_key]
 rounded(actor,Vector3(0,0.7,0),Vector3(0.72,0.94,0.57),color).material_override=fabric
 rounded(actor,Vector3(0,1.03,-0.03),Vector3(0.67,0.17,0.55),coat_trim)
 bevel(actor,Vector3(0,0.72,0.42),Vector3(0.62,0.68,0.4),Color("ba8654"))
 box(actor,Vector3(0,0.75,0.64),Vector3(0.15,0.14,0.04),Color("efc86f"))
 for side in [-1.0,1.0]:
  rounded(actor,Vector3(side*0.36,0.81,0),Vector3(0.26,0.32,0.3),color).material_override=fabric
  rounded(actor,Vector3(side*0.36,0.55,0),Vector3(0.23,0.3,0.27),color).material_override=fabric
  ball(actor,Vector3(side*0.36,0.43,-0.02),0.13,Color("79533d"))
  rounded(actor,Vector3(side*0.17,0.32,0),Vector3(0.25,0.24,0.29),Color("3e6176"))
  rounded(actor,Vector3(side*0.17,0.12,-0.05),Vector3(0.28,0.25,0.38),boot_color)
 ball(actor,Vector3(0,1.29,-0.02),0.29,Color("ffd6aa"))
 rounded(actor,Vector3(0,1.48,0),Vector3(0.63,0.36,0.59),hat_color).material_override=clothing_material(hat_color)
 rounded(actor,Vector3(0,1.39,-0.02),Vector3(0.66,0.12,0.6),hat_trim)
 for side in [-1.0,1.0]:
  ball(actor,Vector3(side*0.105,1.29,-0.265),0.038,Color("243e4d"))
  ball(actor,Vector3(side*0.16,1.20,-0.23),0.055,Color("f4ab91"))
 ball(actor,Vector3(0,1.23,-0.3),0.06,Color("edb489"))
 box(actor,Vector3(0,0.75,-0.29),Vector3(0.035,0.48,0.02),coat_trim)
 # Large readable details; no tiny stitched geometry.
 rounded(actor,Vector3(0,0.29,0.01),Vector3(0.74,0.12,0.59),coat_trim)
 rounded(actor,Vector3(-0.18,0.87,-0.31),Vector3(0.16,0.31,0.06),coat_trim)
 bevel(actor,Vector3(0,0.61,0.65),Vector3(0.4,0.25,0.12),Color("99643e"))
 for side in [-1.0,1.0]:
  box(actor,Vector3(side*0.22,0.76,-0.3),Vector3(0.06,0.47,0.035),Color("805432"))
  rounded(actor,Vector3(side*0.17,0.24,0),Vector3(0.28,0.08,0.31),Color("dfcba9"))
  box(actor,Vector3(side*0.105,1.36,-0.26),Vector3(0.085,0.025,0.035),Color("654e3c"))
 for side in [-1.0,1.0]:
  bevel(actor,Vector3(side*0.18,0.64,-0.30),Vector3(0.20,0.18,0.045),color.darkened(0.18))
  box(actor,Vector3(side*0.18,0.73,-0.33),Vector3(0.22,0.035,0.025),Color("e1c89b"))
  rounded(actor,Vector3(side*0.36,0.46,0),Vector3(0.25,0.08,0.28),Color("ead8b5"))
  bevel(actor,Vector3(side*0.17,0.035,-0.08),Vector3(0.29,0.05,0.39),Color("293e48"))
  box(actor,Vector3(side*0.21,0.80,0.66),Vector3(0.06,0.45,0.04),Color("765337"))
 for y in [0.6,0.8,0.96]:
  ball(actor,Vector3(0,y,-0.325),0.025,Color("ebc879"))
 if outfit.is_empty() or int(hat.shape) in [0,1]:
  ball(actor,Vector3(0,1.69,0),0.14 if not outfit.is_empty() and int(hat.shape)==1 else 0.1,hat_trim)
 if not outfit.is_empty():
  if int(hat.shape)==2:
   for side in [-1.0,1.0]:
    rounded(actor,Vector3(side*0.29,1.29,0.02),Vector3(0.15,0.3,0.27),hat_trim)
  elif int(hat.shape)==3:
   bevel(actor,Vector3(0,1.39,-0.33),Vector3(0.61,0.055,0.3),hat_color)
   ball(actor,Vector3(0,1.5,-0.3),0.055,hat_trim)
  if int(coat.shape)==1:
   rounded(actor,Vector3(0,1.0,0.2),Vector3(0.6,0.2,0.34),coat_trim)
  elif int(coat.shape)==2:
   bevel(actor,Vector3(0,0.48,-0.32),Vector3(0.64,0.09,0.04),Color("705039"))
  elif int(coat.shape)==3:
   for x in [-0.1,0.1]:
    for y in [0.55,0.72,0.9]:ball(actor,Vector3(x,y,-0.32),0.028,coat_trim)
  for side in [-1.0,1.0]:
   if int(boots.shape)==2:
    rounded(actor,Vector3(side*0.17,0.24,-0.015),Vector3(0.285,0.18,0.32),boot_color)
   for y in [0.1,0.15,0.2]:
    box(actor,Vector3(side*0.17,y,-0.245),Vector3(0.16,0.018,0.025),Color(boots.trim))
 rig_person(actor)
 batch_character_bones(actor)
 return actor

func apply_fish_species(fish: Node3D,species: int) -> void:
 species=clampi(species,0,DATA.SPECIES.size()-1)
 if int(fish.get_meta("species",-1))==species:return
 fish.set_meta("species",species)
 var body := fish.get_node_or_null("FishBody") as MeshInstance3D
 if body==null:return
 var key := "fish_species_%d" % species
 if not render_cache.has(key):
  var skin := ShaderMaterial.new()
  skin.shader=load("res://FishSurface.gdshader")
  skin.set_meta("outlined",true)
  skin.next_pass=null if weak_device else detail_shader("outline","res://ToonOutline.gdshader")
  skin.set_shader_parameter("body_color",Color(DATA.SPECIES[species].color))
  skin.set_shader_parameter("markings",1.0 if species in [0,2,3] else 0.0)
  render_cache[key]=skin
 body.material_override=render_cache[key]
 body.scale=Vector3(1.15,0.78,0.8) if DATA.SPECIES[species].shape==2 else Vector3(0.84,1.16,1.1) if DATA.SPECIES[species].shape==1 else Vector3.ONE

func _input(event: InputEvent) -> void:
 if paused:return
 if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed and event.position.y<125:return
 super._input(event)

func _unhandled_input(event: InputEvent) -> void:
 if paused:return
 if event is InputEventScreenTouch and event.pressed and event.position.y<125:return
 super._unhandled_input(event)

func segment_blocked(a: Vector3,b: Vector3,obstacles: Array) -> bool:
 var from := Vector2(a.x,a.z)
 var direction := Vector2(b.x-a.x,b.z-a.z)
 for obstacle in obstacles:
  var center := Vector2(obstacle.pos.x,obstacle.pos.z)
  var half: Vector2=obstacle.half+Vector2(0.02,0.02)
  var lower := center-half
  var upper := center+half
  var low := 0.0
  var high := 1.0
  for axis in range(2):
   if absf(direction[axis])<0.0001:
    if from[axis]<=lower[axis] or from[axis]>=upper[axis]:low=2.0;break
   else:
    var t1 := (lower[axis]-from[axis])/direction[axis]
    var t2 := (upper[axis]-from[axis])/direction[axis]
    low=maxf(low,minf(t1,t2))
    high=minf(high,maxf(t1,t2))
  if low<high and low<0.999 and high>0.001:return true
 return false

func navigation_path(start: Vector3,finish: Vector3) -> Array:
 var obstacles: Array=[]
 for obstacle in furniture:
  if absf(obstacle.pos.z-start.z)>27:continue
  if obstacle.has("root") and not obstacle.root.visible:continue
  # A spawning NPC can be inside furniture; collision resolution moves it out.
  var delta := Vector2(start.x-obstacle.pos.x,start.z-obstacle.pos.z).abs()
  if delta.x<obstacle.half.x and delta.y<obstacle.half.y:continue
  obstacles.append(obstacle)
 if not segment_blocked(start,finish,obstacles):return [finish]
 var nodes: Array=[start,finish]
 for obstacle in obstacles:
  var half: Vector2=obstacle.half+Vector2(0.14,0.14)
  for x in [-1,1]:
   for z in [-1,1]:nodes.append(obstacle.pos+Vector3(x*half.x,0,z*half.y))
 var distances: Array=[]
 var previous: Array=[]
 var visited: Array=[]
 for i in range(nodes.size()):distances.append(INF);previous.append(-1);visited.append(false)
 distances[0]=0.0
 for iteration in range(nodes.size()):
  var best := -1
  for i in range(nodes.size()):
   if not visited[i] and (best<0 or distances[i]<distances[best]):best=i
  if best<0 or distances[best]==INF:break
  if best==1:break
  visited[best]=true
  for next in range(nodes.size()):
   if visited[next] or next==best:continue
   var distance: float=distances[best]+flat_distance(nodes[best],nodes[next])
   if distance<distances[next] and not segment_blocked(nodes[best],nodes[next],obstacles):
    distances[next]=distance
    previous[next]=best
 if previous[1]<0:return [finish]
 var result: Array=[]
 var current := 1
 while current>0:
  result.push_front(nodes[current])
  current=previous[current]
 return result

func batch_scenery(region: Node3D,index: int) -> void:
 var excluded: Array=[]
 var detail_root := region.get_node_or_null("GroundDetails_%02d" % index)
 if detail_root!=null:excluded.append(detail_root)
 for pad in pads:
  if int(pad.zone)==index:excluded.append(pad.root)
 var data: Dictionary=zone_live[index]
 excluded.append(data.catch_table)
 for coin in data.cash_models:excluded.append(coin)
 var meshes: Array=[]
 collect_static_meshes(region,excluded,meshes)
 var groups: Dictionary={}
 var inverse := region.global_transform.affine_inverse()
 for source in meshes:
  var mat: Material=source.material_override
  if mat==null:continue
  if mat is ShaderMaterial and mat.shader.resource_path.ends_with("Wind.gdshader"):continue
  var key := mat.get_instance_id()
  if not groups.has(key):
   var builder := SurfaceTool.new()
   builder.begin(Mesh.PRIMITIVE_TRIANGLES)
   groups[key]={"builder":builder,"material":mat,"sources":[]}
  groups[key].builder.append_from(source.mesh,0,inverse*source.global_transform)
  groups[key].sources.append(source)
 for group in groups.values():
  if group.sources.size()<2:continue
  var combined := MeshInstance3D.new()
  combined.name="StaticBatch"
  combined.mesh=group.builder.commit()
  combined.material_override=group.material
  region.add_child(combined)
  for source in group.sources:
   source.get_parent().remove_child(source)
   source.queue_free()

func collect_static_meshes(node: Node,excluded: Array,result: Array) -> void:
 if excluded.has(node):return
 if node is MeshInstance3D:
  if node.visible and node.mesh!=null:result.append(node)
 for child in node.get_children():collect_static_meshes(child,excluded,result)

func fish_species_for(zone: int,slot: int) -> int:
 var generation := int(profile.ice_cycles.get("%d:%d" % [zone,slot],0))
 var rng := RandomNumberGenerator.new()
 rng.seed=(zone+1)*73856093+(slot+1)*19349663+generation*83492791
 return DATA.roll_species(rng.randf())


func detail_shader(key: String,path: String) -> ShaderMaterial:
 if not render_cache.has(key):
  var shader_material := ShaderMaterial.new()
  shader_material.shader=load(path)
  render_cache[key]=shader_material
 return render_cache[key]

# Merge rigid pieces only within each bone: articulation remains independent.
func batch_character_bones(node: Node3D) -> void:
 var groups: Dictionary={}
 for child in node.get_children():
  if child is MeshInstance3D and child.material_override!=null:
   var key: int=child.material_override.get_instance_id()
   if not groups.has(key):groups[key]=[]
   groups[key].append(child)
  elif child is Node3D:batch_character_bones(child)
 for pieces in groups.values():
  if pieces.size()<2:continue
  var builder := SurfaceTool.new()
  builder.begin(Mesh.PRIMITIVE_TRIANGLES)
  for piece in pieces:builder.append_from(piece.mesh,0,piece.transform)
  var combined := MeshInstance3D.new()
  combined.mesh=builder.commit()
  combined.material_override=pieces[0].material_override
  node.add_child(combined)
  for piece in pieces:
   node.remove_child(piece)
   piece.queue_free()

func set_weak_device(value: bool) -> void:
 weak_device=value
 if value:
  while ice_effects.size()>24:
   var oldest: Dictionary=ice_effects.pop_front()
   oldest.node.queue_free()
 for index in region_roots:
  var details: Node3D=region_roots[index].get_node_or_null("GroundDetails_%02d" % index)
  if details!=null:details.visible=not value
 set_economy_graphics(economy_graphics)
 for entry in fish_live:entry.node.material_override.set_shader_parameter("low_detail",value)
 update_displays()

func build_border_details(index: int,offset: Vector3) -> void:
 var theme := Color(DATA.ZONES[index].color)
 # Perimeter-only decorations keep all interaction pads and routes clear.
 for n in range(3):
  var at := offset+Vector3(9.5,0,-4+n*5.0)
  var crate := bevel(self,at+Vector3(0,0.35,0),Vector3(0.75,0.7,0.7),Color("b77e49"))
  crate.material_override=detail_shader("painted_wood","res://PaintedWood.gdshader")
  for z in [-0.36,0.36]:
   for y in [0.12,0.58]:
    box(self,at+Vector3(0,y,z),Vector3(0.81,0.08,0.045),Color("825735"))
  box(self,at+Vector3(0,0.72,0),Vector3(0.8,0.06,0.72),Color("eaf1e8"))
  bevel(self,at+Vector3(-0.65,0.14,0.1),Vector3(0.4,0.28,0.55),theme.lightened(0.2))
 for n in range(2):
  var at := offset+Vector3(10.1,0,-6.2+n*18.2)
  box(self,at+Vector3(0,0.8,0),Vector3(0.10,1.6,0.10),Color("805735"))
  box(self,at+Vector3(-0.16,1.57,0),Vector3(0.42,0.08,0.10),Color("805735"))
  bevel(self,at+Vector3(-0.3,1.31,0),Vector3(0.25,0.36,0.25),Color("ffe4a0"))
  for y in [1.1,1.52]:
   box(self,at+Vector3(-0.3,y,0),Vector3(0.32,0.07,0.32),Color("465d62"))
  bevel(self,at+Vector3(0.12,0.1,0.2),Vector3(0.55,0.2,0.5),Color("e7f0ed"))

func celebrate_zone(index: int) -> void:
 if start_pending:return
 if is_instance_valid(zone_celebration):
  zone_celebration.queue_free()
 var layer := get_node_or_null("CelebrationLayer") as CanvasLayer
 if layer==null:
  layer=CanvasLayer.new()
  layer.name="CelebrationLayer"
  layer.layer=18
  add_child(layer)
 zone_celebration=Control.new()
 zone_celebration.set_script(load("res://ZoneCelebration.gd"))
 zone_celebration.game=self
 zone_celebration.zone_index=index
 layer.add_child(zone_celebration)

# Small themed dioramas occupy a reserved corner away from working stations.
func build_zone_garden(index: int,offset: Vector3) -> void:
 var base := offset+Vector3(9.25,0,7.55)
 var tone := Color(DATA.ZONES[index].color)
 var root := Node3D.new()
 root.name="ThemeGarden_%02d" % index
 root.set_meta("zone_theme",index)
 add_child(root)
 root.position=base
 bevel(root,Vector3(0,0.24,0),Vector3(1.35,0.18,1.25),tone.darkened(0.22))
 for n in range(5):
  var angle := n*TAU/5
  bevel(root,Vector3(sin(angle)*0.58,0.34,cos(angle)*0.52),Vector3(0.25,0.15,0.25),tone.lightened(0.35))
 match index:
  0: # Tied fishing floats
   for x in [-0.28,0.28]:
    rounded(root,Vector3(x,0.67,0),Vector3(0.27,0.6,0.27),Color("eee9d6"))
    rounded(root,Vector3(x,0.74,0),Vector3(0.29,0.14,0.29),Color("d76e55"))
    box(root,Vector3(x,1.06,0),Vector3(0.045,0.2,0.045),Color("79573f"))
  1: # Firewood rack
   for x in [-0.5,0.5]:box(root,Vector3(x,0.65,0),Vector3(0.08,0.7,0.7),Color("4b6570"))
   for n in range(5):
    rounded(root,Vector3((n%3-1)*0.25,0.45+int(n/3)*0.25,0),Vector3(0.22,0.22,0.7),Color("b78451"))
  2: # Mushrooms beneath fir sapling
   tree_at(base+Vector3(0.15,0,0.15),0.35)
   for x in [-0.35,0.15]:
    box(root,Vector3(x,0.48,-0.3),Vector3(0.07,0.3,0.07),Color("e6d1a4"))
    rounded(root,Vector3(x,0.64,-0.3),Vector3(0.3,0.12,0.28),Color("d8875c"))
  3: # Mineral spring
   rounded(root,Vector3(0,0.35,0),Vector3(1,0.12,0.85),Color("65cbd3"))
   for n in range(3):
    bevel(root,Vector3(-0.35+n*0.3,0.58,0.28),Vector3(0.28,0.45+n*0.12,0.3),Color("9cc3bb"))
  4: # Polar dessert display
   box(root,Vector3(0,0.65,0),Vector3(0.9,0.1,0.7),Color("e6d8b8"))
   box(root,Vector3(0,0.45,0),Vector3(0.15,0.4,0.15),Color("cfaa65"))
   for x in [-0.28,0,0.28]:
    rounded(root,Vector3(x,0.8,0),Vector3(0.2,0.18,0.24),Color("edbfb1"))
    ball(root,Vector3(x,0.92,0),0.06,Color("c35569"))
  5: # Red lantern arch
   for x in [-0.45,0.45]:box(root,Vector3(x,0.9,0),Vector3(0.09,1.2,0.09),Color("5b8062"))
   box(root,Vector3(0,1.48,0),Vector3(1.1,0.1,0.12),Color("72553e"))
   rounded(root,Vector3(0,1.13,0),Vector3(0.42,0.48,0.4),Color("d97962"))
   box(root,Vector3(0,0.82,0),Vector3(0.05,0.2,0.05),Color("e6c67b"))
  6: # Anchor
   box(root,Vector3(0,0.95,0),Vector3(0.12,1.1,0.12),Color("607d86"))
   box(root,Vector3(0,1.12,0),Vector3(0.8,0.1,0.13),Color("607d86"))
   for side in [-1,1]:
    var arm := box(root,Vector3(side*0.23,0.52,0),Vector3(0.55,0.12,0.15),Color("607d86"))
    arm.rotation.z=side*0.55
  7: # Amber gems
   for n in range(4):
    bevel(root,Vector3(sin(n*2)*0.35,0.5+0.09*n,cos(n*2)*0.3),Vector3(0.38,0.35+0.1*n,0.35),Color("edb457"))
  8: # Frozen stalactite arch
   for x in [-0.4,0.4]:bevel(root,Vector3(x,0.9,0),Vector3(0.28,1.2,0.36),Color("9fdfec"))
   bevel(root,Vector3(0,1.4,0),Vector3(1,0.25,0.4),Color("c9f0ec"))
   for x in [-0.2,0.15]:bevel(root,Vector3(x,1.15,0),Vector3(0.09,0.4,0.1),Color("d9f4ed"))
  9: # Anvil and copper ingots
   bevel(root,Vector3(0,0.59,0),Vector3(0.7,0.45,0.45),Color("52636d"))
   bevel(root,Vector3(0,0.86,0),Vector3(1,0.15,0.48),Color("81949b"))
   for n in range(2):bevel(root,Vector3(n*0.28-0.15,0.44,-0.43),Vector3(0.23,0.15,0.24),Color("db9965"))
  10: # Giant marsh mushrooms
   for n in range(3):
    var at := Vector3(sin(n*2.4)*0.3,0.6+n*.15,cos(n*2.4)*0.3)
    box(root,at,Vector3(0.09,0.6,0.09),Color("a3b48a"))
    rounded(root,at+Vector3(0,0.3,0),Vector3(0.5,0.16,0.45),Color("93b9a0"))
  11: # Starfish sculpture
   for n in range(5):
    var ray := bevel(root,Vector3(sin(n*TAU/5)*0.18,0.5,cos(n*TAU/5)*0.18),Vector3(0.2,0.16,0.65),Color("ecaa84"))
    ray.rotation.y=n*TAU/5
   ball(root,Vector3(0,0.58,0),0.15,Color("f7cda1"))
  12: # Desert jars
   for x in [-0.28,0.28]:
    rounded(root,Vector3(x,0.67,0),Vector3(0.42,0.65,0.42),Color("d7a171"))
    rounded(root,Vector3(x,1.02,0),Vector3(0.22,0.09,0.22),Color("85634e"))
  13: # Shield and crossed posts
   bevel(root,Vector3(0,0.94,0),Vector3(0.7,0.85,0.15),Color("839da9"))
   box(root,Vector3(0,0.97,-0.09),Vector3(0.12,0.65,0.03),Color("e4c27b"))
   for side in [-1,1]:
    var post := box(root,Vector3(side*0.25,0.82,0.15),Vector3(0.07,1.3,0.07),Color("a88962"))
    post.rotation.z=side*0.35
  14: # Stone garden lantern
   box(root,Vector3(0,0.61,0),Vector3(0.25,0.55,0.25),Color("adb5a6"))
   bevel(root,Vector3(0,0.96,0),Vector3(0.5,0.35,0.5),Color("f2d497"))
   bevel(root,Vector3(0,1.21,0),Vector3(0.8,0.16,0.7),Color("8eaaa4"))
  15: # Basalt with glowing seams
   for n in range(3):
    var at := Vector3((n-1)*0.3,0.6+0.12*n,0)
    bevel(root,at,Vector3(0.27,0.7+0.24*n,0.4),Color("535b68"))
    box(root,at+Vector3(0,0,-0.21),Vector3(0.055,0.5,0.025),Color("f5b36a"))
  16: # Small sailboat
   bevel(root,Vector3(0,0.5,0),Vector3(1.05,0.28,0.5),Color("b4c6c5"))
   box(root,Vector3(0,1.0,0),Vector3(0.055,1.1,0.055),Color("a5855a"))
   bevel(root,Vector3(0.2,1.16,0),Vector3(0.4,0.65,0.04),Color("f0e4c5"))
  17: # Orrery
   box(root,Vector3(0,0.7,0),Vector3(0.13,0.7,0.13),Color("bc9b61"))
   ball(root,Vector3(0,1.15,0),0.23,Color("f2cc80"))
   for n in range(3):
    var at := Vector3(sin(n*2.1)*0.45,1.1,cos(n*2.1)*0.4)
    ball(root,at,0.1,Color("97b9d8"))
    var bar := box(root,at*Vector3(0.5,0,0.5)+Vector3(0,1.1,0),Vector3(0.04,0.04,0.8),Color("bc9b61"))
    bar.rotation.y=n*2.1
  18: # Aurora obelisk
   bevel(root,Vector3(0,0.95,0),Vector3(0.44,1.4,0.44),Color("bfa6db"))
   for side in [-1,1]:
    var gem := bevel(root,Vector3(side*0.4,0.75,0),Vector3(0.22,0.9,0.25),Color("9ee3d4"))
    gem.rotation.z=side*-0.3
  19: # Royal fish trophy
   box(root,Vector3(0,0.6,0),Vector3(0.16,0.6,0.16),Color("c7a35a"))
   rounded(root,Vector3(0,1.0,0),Vector3(0.85,0.38,0.3),Color("f2cf77"))
   var tail := bevel(root,Vector3(0.53,1.0,0),Vector3(0.3,0.5,0.12),Color("e3b85d"))
   tail.rotation.z=0.25
   ball(root,Vector3(-0.27,1.05,-0.15),0.045,Color("425b66"))
 furniture.append({"pos":base,"half":Vector2(0.73,0.68)})

func build_early_landmark(index: int,base: Vector3) -> void:
 var tone := Color(DATA.ZONES[index].color)
 match index:
  0:
   for x in [-0.65,0.65]:box(self,base+Vector3(x,0.95,0),Vector3(0.12,1.9,0.12),Color("a8784d"))
   box(self,base+Vector3(0,1.8,0),Vector3(1.5,0.12,0.12),Color("a8784d"))
   for n in range(5):box(self,base+Vector3(-0.5+n*.25,1.2,0),Vector3(0.025,1.1,0.025),Color("d2c2a0"))
   for n in range(4):box(self,base+Vector3(0,0.75+n*.25,0),Vector3(1.15,0.025,0.025),Color("d2c2a0"))
  1:
   for n in range(6):bevel(self,base+Vector3(sin(n)*.55,0.35,cos(n)*.55),Vector3(0.35,0.3,0.35),Color("8f9c9c"))
   for n in range(3):
    var log := box(self,base+Vector3(0,0.4+n*.05,0),Vector3(1,0.15,0.15),Color("a5774c"))
    log.rotation.y=n*1.1
   for n in range(3):bevel(self,base+Vector3((n-1)*.15,0.65,0),Vector3(0.18,0.5,0.2),Color("edb16b"))
  2:
   for n in range(5):rounded(self,base+Vector3((n%3-1)*.35,0.35+int(n/3)*.35,0),Vector3(0.3,0.3,1.2),Color("c29560"))
   tree_at(base+Vector3(0.5,0,0.5),0.5)
  3:
   rounded(self,base+Vector3(0,0.3,0),Vector3(1.7,0.18,1.3),Color("77c8ca"))
   for n in range(7):bevel(self,base+Vector3(sin(n)*.8,0.38,cos(n)*.6),Vector3(.38,.3,.35),Color("b6b4a5"))
  4:
   for x in [-0.7,0.7]:box(self,base+Vector3(x,1.1,0),Vector3(0.15,2.2,0.15),Color("bda16a"))
   bevel(self,base+Vector3(0,2.1,0),Vector3(1.7,0.22,0.4),tone.lightened(0.4))
   for n in range(3):ball(self,base+Vector3((n-1)*.4,1.65,0),0.16,Color("ffe3a1"))
 furniture.append({"pos":base,"half":Vector2(1.15,0.85)})

func build_rest_corner(index: int,offset: Vector3) -> void:
 var base := offset+Vector3(1.4,0,-6.35)
 var tone := Color(DATA.ZONES[index].color)
 var timber := detail_shader("painted_wood","res://PaintedWood.gdshader")
 var stone := detail_shader("garden_stone","res://GardenStone.gdshader")
 var root := Node3D.new()
 root.name="RestCorner_%02d" % index
 root.position=base
 add_child(root)
 # A compact bench, placed along the back edge, outside all work routes.
 for z in [-0.22,0.0,0.22]:
  bevel(root,Vector3(0,0.67,z),Vector3(2.4,0.12,0.18),Color.WHITE).material_override=timber
 for y in [0.98,1.22]:
  bevel(root,Vector3(0,y,-0.28),Vector3(2.4,0.16,0.12),Color.WHITE).material_override=timber
 for x in [-0.92,0.92]:
  box(root,Vector3(x,0.42,0),Vector3(0.14,0.5,0.52),Color("53646b"))
  box(root,Vector3(x,0.94,-0.3),Vector3(0.09,0.7,0.09),Color("53646b"))
 # Snow-lined stone path and baskets remain outside the bridge opening.
 for n in range(4):
  bevel(root,Vector3(-0.7+n*0.45,0.22,0.85),Vector3(0.36,0.045,0.38),Color.WHITE).material_override=stone
 for side in [-1,1]:
  bevel(root,Vector3(side*1.05,0.5,0.15),Vector3(0.32,0.22,0.32),tone.lightened(0.3))
 # Cushion and woven picnic cloth use a single shared material per zone.
 var cloth := detail_shader("picnic_cloth_%d" % index,"res://PicnicCloth.gdshader")
 cloth.set_shader_parameter("tint",tone.lightened(0.2))
 bevel(root,Vector3(0.48,0.79,0.02),Vector3(0.65,0.14,0.42),tone).material_override=cloth
 # Flags overhead: static geometry, no extra real-time lights or particles.
 for x in [-1.4,1.4]:
  box(root,Vector3(x,1.35,-0.38),Vector3(0.07,2.3,0.07),Color("a27a50"))
 box(root,Vector3(0,2.44,-0.38),Vector3(2.9,0.035,0.035),Color("8d7358"))
 for n in range(5):
  var flag := bevel(root,Vector3(-1.05+n*0.52,2.22,-0.38),Vector3(0.32,0.38,0.035),tone if n%2==0 else Color("e7c986"))
  flag.rotation.z=(n-2)*0.035
 for x in [-1.3,1.3]:
  bevel(root,Vector3(x,0.27,0.32),Vector3(0.45,0.15,0.4),Color.WHITE).material_override=stone
 furniture.append({"pos":base,"half":Vector2(1.5,0.62)})
 # Small barrel planter beside the bench, well clear of the coin pickup.
 var pot := base+Vector3(6.2,0,0)
 var barrel_material := detail_shader("barrel_staves","res://BarrelStaves.gdshader")
 var barrel := MeshInstance3D.new()
 var cylinder := CylinderMesh.new()
 cylinder.top_radius=0.31;cylinder.bottom_radius=0.26;cylinder.height=0.7;cylinder.radial_segments=12
 barrel.mesh=cylinder;barrel.material_override=barrel_material
 add_child(barrel);barrel.position=pot+Vector3(0,0.55,0)
 for y in [0.3,0.77]:
  var band := MeshInstance3D.new()
  var ring := CylinderMesh.new()
  ring.top_radius=0.315;ring.bottom_radius=0.315;ring.height=0.065;ring.radial_segments=12
  band.mesh=ring;band.material_override=material(Color("607078"))
  add_child(band);band.position=pot+Vector3(0,y,0)
 for n in range(4):
  var stem := pot+Vector3(sin(n*2.2)*0.19,1.0,cos(n*2.2)*0.19)
  box(self,stem,Vector3(0.035,0.45,0.035),Color("6c8d6a"))
  if index in [0,3,8,18]:
   bevel(self,stem+Vector3(0,0.25,0),Vector3(0.12,0.28,0.14),tone.lightened(0.4))
  else:
   ball(self,stem+Vector3(0,0.25,0),0.12,Color("efc987") if index%2==0 else Color("dfa79c"))
 furniture.append({"pos":pot,"half":Vector2(0.4,0.4)})


func cloth_texture() -> ImageTexture:
 if render_cache.has("woven_cloth"):return render_cache.woven_cloth
 var pixels := Image.create(64,64,false,Image.FORMAT_RGB8)
 for y in range(64):
  for x in range(64):
   var thread := 0.96 if (x%4==0 or y%4==0) else 1.0
   if (x+y*3)%16==0:thread=0.93
   pixels.set_pixel(x,y,Color(thread,thread,thread))
 pixels.generate_mipmaps()
 var tex := ImageTexture.create_from_image(pixels)
 render_cache.woven_cloth=tex
 return tex


# The central working footprint is shared for safe routes; coastlines are unique.
# Each hand-shaped east profile has six vertices at fixed north/south stations.
const EAST_COASTS = [
 [Vector2(11,-7),Vector2(15,-3),Vector2(17,3),Vector2(15,10),Vector2(11,13)],
 [Vector2(11,-7),Vector2(19,-7),Vector2(19,-1),Vector2(11,-1),Vector2(11,5),Vector2(19,5),Vector2(19,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(15,-7),Vector2(15,-3),Vector2(18,-3),Vector2(18,1),Vector2(21,1),Vector2(21,6),Vector2(18,6),Vector2(18,10),Vector2(15,10),Vector2(15,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(17,-5),Vector2(13,-1),Vector2(20,3),Vector2(13,7),Vector2(17,11),Vector2(11,13)],
 [Vector2(11,-7),Vector2(12,-7),Vector2(22,3),Vector2(12,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(20,-7),Vector2(20,-2),Vector2(14,-2),Vector2(14,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(14,-7),Vector2(14,8),Vector2(21,8),Vector2(21,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(16,-6),Vector2(19,-3),Vector2(20,3),Vector2(19,9),Vector2(16,12),Vector2(11,13)],
 [Vector2(11,-7),Vector2(20,-7),Vector2(20,-3),Vector2(12,-3),Vector2(12,0),Vector2(18,0),Vector2(18,5),Vector2(12,5),Vector2(12,9),Vector2(20,9),Vector2(20,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(13,-7),Vector2(13,-1),Vector2(21,-1),Vector2(21,7),Vector2(13,7),Vector2(13,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(14,-7),Vector2(14,-4),Vector2(18,-4),Vector2(18,-1),Vector2(14,-1),Vector2(14,3),Vector2(20,3),Vector2(20,6),Vector2(14,6),Vector2(14,10),Vector2(17,10),Vector2(17,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(12,-7),Vector2(15,-4),Vector2(21,-2),Vector2(17,2),Vector2(21,6),Vector2(15,10),Vector2(12,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(18,-7),Vector2(21,-3),Vector2(15,1),Vector2(11,3),Vector2(15,5),Vector2(21,9),Vector2(18,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(18,-7),Vector2(18,-5),Vector2(21,-5),Vector2(21,0),Vector2(18,0),Vector2(18,6),Vector2(21,6),Vector2(21,11),Vector2(18,11),Vector2(18,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(15,-6),Vector2(18,-3),Vector2(16,0),Vector2(20,3),Vector2(16,6),Vector2(18,9),Vector2(15,12),Vector2(11,13)],
 [Vector2(11,-7),Vector2(21,-5),Vector2(17,-1),Vector2(20,2),Vector2(14,4),Vector2(18,8),Vector2(15,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(14,-7),Vector2(14,-2),Vector2(19,-2),Vector2(19,0),Vector2(14,0),Vector2(14,5),Vector2(21,5),Vector2(21,9),Vector2(14,9),Vector2(14,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(12,-7),Vector2(17,-5),Vector2(21,-1),Vector2(22,3),Vector2(21,7),Vector2(17,11),Vector2(12,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(20,-7),Vector2(16,-3),Vector2(21,1),Vector2(16,5),Vector2(20,9),Vector2(18,13),Vector2(11,13)],
 [Vector2(11,-7),Vector2(15,-7),Vector2(15,-4),Vector2(20,-4),Vector2(20,0),Vector2(16,0),Vector2(16,6),Vector2(20,6),Vector2(20,10),Vector2(15,10),Vector2(15,13),Vector2(11,13)],
]

func island_outline(index: int) -> PackedVector2Array:
 if coastline_cache.has(index):return coastline_cache[index]
 var outline := PackedVector2Array([Vector2(-0.5,-7),Vector2(8.6,-7)])
 for vertex in EAST_COASTS[index]:outline.append(vertex)
 outline.append(Vector2(8.8,13.5+float(index%3)*0.35))
 outline.append(Vector2(4.0,14.1+float(index%2)*0.25))
 outline.append(Vector2(-3.0,13.0))
 outline.append(Vector2(-3.0,3.5))
 outline.append(Vector2(-0.5,3.5))
 coastline_cache[index]=outline
 return outline

func build_island_terrain(index: int,offset: Vector3,top_material: Material) -> void:
 var outline := island_outline(index)
 var triangles := Geometry2D.triangulate_polygon(outline)
 var top := SurfaceTool.new()
 top.begin(Mesh.PRIMITIVE_TRIANGLES)
 for n in range(0,triangles.size(),3):
  for corner in [0,1,2]:
   var v := outline[triangles[n+corner]]
   top.set_normal(Vector3.UP)
   top.set_uv(v*0.1)
   top.add_vertex(Vector3(v.x,0.2,v.y))
 var ground := MeshInstance3D.new()
 ground.name="IslandTerrain_%02d" % index
 ground.mesh=top.commit()
 ground.material_override=top_material
 add_child(ground)
 ground.position=offset
 var sides := SurfaceTool.new()
 sides.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(outline.size()):
  var a := outline[i]
  var b := outline[(i+1)%outline.size()]
  var normal := Vector3(b.y-a.y,0,a.x-b.x).normalized()
  for v in [Vector3(a.x,0.2,a.y),Vector3(b.x,0.2,b.y),Vector3(a.x,-0.8,a.y),Vector3(b.x,0.2,b.y),Vector3(b.x,-0.8,b.y),Vector3(a.x,-0.8,a.y)]:
   sides.set_normal(normal)
   sides.add_vertex(v)
 var cliff := MeshInstance3D.new()
 cliff.mesh=sides.commit()
 cliff.material_override=material(Color("65738e"))
 # Double-sided cliffs handle either side when the camera is near a corner.
 cliff.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
 add_child(cliff)
 cliff.position=offset
 # Posts follow the new silhouette; leave the front entrance and fishing bank open.
 for i in range(1,outline.size()-3):
  var a := outline[i]
  var b := outline[(i+1)%outline.size()]
  var count := maxi(1,int(a.distance_to(b)/1.15))
  for n in range(count):
   var v := a.lerp(b,float(n)/count)
   log_at(offset+Vector3(v.x,0.6,v.y),0.9)
 for x in [0,1,2,7,8]:log_at(offset+Vector3(x,0.6,-7),0.9)

func scatter_zone_details(index: int) -> void:
 var root := Node3D.new()
 root.name="GroundDetails_%02d" % index
 add_child(root)
 var rng := RandomNumberGenerator.new()
 rng.seed=7831+index*197
 var positions: Array=[]
 var tone := Color(DATA.ZONES[index].color)
 for attempt in range(520):
  if positions.size()>=48:break
  var pos := Vector3(rng.randf_range(0.0,18.0),0.23,rng.randf_range(-6.5,14.0)+index*DATA.ZONE_SPACING)
  if not Geometry2D.is_point_in_polygon(Vector2(pos.x+0.4,pos.z-index*DATA.ZONE_SPACING+0.3),island_outline(index)):continue
  if not Geometry2D.is_point_in_polygon(Vector2(pos.x-0.3,pos.z-index*DATA.ZONE_SPACING-0.3),island_outline(index)):continue
  if pos.x>3.0 and pos.x<6.8:continue
  var clear := true
  for kind in ["sale","counter","coins","drop","cook","output","catch","shop"]:
   if flat_distance(pos,point(index,kind))<1.65:clear=false
  for obstacle in furniture:
   if absf(pos.x-obstacle.pos.x)<obstacle.half.x+0.45 and absf(pos.z-obstacle.pos.z)<obstacle.half.y+0.45:clear=false
  for prior in positions:
   if flat_distance(pos,prior)<0.65:clear=false
  if not clear:continue
  positions.append(pos)
  var style := index%8
  for n in range(2 if style==2 else 3):
   var at := pos+Vector3(n*0.12,0,n*0.08)
   if style==0:rounded(root,at,Vector3(0.25,0.1,0.18),tone.lightened(0.4))
   elif style==1:
    var leaf := bevel(root,at,Vector3(0.1,0.025,0.28),tone.lerp(Color("719b60"),0.5))
    leaf.rotation.y=rng.randf_range(-PI,PI)
   elif style==2:bevel(root,at+Vector3(0,0.1,0),Vector3(0.1,0.2+n*0.1,0.12),tone.lightened(0.5))
   elif style==3:bevel(root,at,Vector3(0.22,0.07,0.21),tone.darkened(0.2))
   elif style==4:rounded(root,at,Vector3(0.18,0.04,0.22),Color("e5eced").lerp(tone,0.2))
   elif style==5:
    box(root,at+Vector3(0,0.1,0),Vector3(0.035,0.2,0.035),Color("71916a"))
    ball(root,at+Vector3(0,0.21,0),0.06,Color("f0c36d").lerp(tone,0.3))
   elif style==6:
    box(root,at+Vector3(0,0.06,0),Vector3(0.04,0.12,0.04),Color("dfcda4"))
    rounded(root,at+Vector3(0,0.12,0),Vector3(0.14,0.06,0.12),tone)
   else:
    var log := rounded(root,at+Vector3(0,0.05,0),Vector3(0.32,0.1,0.1),Color("a78059"))
    log.rotation.y=0.4
 root.set_meta("positions",positions)
 # Larger clusters form readable landmarks on the new wings.
 var planted := 0
 for at in positions:
  if at.x<12.2 or planted>=5:continue
  planted+=1
  var plinth := bevel(root,at,Vector3(0.9,0.13,0.75),tone.darkened(0.12))
  plinth.rotation.y=float(planted)*0.7
  if index%4==0:
   for n in range(3):bevel(root,at+Vector3((n-1)*0.22,0.28,0),Vector3(0.18,0.5+n*0.15,0.22),tone.lightened(0.45))
  elif index%4==1:
   for n in range(3):rounded(root,at+Vector3(0,0.16+n*0.12,(n-1)*0.18),Vector3(0.7,0.15,0.15),Color("ac7c4f"))
  elif index%4==2:
   box(root,at+Vector3(0,0.25,0),Vector3(0.07,0.45,0.07),Color("8d7651"))
   for n in range(3):rounded(root,at+Vector3((n-1)*0.17,0.5,0),Vector3(0.4,0.25,0.35),tone.lerp(Color("66926a"),0.5))
  else:
   rounded(root,at+Vector3(0,0.1,0),Vector3(0.6,0.13,0.6),Color("70b7c5"))
   for n in range(3):ball(root,at+Vector3((n-1)*0.25,0.17,0.2),0.12,Color("cad3cc"))


func clothing_material(color: Color) -> Material:
 var key := "wardrobe_"+color.to_html()
 if not render_cache.has(key):
  var fabric := material(color).duplicate()
  fabric.albedo_texture=cloth_texture()
  fabric.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  fabric.set_meta("outlined",true)
  fabric.next_pass=null if weak_device else detail_shader("outline","res://ToonOutline.gdshader")
  render_cache[key]=fabric
 return render_cache[key]

func clothing_catalogue(action: String,uid: int) -> Dictionary:
 if uid<0 or uid>=CLOTHES.ITEMS.size():return {}
 var entry: Dictionary=CLOTHES.ITEMS[uid]
 var owned: bool=profile.wardrobe.owned.has(entry.id)
 var equipped: bool=profile.wardrobe.equipped[entry.slot]==entry.id
 var gift := int(entry.get("reward_zone",-1))
 var detail: String=CLOTHES.SLOT_NAMES[entry.slot]+" · лише зовнішній вигляд."
 if gift>0 and not owned:detail+=" Нагорода за зону %d." % (gift+1)
 elif owned:detail+=" Уже у гардеробі — перевдягання безкоштовне."
 return {"action":action,"zone":selected_zone,"uid":uid,"title":entry.name,"detail":detail,"cost":int(entry.cost),"icon":"","clothing":entry,"owned":owned,"equipped":equipped,"reward_only":gift>0,"done":equipped if action=="clothes_equip" else owned,"available":(owned and not equipped) if action=="clothes_equip" else (not owned and gift<0 and money>=int(entry.cost))}

func wardrobe_action(action: String,uid: int) -> bool:
 if not shop_open:return false
 var entry := clothing_catalogue(action,uid)
 if entry.is_empty() or not entry.available:return false
 var clothing: Dictionary=entry.clothing
 if action=="clothes_buy":
  money-=int(clothing.cost)
  profile.wardrobe.owned.append(clothing.id)
 # Buying outfits also equips them; previously owned pieces always remain selectable.
 profile.wardrobe.equipped[clothing.slot]=clothing.id
 rebuild_hero_outfit()
 play_sound("shop",-22)
 save_game()
 return true

func rebuild_hero_outfit() -> void:
 if not is_instance_valid(hero):return
 var previous: Node3D=hero
 hero=person(previous.position,Color("218caf"),"",profile.wardrobe.equipped)
 hero.name="Hero"
 hero.rotation=previous.rotation
 for key in ["load_ratio","carrying","handover","work","cheer","mining_facing"]:
  if previous.has_meta(key):hero.set_meta(key,previous.get_meta(key))
 hero_carry_models=carry_models(hero,3)
 tool_pivot=make_pickaxe(hero)
 hero_velocity=Vector3.ZERO
 hero.reset_physics_interpolation()
 previous.hide()
 previous.queue_free()
 show_bag(hero_carry_models,profile.bag)

func zone_reward(index: int) -> Dictionary:
 return CLOTHES.reward(index,int(DATA.ZONES[index].cost))

func grant_zone_reward(index: int) -> bool:
 if index<1 or index>=DATA.ZONES.size() or not profile.zones[index].unlocked or profile.zone_rewards.has(index):return false
 profile.zone_rewards.append(index)
 var reward := zone_reward(index)
 money+=int(reward.coins)
 gain_xp(int(reward.xp))
 for id in reward.clothes:
  if not profile.wardrobe.owned.has(id):profile.wardrobe.owned.append(id)
 return true

func reward_description(index: int) -> String:
 var reward := zone_reward(index)
 var result := "+%d монет · +%d досвіду" % [reward.coins,reward.xp]
 for id in reward.clothes:result+="\n"+str(CLOTHES.item(id).name)+" → гардероб"
 return result
