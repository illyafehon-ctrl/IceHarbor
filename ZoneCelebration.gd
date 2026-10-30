extends Control
var game: Node
var zone_index := 0
var elapsed := 0.0
var title: Label
var subtitle: Label
var panel: PanelContainer
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel=PanelContainer.new()
 panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 panel.offset_left=-222
 panel.offset_right=222
 panel.offset_top=148
 panel.offset_bottom=250
 add_child(panel)
 var style := StyleBoxFlat.new()
 style.bg_color=Color("173f4c")
 style.border_color=Color("f1cb71")
 style.set_border_width_all(2)
 style.set_corner_radius_all(22)
 style.content_margin_top=16
 style.content_margin_bottom=16
 panel.add_theme_stylebox_override("panel",style)
 var body := VBoxContainer.new()
 body.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.add_child(body)
 title=Label.new()
 title.text="НОВУ ЗОНУ ВІДКРИТО!"
 title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 title.add_theme_font_override("font",load("res://fonts/DejaVuSans-Bold.ttf"))
 title.add_theme_font_size_override("font_size",24)
 title.add_theme_color_override("font_color",Color("ffe4a0"))
 title.mouse_filter=Control.MOUSE_FILTER_IGNORE
 body.add_child(title)
 subtitle=Label.new()
 subtitle.text=str(zone_index+1)+". "+str(game.DATA.ZONES[zone_index].name)
 subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 subtitle.add_theme_font_size_override("font_size",21)
 subtitle.mouse_filter=Control.MOUSE_FILTER_IGNORE
 body.add_child(subtitle)
 var reward := Label.new()
 reward.text=game.reward_description(zone_index)
 reward.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 reward.add_theme_font_size_override("font_size",20)
 reward.add_theme_color_override("font_color",Color("a6ebce"))
 reward.mouse_filter=Control.MOUSE_FILTER_IGNORE
 body.add_child(reward)
 panel.modulate.a=0
func _process(delta: float) -> void:
 if game.paused or game.start_pending:return
 elapsed+=minf(delta,0.05)
 if elapsed>=5.0:
  queue_free()
  return
 var entrance := smoothstep(0.0,0.4,elapsed)
 var alpha := entrance*(1.0-smoothstep(4.3,5.0,elapsed))
 panel.modulate.a=alpha
 panel.position.y=148-(1.0-entrance)*22
 queue_redraw()
func _draw() -> void:
 var fade := 1.0-smoothstep(1.8,2.8,elapsed)
 if fade<=0:return
 var center := Vector2(size.x*0.5,200)
 var palette := [Color("ffe09a"),Color("7ce4ce"),Color("f2a090")]
 var count := 12 if game.weak_device else 28
 for i in range(count):
  var angle := float(i)*TAU/float(count)
  var travel := 42.0+elapsed*(52.0+float(i%4)*12.0)
  var pos := center+Vector2(cos(angle)*travel,sin(angle)*travel*0.75+elapsed*elapsed*24)
  var tint: Color=palette[i%3]
  tint.a=fade
  draw_circle(pos,2.0+float(i%3),tint)
 var ring_color := Color(1,0.87,0.54,(1-smoothstep(0.2,1.1,elapsed))*0.65)
 draw_arc(center,35+elapsed*150,0,TAU,40,ring_color,2,true)
