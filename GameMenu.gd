extends CanvasLayer
var game: Node
var overlay: Control
var settings: VBoxContainer
var controls: HBoxContainer
var help_panel: VBoxContainer
var quality: CheckButton
var weak: CheckButton
func _ready() -> void:
 layer=30
 controls=HBoxContainer.new()
 add_child(controls)
 controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 controls.offset_left=-116
 controls.offset_top=23
 controls.offset_right=-12
 controls.offset_bottom=71
 controls.add_theme_constant_override("separation",8)
 for title in ["Меню","Налаштування"]:
  var button := Button.new()
  button.name="MenuButton" if title=="Меню" else "SettingsButton"
  button.icon=load("res://icons/menu_minimal.svg" if title=="Меню" else "res://icons/settings_minimal.svg")
  button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
  button.expand_icon=true
  button.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
  button.tooltip_text=title
  button.custom_minimum_size=Vector2(48,48)
  button.add_theme_constant_override("icon_max_width",24)
  button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  for state in ["normal","hover","pressed","focus"]:
   var style := StyleBoxFlat.new()
   style.bg_color=Color(0.05,0.12,0.17,0.82) if state=="normal" else Color(0.17,0.31,0.34,0.96)
   style.set_corner_radius_all(14)
   style.content_margin_left=12
   style.content_margin_right=12
   style.content_margin_top=12
   style.content_margin_bottom=12
   style.set_border_width_all(1)
   style.border_color=Color(0.65,0.85,0.84,0.15 if state=="normal" else 0.5)
   button.add_theme_stylebox_override(state,style)
  controls.add_child(button)
  button.pressed.connect(open_menu.bind(title=="Налаштування"))
 overlay=Control.new()
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.theme=preload("res://ArtTheme.gd").make()
 add_child(overlay)
 var shade := ColorRect.new()
 shade.color=Color(0.025,0.07,0.1,0.97)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(shade)
 var backdrop := Control.new()
 backdrop.set_script(load("res://MenuBackdrop.gd"))
 backdrop.modulate=Color(0.5,0.6,0.65,0.22)
 overlay.add_child(backdrop)
 var center := CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(center)
 var body := VBoxContainer.new()
 body.custom_minimum_size=Vector2(430,0)
 body.add_theme_constant_override("separation",18)
 center.add_child(body)
 var heading := Label.new()
 heading.text="Пауза"
 heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 heading.add_theme_font_size_override("font_size",32)
 body.add_child(heading)
 settings=VBoxContainer.new()
 body.add_child(settings)
 var sound := VBoxContainer.new()
 sound.set_script(load("res://SoundSettings.gd"))
 sound.game=game
 settings.add_child(sound)
 quality=CheckButton.new()
 quality.set_pressed_no_signal(game.economy_graphics)
 quality.text="Без тіней · чітка графіка"
 quality.custom_minimum_size.y=58
 quality.toggled.connect(game.set_economy_graphics)
 settings.add_child(quality)
 weak=CheckButton.new()
 weak.text="Слабкий пристрій · 30 FPS"
 weak.custom_minimum_size.y=48
 weak.set_pressed_no_signal(game.weak_device)
 weak.toggled.connect(game.set_weak_device)
 settings.add_child(weak)
 help_panel=VBoxContainer.new()
 body.add_child(help_panel)
 var guide := Label.new()
 guide.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 guide.add_theme_font_size_override("font_size",18)
 guide.text="1. Рухайся пальцем і підійди до малої крижини. Удари автоматичні.\n\n2. Стань на позначку продажу біля столу та дочекайся покупця. Забери монети праворуч.\n\n3. Рідкісна риба дорожча; її назва й ціна видимі біля крижини. Великій рибі потрібно більше місця в рюкзаку.\n\n4. У магазині гортай вгору/вниз, а між розділами — ліворуч/праворуч.\n\n5. Рибалка добуває, кур’єр переносить, продавець продає. Розвивай їх окремо."
 help_panel.add_child(guide)
 var hints := Button.new()
 hints.text="Показати підказки знову"
 hints.custom_minimum_size.y=48
 hints.pressed.connect(func():game.profile.tutorial_step=0;game.tutorial_walk=0;close_menu())
 help_panel.add_child(hints)
 help_panel.hide()
 for label in ["Продовжити","Налаштування","Як грати","Зберегти й вийти в меню"]:
  var button := Button.new()
  button.text=label
  button.custom_minimum_size.y=60
  body.add_child(button)
  if label=="Продовжити":button.pressed.connect(close_menu)
  elif label=="Налаштування":button.pressed.connect(func():settings.visible=not settings.visible;help_panel.hide())
  elif label=="Як грати":button.pressed.connect(func():help_panel.visible=not help_panel.visible;settings.hide())
  else:button.pressed.connect(game.return_to_title)
 overlay.hide()
func open_menu(show_settings: bool) -> void:
 if game.start_pending:return
 game.close_shop()
 game.set_paused(true)
 help_panel.hide()
 quality.set_pressed_no_signal(game.economy_graphics)
 weak.set_pressed_no_signal(game.weak_device)
 settings.visible=show_settings
 overlay.show()
func close_menu() -> void:
 overlay.hide()
 game.set_paused(false)
func _process(_delta: float) -> void:
 controls.visible=not game.start_pending and not game.shop_open and not game.paused
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and not game.start_pending:
  if game.paused:close_menu()
  else:open_menu(false)
  get_viewport().set_input_as_handled()
