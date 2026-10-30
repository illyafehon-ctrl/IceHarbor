extends VBoxContainer
var game: Node
var rows: Dictionary={}
var toggle: Button
var timer := 0.0
func _ready() -> void:
 add_theme_constant_override("separation",8)
 toggle=Button.new()
 toggle.custom_minimum_size.y=46
 toggle.pressed.connect(func():game.toggle_audio();refresh_values())
 add_child(toggle)
 for entry in [["master","Загальна гучність"],["effects","Ефекти · кроки та дії"],["music","Музика"],["ambient","Фон · вода й вітер"]]:
  var group: String=entry[0]
  var row := VBoxContainer.new()
  row.add_theme_constant_override("separation",0)
  add_child(row)
  var title := Label.new()
  title.add_theme_font_size_override("font_size",17)
  row.add_child(title)
  var slider := HSlider.new()
  slider.custom_minimum_size=Vector2(0,38)
  slider.min_value=0
  slider.max_value=100
  slider.step=5
  slider.value_changed.connect(on_slider.bind(group))
  row.add_child(slider)
  rows[group]={"label":title,"slider":slider,"title":entry[1]}
 refresh_values()
func on_slider(value: float,group: String) -> void:
 if group=="master":game.set_audio_volume(value/100.0)
 else:game.set_sound_level(group,value/100.0)
 refresh_values()
func refresh_values() -> void:
 if not is_instance_valid(toggle):return
 toggle.text="Звук увімкнено" if game.sounds_enabled else "Увімкнути звук"
 for group in rows:
  var value: float=game.audio_volume if group=="master" else float(game.sound_mix[group])
  rows[group].label.text="%s · %d%%" % [rows[group].title,roundi(value*100)]
  rows[group].slider.set_value_no_signal(value*100)
func _process(delta: float) -> void:
 if not is_visible_in_tree():return
 timer+=delta
 if timer>0.15:
  timer=0
  refresh_values()
