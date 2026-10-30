extends CanvasLayer
var game: Node
var shell: Control
var list: VBoxContainer
var travel_button: Button
var zone_picker: OptionButton
var balance: Label
var rows: Array=[]
var tab := 0
var zone := 0
var volume: HSlider
var volume_text: Label
var mute: Button
var sound_settings: VBoxContainer
var timer := 0.0
var tab_buttons: Array=[]
var scroll: ScrollContainer
var audio_controls: VBoxContainer
var category_hint: Label
var clothing_slot := "hat"
var gesture_active := false
var gesture_start := Vector2.ZERO
var gesture_delta := Vector2.ZERO
var gesture_scroll := 0
var gesture_dragged := false
var inertia := 0.0
var suppress_purchase := false

func theme_box(color: Color) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color=color
 style.set_corner_radius_all(16)
 style.content_margin_left=12
 style.content_margin_right=12
 style.content_margin_top=10
 style.content_margin_bottom=10
 return style

func _ready() -> void:
 layer=20
 shell=Control.new()
 shell.theme=preload("res://ArtTheme.gd").make()
 shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(shell)
 var shade := ColorRect.new()
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.color=Color(0.02,0.05,0.08,0.9)
 shell.add_child(shade)
 var panel := PanelContainer.new()
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel.offset_left=16
 panel.offset_right=-16
 panel.offset_top=14
 panel.offset_bottom=-20
 panel.add_theme_stylebox_override("panel",theme_box(Color("19343e")))
 shell.add_child(panel)
 var body := VBoxContainer.new()
 body.add_theme_constant_override("separation",10)
 panel.add_child(body)
 var header := HBoxContainer.new()
 body.add_child(header)
 var title := Label.new()
 title.text="Крамниця"
 title.add_theme_font_override("font",preload("res://ArtTheme.gd").TITLE)
 title.add_theme_font_size_override("font_size",28)
 title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 header.add_child(title)
 var close := Button.new()
 close.text="Готово ×"
 close.custom_minimum_size=Vector2(120,48)
 close.pressed.connect(game.close_shop)
 header.add_child(close)
 balance=Label.new()
 balance.add_theme_color_override("font_color",Color("f2d49c"))
 body.add_child(balance)
 zone_picker=OptionButton.new()
 zone_picker.custom_minimum_size.y=50
 for i in range(game.DATA.ZONES.size()):
  zone_picker.add_item("%d · %s" % [i+1,game.DATA.ZONES[i].name])
 zone_picker.item_selected.connect(func(index: int): zone=index; build_list())
 var destination := HBoxContainer.new()
 body.add_child(destination)
 zone_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 destination.add_child(zone_picker)
 travel_button=Button.new()
 travel_button.text="Перейти"
 travel_button.custom_minimum_size=Vector2(110,50)
 travel_button.pressed.connect(func(): game.purchase("travel",zone))
 destination.add_child(travel_button)
 var tabs := GridContainer.new()
 tabs.columns=2
 body.add_child(tabs)
 var names := ["Помічники","Герой","Команда","Локації","Купити одяг","Мій гардероб"]
 for i in range(6):
  var button := Button.new()
  button.text=names[i]
  button.custom_minimum_size=Vector2(0,54)
  button.add_theme_font_size_override("font_size",18)
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button.pressed.connect(select_tab.bind(i))
  tab_buttons.append(button)
  tabs.add_child(button)
 var swipe_hint := Label.new()
 swipe_hint.text="↑↓ Гортай список    ←→ Змінюй розділ"
 swipe_hint.add_theme_font_size_override("font_size",14)
 swipe_hint.add_theme_color_override("font_color",Color("9cc8c5"))
 body.add_child(swipe_hint)
 category_hint=Label.new()
 category_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 category_hint.add_theme_color_override("font_color",Color("b7d1cf"))
 body.add_child(category_hint)
 scroll=ScrollContainer.new()
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 body.add_child(scroll)
 list=VBoxContainer.new()
 list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 list.add_theme_constant_override("separation",10)
 scroll.add_child(list)
 var audio_toggle := Button.new()
 audio_toggle.text="♫  Налаштування звуку"
 audio_toggle.custom_minimum_size.y=44
 body.add_child(audio_toggle)
 audio_controls=VBoxContainer.new()
 body.add_child(audio_controls)
 audio_controls.hide()
 audio_toggle.pressed.connect(func(): audio_controls.visible=not audio_controls.visible)
 sound_settings=VBoxContainer.new()
 sound_settings.set_script(load("res://SoundSettings.gd"))
 sound_settings.game=game
 audio_controls.add_child(sound_settings)
 shell.hide()

