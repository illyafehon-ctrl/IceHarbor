extends CanvasLayer
var game: Node
var status: Label
var confirm: ConfirmationDialog
var has_save := false
var settings: Control
var sound_text: Label
func style(color: Color) -> StyleBoxFlat:
 var s := StyleBoxFlat.new()
 s.bg_color=color
 s.set_border_width_all(1)
 s.border_color=color.lightened(0.22)
 s.shadow_color=Color(0.01,0.05,0.08,0.25)
 s.shadow_size=5
 s.set_corner_radius_all(18)
 s.content_margin_left=22
 s.content_margin_right=22
 s.content_margin_top=22
 s.content_margin_bottom=22
 return s
func label(text: String,font_size: int,color: Color=Color.WHITE) -> Label:
 var l := Label.new()
 l.text=text
 l.add_theme_font_size_override("font_size",font_size+2)
 if font_size>=24:
  l.add_theme_font_override("font",preload("res://ArtTheme.gd").TITLE)
 l.add_theme_color_override("font_color",color)
 l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 return l
func button(text: String,callback: Callable) -> Button:
 var b := Button.new()
 b.text=text
 b.custom_minimum_size=Vector2(0,58)
 b.add_theme_font_size_override("font_size",22)
 b.add_theme_stylebox_override("normal",style(Color("316c73")))
 b.add_theme_stylebox_override("hover",style(Color("41878a")))
 b.add_theme_stylebox_override("pressed",style(Color("24565f")))
 b.pressed.connect(callback)
 return b
func _ready() -> void:
 layer=40
 has_save=not game.read_progress().is_empty()
 var scene := Control.new()
 scene.theme=preload("res://ArtTheme.gd").make()
 scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(scene)
 var backdrop := Control.new()
 backdrop.set_script(load("res://MenuBackdrop.gd"))
 scene.add_child(backdrop)
 var center := CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scene.add_child(center)
 var card := PanelContainer.new()
 card.custom_minimum_size=Vector2(440,0)
 card.add_theme_stylebox_override("panel",style(Color(0.035,0.11,0.16,0.93)))
 center.add_child(card)
 var body := VBoxContainer.new()
 body.add_theme_constant_override("separation",16)
 card.add_child(body)
 var crest := TextureRect.new()
 crest.texture=load("res://icons/pad_fish.svg")
 crest.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 crest.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 crest.custom_minimum_size=Vector2(0,78)
 crest.modulate=Color("c1e4dc")
 body.add_child(crest)
 body.add_child(label("ICE HARBOR",36,Color("f6e9c8")))
 body.add_child(label("Від першої рибини\nдо королівської гавані",17,Color("b8d4d6")))
 body.add_child(label("20 локацій   ·   Власна команда",14,Color("8fbabf")))
 body.add_child(button("Продовжити" if has_save else "Почати пригоду",func(): launch(false)))
 if has_save:
  body.add_child(button("Нова гра",func(): confirm.popup_centered(Vector2i(450,220))))
 body.add_child(button("♫  Налаштування",func(): settings.show()))
 status=label("",14,Color("f0cf9b"))
 body.add_child(status)
 confirm=ConfirmationDialog.new()
 confirm.title="Почати нову гру?"
 confirm.dialog_text="Поточний прогрес буде скинуто.\nПопереднє збереження залишиться в резервній копії."
 confirm.ok_button_text="Почати з нуля"
 confirm.cancel_button_text="Скасувати"
 add_child(confirm)
 confirm.confirmed.connect(func(): launch(true))
 build_settings(scene)
func launch(fresh: bool) -> void:
 var mix: Dictionary=game.sound_mix.duplicate(true)
 var volume: float=game.audio_volume
 var enabled: bool=game.sounds_enabled
 if fresh or not has_save:
  if not game.start_fresh():
   status.text="Не вдалося створити резервну копію. Прогрес збережений."
   return
 else:
  game.continue_saved()
  if game.start_pending:
   status.text="Не вдалося прочитати збереження."
   return
 game.sound_mix=mix
 game.apply_sound_mix()
 game.audio_volume=volume
 game.sounds_enabled=enabled
 game.audio.set_volume(volume)
 game.audio.set_enabled(enabled)
 game.save_game()
 queue_free()
func build_settings(scene: Control) -> void:
 settings=Control.new()
 settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scene.add_child(settings)
 var backdrop := Control.new()
 backdrop.set_script(load("res://MenuBackdrop.gd"))
 settings.add_child(backdrop)
 var center := CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 settings.add_child(center)
 var panel := PanelContainer.new()
 panel.custom_minimum_size=Vector2(440,0)
 panel.add_theme_stylebox_override("panel",style(Color(0.035,0.11,0.16,0.96)))
 center.add_child(panel)
 var body := VBoxContainer.new()
 body.add_theme_constant_override("separation",22)
 panel.add_child(body)
 body.add_child(label("Налаштування",28,Color("f6e9c8")))
 var mixer := VBoxContainer.new()
 mixer.set_script(load("res://SoundSettings.gd"))
 mixer.game=game
 body.add_child(mixer)
 body.add_child(button("Готово",func(): settings.hide()))
 settings.hide()