func set_open(value: bool) -> void:
 shell.visible=value
 gesture_active=false
 inertia=0
 if value:
  zone=game.selected_zone
  build_list()

func build_list() -> void:
 category_hint.text=["Рибалка добуває, кур’єр переносить, продавець продає. До 3 рибалок, 3 кур’єрів та 1 продавця на зону.","Ці покращення діють для героя в усіх зонах.","Кожен помічник має власний рівень розвитку.","Відкривай зони послідовно: отримуй монети, досвід та подарунки.","Купівля одразу одягає річ. Одяг не змінює силу чи швидкість.","Усі придбані й подаровані речі. Перевдягання безкоштовне."][tab]
 for i in range(tab_buttons.size()):
  tab_buttons[i].add_theme_stylebox_override("normal",theme_box(Color("3d827d") if i==tab else Color("284852")))
 rows.clear()
 for node in list.get_children():
  list.remove_child(node)
  node.queue_free()
 if tab==0:
  for role in ["fisher","runner","seller"]:
   add_card(game.catalogue_item(role,zone))
 elif tab==1:
  for stat in ["tool","bag","speed","trade"]:
   add_card(game.catalogue_item("hero_"+stat,zone))
 elif tab==2:
  for worker in game.profile.workers:
   if worker.zone==zone:
    add_card(game.catalogue_item("rank",zone,int(worker.uid)))
  if rows.is_empty():
   var label := Label.new()
   label.text="У цій зоні ще немає найнятих працівників."
   label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
   list.add_child(label)
 elif tab==3:
  if zone>0:
   add_card(game.catalogue_item("kitchen",zone))
  for i in range(game.DATA.ZONES.size()):
   add_card(game.catalogue_item("travel" if game.profile.zones[i].unlocked else "unlock",i))
 else:
  var filters := HBoxContainer.new()
  list.add_child(filters)
  for slot in game.CLOTHES.SLOTS:
   var button := Button.new()
   button.text=game.CLOTHES.SLOT_NAMES[slot]
   button.custom_minimum_size.y=48
   button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   button.disabled=slot==clothing_slot
   button.pressed.connect(func():clothing_slot=slot;build_list())
   filters.add_child(button)
  for i in range(game.CLOTHES.ITEMS.size()):
   var entry: Dictionary=game.CLOTHES.ITEMS[i]
   if entry.slot!=clothing_slot:continue
   var owned: bool=game.profile.wardrobe.owned.has(entry.id)
   if tab==4 and not owned:add_card(game.clothing_catalogue("clothes_buy",i))
   elif tab==5 and owned:add_card(game.clothing_catalogue("clothes_equip",i))
  if rows.is_empty():
   var label := Label.new()
   label.text="Усі речі цієї категорії вже у гардеробі."
   label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
   list.add_child(label)
 refresh()

func add_card(item: Dictionary) -> void:
 if item.is_empty():
  return
 var panel := PanelContainer.new()
 panel.add_theme_stylebox_override("panel",theme_box(Color("284852")))
 list.add_child(panel)
 var row := HBoxContainer.new()
 row.add_theme_constant_override("separation",10)
 panel.add_child(row)
 var image := TextureRect.new()
 if item.has("clothing"):
  image.hide()
  var preview := Control.new()
  preview.set_script(load("res://ClothingIcon.gd"))
  preview.item=item.clothing
  row.add_child(preview)
 elif str(item.icon).begins_with("icons/portrait_"):
  var atlas: Texture2D=load("res://icons/portraits_cartoon.png")
  var portrait := AtlasTexture.new()
  portrait.atlas=atlas
  var role := str(item.icon).trim_prefix("icons/portrait_").trim_suffix(".png")
  var slot: int={"fisher":0,"runner":1,"seller":2}.get(role,0)
  portrait.region=Rect2(float(atlas.get_width())/3*slot,0,float(atlas.get_width())/3,atlas.get_height())
  image.texture=portrait
 else:image.texture=load("res://"+item.icon)
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.custom_minimum_size=Vector2(64,86)
 image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 row.add_child(image)
 var text := VBoxContainer.new()
 text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 row.add_child(text)
 var title := Label.new()
 title.text=item.title
 title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 title.add_theme_font_override("font",preload("res://ArtTheme.gd").TITLE)
 title.add_theme_font_size_override("font_size",23)
 text.add_child(title)
 var detail := Label.new()
 detail.text=item.detail
 detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 detail.add_theme_color_override("font_color",Color("c4d8d6"))
 detail.add_theme_font_size_override("font_size",18)
 text.add_child(detail)
 var buy := Button.new()
 buy.custom_minimum_size.y=52
 buy.pressed.connect(func():
  if suppress_purchase:return
  var old_scroll := scroll.scroll_vertical
  game.purchase(item.action,int(item.zone),int(item.uid))
  if shell.visible:
   build_list()
   scroll.set_deferred("scroll_vertical",old_scroll)
 )
 text.add_child(buy)
 rows.append({"item":item,"buy":buy,"detail":detail})

func refresh() -> void:
 balance.text="● %d монет     ·     Герой: рівень %d" % [game.money,game.player_level]
 for i in range(game.DATA.ZONES.size()):
  zone_picker.set_item_disabled(i,not game.profile.zones[i].unlocked)
 zone_picker.select(zone)
 travel_button.disabled=zone==game.selected_zone or not game.profile.zones[zone].unlocked
 travel_button.text="Ви тут" if zone==game.selected_zone else "Перейти"
 sound_settings.refresh_values()
 for row in rows:
  var previous: Dictionary=row.item
  var item: Dictionary=game.catalogue_item(previous.action,int(previous.zone),int(previous.uid))
  row.detail.text=item.detail
  row.buy.disabled=not item.available
  if item.action=="clothes_equip":
   row.buy.text="На герої ✓" if item.equipped else "Одягнути · безкоштовно"
  elif item.action=="clothes_buy" and item.reward_only:
   row.buy.text="Подарунок за зону %d" % (int(item.clothing.reward_zone)+1)
  elif item.done:
   row.buy.text="Максимум / придбано"
  elif item.action=="travel":
   row.buy.text="Перейти в зону"
  elif item.action=="unlock" and int(item.zone)>0 and not game.profile.zones[int(item.zone)-1].unlocked:
   row.buy.text="Спочатку попередня зона"
  else:
   row.buy.text="Купити · %d ●" % int(item.cost) if item.available else "Бракує %d ●" % maxi(0,int(item.cost)-game.money)

func _process(delta: float) -> void:
 if shell.visible:
  if not gesture_active and absf(inertia)>2:
   scroll.scroll_vertical+=int(inertia*delta)
   inertia*=exp(-8*delta)
  timer+=delta
  if timer>0.25:
   timer=0
   refresh()

func _unhandled_input(event: InputEvent) -> void:
 if shell.visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  game.close_shop()
  get_viewport().set_input_as_handled()

func select_tab(index: int) -> void:
 tab=clampi(index,0,5)
 inertia=0
 build_list()
 scroll.scroll_vertical=0

func _input(event: InputEvent) -> void:
 if not shell.visible:return
 var down: bool=event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT)
 var motion: bool=event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
 if down:
  if event.pressed:
   if not scroll.get_global_rect().has_point(event.position):return
   gesture_active=true
   gesture_start=event.position
   gesture_delta=Vector2.ZERO
   gesture_scroll=scroll.scroll_vertical
   gesture_dragged=false
   suppress_purchase=false
   inertia=0
  elif gesture_active:
   gesture_active=false
   if gesture_dragged:
    suppress_purchase=true
    if absf(gesture_delta.x)>65 and absf(gesture_delta.x)>absf(gesture_delta.y)*1.3:
     select_tab((tab+(1 if gesture_delta.x<0 else 5))%6)
    for row in rows:row.buy.set_pressed_no_signal(false)
    get_viewport().set_input_as_handled()
    reset_purchase.call_deferred()
 elif motion and gesture_active:
  gesture_delta=event.position-gesture_start
  if gesture_delta.length()>12:gesture_dragged=true
  if gesture_dragged:
   suppress_purchase=true
   if absf(gesture_delta.y)>=absf(gesture_delta.x):
    scroll.scroll_vertical=gesture_scroll-int(gesture_delta.y)
    inertia=clampf(-event.relative.y*35,-1200,1200)
   get_viewport().set_input_as_handled()

func reset_purchase() -> void:
 suppress_purchase=false
